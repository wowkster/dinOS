%ifndef IDR_ASM
%define ISR_ASM

%include "vga.asm"

;
; General exception handler
;
isr_exception:
    cli

    mov esi, exception_msg
    call kprintln

    hlt
    jmp $

exception_msg: db 'Unhandled Exception!', 0

;
; Interrupt Service Routine for keyboard interrupts
;
isr_keyboard:
    mov si, exception_msg
    call kprintln

    iret

keyboard_msg: db 'Caught keyboard interrupt!', 0

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
