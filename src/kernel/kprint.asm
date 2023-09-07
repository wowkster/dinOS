%ifndef PRINT_ASM
%define PRINT_ASM

bits 32

VIDEO_MEMORY_ADDR equ 0xB8000
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
    xor bh, bh

.print_loop:
    ; Load a character from esi register into al 
    lodsb 

    ; If the character is null (the end of the string) jump to the end of the routine
    or al, al
    jz .print_done

    ; Calculate the correct offset into the video memory and move the character
    mov bl, [_print_offset]
    mov [ebx * 2 + VIDEO_MEMORY_ADDR], ax

    ; Increment the print offset (will wrap automatically)
    inc bl
    mov [_print_offset], bl

    ; Continue the loop
    jmp .print_loop

.print_done:
    popa
    ret

%endif