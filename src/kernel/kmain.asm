bits 32
org 0x10000

%include "macros.asm"

%define enumerate_driver_init_functions(O) \
    O keyboard_driver_init

%macro call_with_ok 1
    mkprint(%str(%1))
    mkprint('...')

    call %1
    mkprintln_ok()
%endmacro

kmain:
    .clear_vga_buffer:
        call clear_screen
        call vga_disable_cursor

    ; Kernel boot message
    mkprint('dinOS version 0.0.1-beta-x86 (nasm version ')
    mkprint(nasm_version)
    mkprintln(')')
    mkprintln()

    ; Initialize interrupts    
    call_with_ok init_interrupts

    ; Initialize drivers
    enumerate_driver_init_functions(call_with_ok)

    ; Enable cursor and prep for keyboard key event
    call vga_enable_cursor
    mkprintln()
halt:
    ; Halt the processor
    hlt
    jmp halt

%include "vga.asm"
%include "interrupt/init.asm"
%include "drivers/keyboard.asm"