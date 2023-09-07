org 0x10000
bits 32

kmain:
    mov esi, kernel_msg
    call kprint

halt:
    ; Halt the processor
    hlt
    jmp halt

%include "kprint.asm"

kernel_msg: db 'This string only exists in the kernel!', 0