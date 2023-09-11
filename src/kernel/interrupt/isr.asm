%ifndef IDR_ASM
%define ISR_ASM

%include "vga.asm"
%include "interrupt/pic.asm"
%include "drivers/keyboard.asm"

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

;
; Interrupt Service Routine for keyboard interrupts
;
isr_keyboard:
    push eax

    ; Call keyboard driver hook
    call keyboard_driver_handle_interrupt

    ; Acknowledge PIC IRQ
    mov ah, 1
    call pic_send_eoi

    pop eax
    iret

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
