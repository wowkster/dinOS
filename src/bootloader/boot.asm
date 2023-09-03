org 0x7C00
bits 16

jmp short main
nop

bdb_oem:                    db 'MSWIN4.1'
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0x0E0
bdb_total_sectors:          dw 2880
bdb_media_descriptor_type:  db 0x0F0
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

ebr_drive_number:   db 0
                    db 0
ebr_signature:      db 0x29
ebr_volume_id:      db 0x12, 0x34, 0x56, 0x78
ebr_volume_label:   db 'CHAOS      '
ebr_system_id:      db 'FAT12   '

main:
    ; Initialize the registers of the processor to a known state
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Setup the stack to a known place in memory (grows down)
    mov sp, 0x7C00

    ; Read data from the disk (1 sector from sector 1 into 0x7E00)
    mov [ebr_drive_number], dl
    mov ax, 1
    mov cl, 1
    mov bx, 0x7E00
    call disk_read

    ; Call print with the address of our message
    mov si, os_boot_msg
    call print

    ; Halt the processor
    hlt

halt:
    jmp halt

;
; Converts a disk location from LBA indexing to CHS indexing format
;   @input ax - LBA index
;   @output cx [bits 0-5] - sector number
;   @output cx [bits 6-15] - cylinder
;   @output dh - head
;
lba_to_chs:
    push ax
    push dx

    ; Clear dx
    xor dx, dx

    ; LBA % sectors per track + 1 = sector
    div word [bdb_sectors_per_track] 
    inc dx 
    mov cx, dx ; Sector in cx

    xor dx, dx
    div word [bdb_heads] 

    ; (LBA / sectors per track) % number of heads = head
    mov dh, dl ; Head in dh

    ; (LBA / sectors per track) / number of heads  = cylinder
    mov ch, al
    shl ah, 6
    or cl, ah ; Cylinder in cx [bits 6-15]

    pop ax
    mov dl, al
    pop ax

    ret

;
; Resets the drivers for the given disk 
; @input dl - drive number
;
disk_reset:
    pusha

    ; BIOS interrupt to reset disk system
    mov ah, 0
    stc
    int 0x13
    jc disk_read_fail
    
    popa
    ret

;
; Reads a given sector from a disk
;
disk_read:
    push ax
    push bx
    push cx
    push dx
    push di

    ; Convert the LBA sector index to CHS
    call lba_to_chs

    ; Set the flag for reading a sector
    mov ah, 0x02

    ; Create a retry counter to tell us when to stop reading after failures
    mov di, 3 ; Counter

disk_read_retry:
    ; BIOS interrupt to read a sector
    stc
    int 0x13

    ; Jump to end if succeeded
    jnc disk_read_done

    ; If failed, reset the disk system
    call disk_reset

    ; If we havent reached the retry limit, try again
    dec di
    test di, di
    jnz disk_read_retry

disk_read_fail:
    ; Print a failure message and halt
    mov si, read_failure
    call print
    hlt
    jmp halt

disk_read_done:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    
    ret

; 
; Prints a given string to the screen using BIOS interrupts
;
print: 
    ; Preserve registers on the stack
    push si
    push ax
    push bx

print_loop:
    ; Load a character from si register into al 
    lodsb 

    ; If the character is null (the end of the string) jump to the end of the routine
    or al, al
    jz print_done

    ; BIOS interrupt to print char
    mov ah, 0x0E
    mov bh, 0
    int 0x10

    ; Continue the loop
    jmp print_loop

print_done:
    ; Pop preserved registers off the stack
    pop bx
    pop ax
    pop si
    ret

os_boot_msg: db 'Hello World!', 0x0D, 0x0A, 0
read_failure: db 'Failed to read disk!!', 0x0D, 0x0A, 0

times 510-($-$$) db 0
dw 0xAA55
