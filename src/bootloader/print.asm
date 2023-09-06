%ifndef PRINT_ASM
%define PRINT_ASM

; 
; Prints a given string to the screen using BIOS interrupts
; @input si - Pointer to the string to print
;
print: 
    pusha

.print_loop:
    ; Load a character from si register into al 
    lodsb 

    ; If the character is null (the end of the string) jump to the end of the routine
    or al, al
    jz .print_done

    ; BIOS interrupt to print char
    mov ah, 0x0E
    mov bh, 0
    int 0x10

    ; Continue the loop
    jmp .print_loop

.print_done:
    popa
    ret

%endif