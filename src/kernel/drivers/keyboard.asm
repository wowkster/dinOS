%ifndef DRIVERS_KEYBOARD_ASM
%define DRIVERS_KEYBOARD_ASM

%include "vga.asm"

KEYBOARD_PORT equ 0x60

;
; Handler for keyboard interrupts as they come in from the PS/2 controller
;
keyboard_driver_handle_interrupt:
    push eax
    push esi

    ; Read in scan code
    in al, KEYBOARD_PORT

    ; Print the byte to the screen
    call kprint_byte

    ; Print a new line
    mov esi, 0
    call kprintln

    pop esi
    pop eax
    ret

%endif