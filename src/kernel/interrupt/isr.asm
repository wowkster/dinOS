%ifndef IDR_ASM
%define ISR_ASM

%include "vga.asm"
%include "interrupt/pic.asm"
%include "drivers/keyboard/keyboard.asm"

;
; General exception handler
;
isr_exception:
    cli

    kpanic('isr_exception', 'Unhandled Exception! Halting...')

;
; Interrupt Service Routine for keyboard interrupts
;
isr_keyboard:
    push eax

    ; Call keyboard driver hook
    call keyboard_driver_handle_interrupt

    ; Acknowledge PIC IRQ
    mov ah, IRQ_KEYBAORD
    call pic_send_eoi

    pop eax
    iret

;
; Handler for spurious interrupts
;
isr_spurious_interrupt:
    kpanic('isr_spurious_interrupt', 'Caught spurious interrupt!')

%endif
