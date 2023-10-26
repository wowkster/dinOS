bits 32
org 0x10000

%include "macros.asm"

kmain:
    .clear_vga_buffer:
        call clear_screen

    mkprintln('dinOS v0.0.1-beta')
    mkprintln('Interrupts initialized!')
    
    .enable_interrupts:
        call init_interrupts
    

    .init_drivers:
        call keyboard_driver_init
halt:
    ; Halt the processor
    hlt
    jmp halt

%include "vga.asm"
%include "interrupt/init.asm"
%include "drivers/keyboard.asm"