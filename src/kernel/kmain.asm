org 0x10000
bits 32

kmain:
    call clear_screen

.print_hello:
    mov esi, kernel_msg_1
    call kprintln

    mov esi, kernel_msg_2
    call kprintln

halt:
    ; Halt the processor
    hlt
    jmp halt

%include "video.asm"

kernel_msg_1: db 'Hello from the kernel!', 0
kernel_msg_2: db 'This tetx is on another line!', 0