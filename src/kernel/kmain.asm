org 0x10000
bits 32

kmain:
    .clear_vga_buffer:
        call clear_screen

    .print_hello:
        mov esi, kernel_msg_1
        call kprintln

        mov esi, kernel_msg_2
        call kprintln
    
    .enable_interrupts:
        call init_interrupts

halt:
    ; Halt the processor
    hlt
    jmp halt

%include "vga.asm"
%include "interrupt/init.asm"

kernel_msg_1: db 'Hello from the kernel!', 0
kernel_msg_2: db 'This tetx is on another line!', 0