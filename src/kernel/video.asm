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
    pusha

    ; All text will be printed as white on black for now
    mov ah, WHITE_ON_BLACK
    xor bx, bx

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
    popa
    ret

;
; Function to clear the entire video buffer
;
clear_screen:
    pusha 

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
    popa
    ret

%endif