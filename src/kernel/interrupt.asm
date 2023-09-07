;
; Code related to setting up CPU interrupts for our operating system
; https://wiki.osdev.org/Interrupts
;

; IO port definitions
PIC1_COMMAND_PORT equ 0x20
PIC1_DATA_PORT equ 0x21
PIC2_COMMAND_PORT equ 0xA0
PIC2_DATA_PORT equ 0xA1

; PIC IRQ offsets
PIC1_OFFSET equ 0x70 ; IRQs 0-7 will be mapped to 0x70-77
PIC2_OFFSET equ 0x78  ; IRQs 8-15 will be mapped to 0x78-7F

; PIC command definitions
PIC_EOI equ 0x20 ; End-of-interrupt command

;
; Initialize the Interrupt Descriptor Table (IDT) and enable interrupts
;
init_interrupts:
    ; TODO

    ; Enables CPU interrupts again (was previously disabled in the bootloader)
    sti

;
; Programs the Programmable Interrupt Controllers (PICs) to remap the interrupt 
; numbers away from CPU reserved interrupt numbers
;
program_pic_controllers:   
    pusha

    mov ebp, esp
    sub esp, 2

    ; Store original masks onto the stack
    .save_masks:
        in al, PIC1_DATA_PORT
        mov [esp + 1], al
    
        in al, PIC2_DATA_PORT
        mov [esp + 2], al

    
    ; TODO

    ; Restore masks we saved earlier
    .restore_masks:
        mov al, [esp + 1]
        out PIC1_DATA_PORT, al
        
        mov al, [esp + 2]
        out PIC2_DATA_PORT, al

    .program_done:
        popa
        ret



;
; Acknowledges the interrupt from the PIC and tells it that we processed the interrupt
; @input ah - IRQ number (0-15)
;
acknowledge_pic_interrupt:
    push eax

    ; Load the command we want to send into al
    mov al, PIC_EOI

    ; Tell the master PIC that it's ok to send more interrupts
    .master_pic:
        out PIC1_COMMAND_PORT, al

    ; If the IRQ number is less than 8, we only need to notify the master PIC
    .check_irq_number:
        cmp ah, 8
        jle .acknowledge_done

    ; Tell the slave PIC that it's ok to send more interrupts
    .slave_pic:
        out PIC2_COMMAND_PORT, al

    .acknowledge_done:
        pop eax
        ret