org 0x10000
bits 32

kmain:
    .clear_vga_buffer:
        call clear_screen

    .print_loaded:
        mov esi, kernel_loaded_msg
        call kprintln
    
    .enable_interrupts:
        call init_interrupts
    
    .interrupts_initialized:
        mov esi, interrupts_initialized_msg
        call kprintln

halt:
    ; Halt the processor
    hlt
    jmp halt

%include "vga.asm"
%include "interrupt/init.asm"

kernel_loaded_msg: db 'Kernel kmain called!', 0
interrupts_initialized_msg: db 'Interrupts initialized!', 0
