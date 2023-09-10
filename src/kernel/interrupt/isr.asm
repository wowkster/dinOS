%ifndef IDR_ASM
%define ISR_ASM

%include "vga.asm"
%include "interrupt/pic.asm"

;
; General exception handler
;
isr_exception:
    cli

    mov esi, exception_msg
    call kprintln

    .halt:
        hlt
        jmp .halt

exception_msg: db 'Unhandled Exception! Halting...', 0

KEYBOARD_PORT equ 0x60

;
; Interrupt Service Routine for keyboard interrupts
;
isr_keyboard:
    pushad

    ; Print initial message
    mov esi, keyboard_msg
    call kprint

    ; Read in scan code
    in al, KEYBOARD_PORT

    ; Print the byte to the screen
    call kprint_byte

    ; Print a new line
    call kprint_empty_line

    ; Acknowledge PIC IRQ
    mov ah, 1
    call pic_send_eoi

    ; Return from the interrupt
    popad
    iret

keyboard_msg: db 'Caught keyboard interrupt: ', 0

;
; Handler for spurious interrupts
;
isr_spurious_interrupt:
    mov si, spurious_msg
    call kprintln

    hlt
    jmp $

spurious_msg: db 'Caught spurious interrupt!', 0

%endif
