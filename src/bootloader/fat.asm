;
; Naive implementation of basic FAT12 driver
;
; https://www.eit.lth.se/fileadmin/eit/courses/eitn50/Literature/fat12_description.pdf
; https://www.sqlpassion.at/archive/2022/03/03/reading-files-from-a-fat12-partition/
;

; Algorithm to read and unpack the nth FAT entry from the table
; 
; - If n is even, then the physical location of the entry is the low four bits in location 1+(3*n)/2
;   and the 8 bits in location (3*n)/2
; - If n is odd, then the physical location of the entry is the high four bits in location (3*n)/2 and
;   the 8 bits in location 1+(3*n)/2
;
; If we read 2 bytes from the FAT at the index 
;
; if (n % 2 == 0) {
;   short entry = FAT[(3 * n) / 2] & 0x0FFF
; } else {
;   short entry = FAT[(3 * n) / 2] >> 4
; }
;
; @input ax - FAT index
; @input es:bx - Address of FAT table in memory
; @output ax - FAT entry
fat_read_entry_from_fat:
    push cx
    push bx
    
    ; Store FAT index for later use
    push ax

    ; Calculate start address offset of 12-bit entry
    mov cx, 3
    mul cx      ; n * 3
    shr ax, 1   ; (n * 3) / 2

    ; Add offset to calculate start address of entry
    add bx, ax

    ; Read the entry bytes into cx
    mov cx, word [bx]

    ; Branch based on parity of index (determines unpacking strategy)
    pop ax
    test ax, 1 ; Sets zero bit to LSB of index (1 if odd 0 is even)
    jnz .odd

.even:
    and cx, 0x0FFF

    jmp .read_done

.odd:
    shr cx, 4
    
.read_done:
    ; Move entry back into ax for return
    mov ax, cx
    
    pop bx
    pop cx
    ret

;
; Reads an entire file from the disk into memory given the index of the first cluster
; 
; @input ax - First logical cluster index
; @input es:bx - Address of FAT table in memory
; @input es:cx - Destination address
;
fat_read_file_from_fat:
    push di

    ; Make room for 8 bytes on the stack
    push bp
    mov bp, sp
    sub sp, 8

    ; Store input variables on the stack
    mov [bp-2], ax      ; Current cluster index
    mov [bp-4], bx      ; FAT table pointer
    mov [bp-6], cx      ; Dest base pointer

    ; Create an incrementing sector offset to add to the dest base pointer
    mov di, 0

.fat_loop:
    mov ax, [bp-2] ; Current cluster index

.disk_read:
    ; Converts the FAT index into a physical sector number on the disk
    add ax, 33
    sub ax, 2 ; Sector number in ax

    ; Calculate the dest address from the offset
    mov bx, di
    shl bx, 9       ; Multiply by 512
    mov cx, [bp-6]  ; Dest base pointer
    add bx, cx      ; Read dest in bx
    
    ; Read the sector into memory
    mov cl, 1                   ; Sectors to read
    mov dl, [ebpb_drive_number] ; Drive number to read from
    call disk_read

    ; Next iteration, write 512 bytes further into memory
    inc di

.get_entry:
    ; Get entry from FAT at the current index
    mov ax, [bp-2]                  ; Current cluster index
    mov bx, [bp-4]                  ; FAT pointer
    call fat_read_entry_from_fat    ; FAT[curr_idx] in ax
    mov [bp-2], ax                  ; curr_idx = FAT[curr_idx]

    ; If the next entry is a valid index, keep traversing, otherwise we are finished reading
    ; 
    ; 0x000: Unused
    ; 0x001: Reserved Cluster
    ; 0x002 – 0xFEF: The cluster is in use, and the value represents the next cluster
    ; 0xFF0 – 0xFF6: Reserved Cluster
    ; 0xFF7: Bad Cluster
    ; 0xFF8 – 0xFFF: Last Cluster in a file
    ;
    ; We can tell if we should keep reading if (entry - 2) <= 0xFED
    ; We can tell that we have reached the end of the file if (entry >> 3) == 0x1FF

    ; Keep traversing case
    sub ax, 2
    cmp ax, 0xFED
    jle .fat_loop

    ; EOF case
    mov ax, [bp-2]
    shr ax, 3
    cmp ax, 0x1FF
    je .read_done

.error:
    ; Print a failure message and halt
    mov si, fat_read_entry_failure_msg
    call print
    jmp halt

.read_done:
    ; Restore input vars
    mov ax, [bp-2]
    mov bx, [bp-4]
    mov cx, [bp-6]
    
    ; Restore the stack
    mov sp, bp
    pop bp
    
    pop di
    ret

;
; Checks to see if the file name of this entry matches a given string
; @input si - file name
; @input es:bx - pointer to the directory entry
;
fat_dir_entry_matches:
    pusha

    ; Store pointer for later
    mov cx, bx

    ; Initialize a counter
    mov di, 0

.match_loop:
    ; Load a byte from the file name into al
    lodsb

    ; Compare with the same byte from the entry file name
    mov bx, cx
    add bx, di
    mov ah, [bx]
    cmp al, ah
    jne .not_matched

    ; If the counter reached 11 without failing early, then the strings match
    inc di
    cmp di, 11
    je .matched

    ; Continue the loop
    jmp .match_loop

.matched:
    ; Set zero flag
    lahf                      ; Load AH from FLAGS
    or       AH,001000000b    ; Set bit for ZF
    sahf                      ; Store AH back to Flags

    jmp .finished

.not_matched:
    ; Clear zero flag
    lahf                      ; Load lower 8 bit from Flags into AH
    and      AH,010111111b    ; Clear bit for ZF
    sahf                      ; Store AH back to Flags

    jmp .finished

.finished:
    popa
    ret

;
; Searches for a reads a file from the root directory into memory 
; @input si - File name
; @input es:bx - Destination address
;
fat_find_and_read_root_file:
    pusha

    ; Store the destination addr for later
    mov cx, bx

    ; Entry index (32-bits each)
    mov di, 0

.search_loop:
    ; Calculate the next entry address
    mov bx, di
    shl bx, 5
    add bx, FAT_ROOT_DIR_ADDR ; entry addr in bx
    
    ; Check if the file name matches the given one
    call fat_dir_entry_matches
    je .file_found

    ; Next time around, get the entry after this one
    inc di

    ; If we are at the end of the root directory, we didnt find the file
    cmp di, 224
    je .file_not_found

    ; Continue the loop
    jmp .search_loop

.file_not_found:
    ; TODO: handle search failure

.file_found:
    ; Get the number of the first logical cluster
    add bx, 26 ; Offset into directory entry
    mov ax, [bx]
    
    ; Read the entire file into memory
    mov bx, FAT_TABLE_ADDR
    call fat_read_file_from_fat

.search_done:
    popa
    ret

fat_read_entry_failure_msg: db 'ERRFAT', 0x0D, 0x0A, 0