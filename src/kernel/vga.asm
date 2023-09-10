%ifndef PRINT_ASM
%define PRINT_ASM

bits 32

VIDEO_MEMORY_ADDR equ 0xB8000
SCREEN_CAPACITY equ 2000
WHITE_ON_BLACK equ 0x0F

; Static variable to hold our offset into the video memory
_print_offset: dw 0

; 
; Prints a given string into the VGA video memory in text mode
; @input esi - Pointer to the string to print (null terminated)
;
kprint: 
    pushad

    ; All text will be printed as white on black for now
    mov ah, WHITE_ON_BLACK

    ; ebx will hold our offset
    xor ebx, ebx

.print_loop:
    ; Load a character from esi register into al 
    lodsb 

    ; If the character is null (the end of the string) jump to the end of the routine
    or al, al
    jz .print_done

    ; Calculate the correct offset into the video memory and move the character
    mov bx, [_print_offset]
    mov [ebx * 2 + VIDEO_MEMORY_ADDR], ax

    ; Increment the print offset
    inc bx

    ; Check if we reached the end of the video memory
    cmp bx, SCREEN_CAPACITY
    jne .continue_loop

.reset_offset:
    ; Reset if reached the end of the video text buffer
    mov bx, 0

.continue_loop:
    ; Store the offset back into memory and continue
    mov [_print_offset], bx
    jmp .print_loop

.print_done:
    popad
    ret

;
; Prints a byte as hex ("0x??")
; @input al - byte to print
;
kprint_byte:
    pushad
    
    ; Convert byte into hex chars
    call byte_to_hex

    ; Insert into template string
    mov byte [.template + 2], ah
    mov byte [.template + 3], al

    mov si, .template
    call kprint

    popad
    ret

    .template: db "0x??", 0

;
; Accepts an input byte and returns the char codes for it's individual nibbles
;
; @input al - byte to conver to hex
; @ouput al - first nibble (LS)
; @output ah - second nibble (MS)
;
byte_to_hex:
    push ebx

    ; Make a copy of the input byte
    mov ah, al
    
    ; Get least significant nibble in al
    and al, 0x0F

    ; Get most significant nibble in ah
    shr ah, 4

    ; Clear upper bits of ebx so we can use it as an offset into the table
    xor ebx, ebx

    ; Index into the table to get the first char code
    mov bl, al
    mov al, [.table + ebx]

    ; Index into the table to get the second char code
    mov bl, ah
    mov ah, [.table + ebx]

    pop ebx
    ret

    .table: db "0123456789ABCDEF"

;
; Prints a given string into the VGA video memory in text mode and moves the cursor down to the next line
; @input esi - Pointer to the string to print (null terminated)
;
kprintln:
    pushad

    ; Print the string
    call kprint

    ; Calculate the index into the current line
    ; dx := _print_offset % 80
    xor dx, dx
    mov ax, [_print_offset]
    mov bx, 80
    div bx

    ; Calculate the number of remaining characters in the current line
    ; bx := 80 - (_print_offset % 80)
    sub bx, dx

    ; Move the print offset to the next line
    ; _print_offset += 80 - (_print_offset % 80)
    mov ax, [_print_offset]
    add ax, bx

    ; Reset the offset if we reached the end of the screen
    cmp ax, SCREEN_CAPACITY
    jl .store_offset

    .reset_offset:
        mov ax, 0

    .store_offset:
        mov [_print_offset], ax

    popad
    ret

;
; Prints an empty line
;
kprint_empty_line:
    push esi

    mov esi, .empty_str
    call kprintln

    pop esi
    ret

    .empty_str: db 0

;
; Function to clear the entire video buffer
;
clear_screen:
    pushad

    ; Clear upper bits of EDI (counter)
    xor edi, edi

.clear_loop:
    ; Use di as an index into the video memory clearing 1 char (2 bytes) at a time
    mov word [edi * 2 + VIDEO_MEMORY_ADDR], 0

    ; Increment the counter
    inc di

    ; Check if we reached the end of the video memory
    cmp di, SCREEN_CAPACITY
    jne .clear_loop

.clear_done:
    popad
    ret

%endif