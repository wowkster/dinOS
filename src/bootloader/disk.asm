%ifndef DISK_ASM
%define DISK_ASM

%include "boot.asm"

;
; Disk operations that use the int 0x13 BIOS interrupt:
;
; https://en.wikipedia.org/wiki/INT_13H
;

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
    div word [bpb_sectors_per_track] 
    inc dx 
    mov cx, dx ; Sector in cx

    xor dx, dx
    div word [bpb_heads] 

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
; Reads the given sector(s) from a disk
; @input ax - LBA index to read from
; @input cl - Number of sectors to read
; @input dl - Drive number
; @input es:bx - Destination address
;
disk_read:
    pusha
    push di

    ; Make room for 4 bytes on the stack
    push bp
    mov bp, sp
    sub sp, 4

    ; Store the number of sectors to read on the stack
    mov [bp-4], cl

    ; Convert the LBA sector index to CHS
    call lba_to_chs

    ; Create a retry counter to tell us when to stop reading after failures
    mov di, 3 ; Counter

.try_read:
    ; Restore the number of sectors to read
    mov al, [bp-4]
    
    ; BIOS interrupt to read a sector
    stc
    mov ah, 0x02
    int 0x13

    ; If carry is set, there was an error
    jc .read_error

    ; If the number of sectors read and the number we requested are different,
    ; there was an error
    cmp [bp-4], al
    jne .read_error

    ; Jump to end if succeeded
    jmp .read_done

.read_error:
    ; If failed, reset the disk system
    call disk_reset

    ; If we havent reached the retry limit, try again
    dec di
    test di, di
    jnz .try_read

    ; If we have reached the limit, jump to hard failure
    jmp disk_fail

.read_done:
    ; Restore the stack
    mov sp, bp
    pop bp
    
    ; Restore all other registers
    pop di
    popa
    
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

    ; If failed to reset, jump to hard failure
    jc disk_fail
    
    popa
    ret

;
; Prints an disk read error message and halts
;
disk_fail:
    ; Print a failure message and halt
    mov si, read_failure_msg
    call print
    jmp halt

read_failure_msg: db 'ERRDSK', 0

%endif