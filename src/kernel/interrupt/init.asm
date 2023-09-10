%ifndef INIT_ASM
%define INIT_ASM

%include "interrupt/pic.asm"
%include "interrupt/idt.asm"

;
; Code related to setting up CPU interrupts for our operating system
; https://wiki.osdev.org/Interrupts
;

;
; Initialize the Interrupt Descriptor Table (IDT) and enable interrupts
;
init_interrupts:
    pushad

    ; Initializes PIC and remaps offsets away from exceptions
    call pic_remap_offsets

    ; Disable all IRQs
    call pic_disable_all

    ; Enable Keyboard IRQ
    mov al, 1
    call pic_clear_mask

    ; Load our Interrupt Descriptor Table
    call idt_init

    ; Enables CPU interrupts again (was previously disabled in the bootloader)
    sti

    popad
    ret

%endif