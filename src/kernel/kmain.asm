org 0x10000
bits 32

kmain:
    call clear_screen

.print_hello:
    mov esi, kernel_msg
    call kprint

halt:
    ; Halt the processor
    hlt
    jmp halt

%include "video.asm"

kernel_msg: db 'Hello from the kernel!', 0