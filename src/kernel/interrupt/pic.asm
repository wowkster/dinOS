%ifndef PIC_ASM
%define PIC_ASM

;
; Driver functions for the 8259A PIC used on x86 computers
;
; 8259A Datasheet: https://pdos.csail.mit.edu/6.828/2010/readings/hardware/8259A.pdf
; Visual diagrams explaining command words: https://www.geeksforgeeks.org/command-words-of-8259-pic
; OS Dev Wiki Page: https://wiki.osdev.org/PIC#Programming_the_PIC_chips
;

; IO port definitions
PIC1_COMMAND_PORT equ 0x20
PIC1_DATA_PORT equ 0x21
PIC2_COMMAND_PORT equ 0xA0
PIC2_DATA_PORT equ 0xA1
UNUSED_PORT equ 0x80

; PIC IRQ offsets
PIC1_OFFSET equ 0x70 ; IRQs 0-7 will be mapped to 0x70-77
PIC2_OFFSET equ 0x78  ; IRQs 8-15 will be mapped to 0x78-7F

; Initialization Command Flags
ICW1_ICW4 equ	0x01		; Indicates that ICW4 will be present
ICW1_SINGLE equ	0x02		; Single (default is cascade) mode 
ICW1_INTERVAL4 equ	0x04	; Call address interval 4 (default is 8) 
ICW1_LEVEL equ	0x08		; Level triggered (default is edge) mode 
ICW1_INIT equ	0x10		; Initialization - required! 

ICW4_8086 equ	0x01		; 8086/88 (default is MCS-80/85) mode 
ICW4_AUTO equ	0x02		; Auto (default is normal) EOI 
ICW4_BUF_SLAVE equ	0x08	; Buffered mode/slave 
ICW4_BUF_MASTER equ	0x0C	; Buffered mode/master 
ICW4_SFNM equ	0x10		; Special fully nested (default is not) 

; OCW1 Commands
OCW1_DISABLE_ALL_CMD equ 0xFF               ; Masks all the bits of the IMR
OCW1_ENABLE_ALL_CMD equ 0x00                ; Un-masks all the bits of the IMR

; OCW2 Flags
OCW2_R equ 0x80       ; Rotate flag
OCW2_SL equ 0x40      ; Select flag 
OCW2_EOI equ 0x20     ; EOI flag

; OCW2 Commands
OCW2_NS_EOI_CMD equ OCW2_EOI                            ; Non-specific end-of-interrupt command
OCW2_S_EOI_CMD equ OCW2_SL | OCW2_EOI                   ; Specific end-of-interrupt command (L0-L2 bits are used)
OCW2_ROTATE_NS_EIO_CMD equ OCW2_R | OCW2_EOI            ; Rotate in non-specific EOI mode command
OCW2_ROTATE_AEIO_SET_CMD equ OCW2_R                     ; Rotate in automatic EOI mode (set) command
OCW2_ROTATE_AEIO_CLR_CMD equ 0x00                       ; Rotate in automatic EOI mode (clear) command
OCW2_ROTATE_S_EOI_CMD equ OCW2_R | OCW2_SL | OCW2_EOI   ; Rotate on specific EOI command (L0-L2 bits are used)
OCW2_SET_PRIORITY_CMD equ OCW2_R | OCW2_SL              ; Set priority command (L0-L2 bits are used)

; OCW3 Flags
OCW3_CMD equ 0x08   ; Marks a command as OCW3 (as apposed to OCW2)
OCW3_RIS equ 0x01   ; Read In-Service Register (ISR) - Reads IR if not set
OCW3_RR equ 0x02    ; Read Register
OCW3_P equ 0x04     ; Poll cmd bit
OCW3_SMM equ 0x20   ; Special Mask Mode
OCW3_ESMM equ 0x40  ; Enable Special Mask Mode

; OCW3 Commands
OCW3_READ_ISR_CMD equ OCW3_CMD | OCW3_RR | OCW3_RIS ; Reads the In-Service Register (ISR)
OCW3_READ_IRR_CMD equ OCW3_CMD | OCW3_RR            ; Reads the Interrupt Request Register (IRR)

; IRQ Numbers
IRQ_KEYBAORD equ 1

;
; Wait a very small amount of time (1 to 4 microseconds, generally). Useful for
; implementing a small delay for PIC remapping on old hardware or generally as
; a simple but imprecise wait.
;
; https://wiki.osdev.org/Inline_Assembly/Examples#IO_WAIT
;
io_wait:
    push ax

    ; We can do an IO op on any unused port but we use 0x80
    mov al, 0
    out UNUSED_PORT, al

    pop ax
    ret

;
; Programs the Programmable Interrupt Controllers (PICs) to remap the interrupt 
; numbers away from CPU reserved interrupt numbers
;
pic_remap_offsets:   
    pushad

    mov ebp, esp
    sub esp, 2

    ; Store original masks onto the stack
    .save_masks:
        in al, PIC1_DATA_PORT
        mov [esp + 1], al
    
        in al, PIC2_DATA_PORT
        mov [esp + 2], al

    ; ICW1: Starts the initialization sequence (in cascade mode)
    .icw1:
        mov al, ICW1_INIT | ICW1_ICW4
        out PIC1_COMMAND_PORT, al
        call io_wait
        out PIC2_COMMAND_PORT, al
        call io_wait

    ; ICW2: Programs the offset for each PIC
    .icw2:
        mov al, PIC1_OFFSET
        out PIC1_DATA_PORT, al
        call io_wait
        mov al, PIC2_OFFSET
        out PIC2_DATA_PORT, al
        call io_wait

    ; ICW3: Tell Master PIC that there is a slave PIC at IRQ2 (0000 0100)
    .icw3_master:
        mov al, 0b0000_0100     ; bit 2 set means IRQ2 has a slave
        out PIC1_DATA_PORT, al
        call io_wait

    ; ICW3: Tell Slave PIC its cascade identity (0000 0010)
    .icw3_slave:
        mov al, 0b0000_0010     ; bits 0-2 tell the slave which IRQ line it is
                                ; connected to on the master (2 in this case)
        out PIC2_DATA_PORT, al
        call io_wait

    ; ICW4: Have the PICs use 8086 mode (and not 8080 mode)
    .icw4:
        mov al, ICW4_8086
        out PIC1_DATA_PORT, al
        call io_wait
        out PIC2_DATA_PORT, al
        call io_wait

    ; Restore masks we saved earlier
    .restore_masks:
        mov al, [esp + 1]
        out PIC1_DATA_PORT, al
        
        mov al, [esp + 2]
        out PIC2_DATA_PORT, al

    ; Restore the stack for return
    mov esp, ebp

    popad
    ret

;
; Disables the PIC to use the processor local APIC and the IOAPIC
;
; Sends OCW1 with all bits set (masks all the IRQ lines)
;
pic_disable_all:
    mov al, OCW1_DISABLE_ALL_CMD
    out PIC2_DATA_PORT, al
    out PIC1_DATA_PORT, al

;
; Enables all IRQs on both PICs
;
; Sends OCW1 with all bits cleared (unmasks all the IRQ lines)
;
pic_enable_all:
    mov al, OCW1_ENABLE_ALL_CMD
    out PIC2_DATA_PORT, al
    out PIC1_DATA_PORT, al

;
; Sets a bit in the Interrupt Mask Register (IMR) of the appropriate PIC
; @input al - IRQ line
;
pic_set_mask:
    pushad

    ; Store the IRQ line into cl
    mov cl, al

    ; Branch on IRQ line to use the right port
    cmp cl, 8
    jge .slave_mask_bit

    ; Set the port to PIC1
    .master_mask_bit:
        mov dx, PIC1_DATA_PORT

        jmp .create_mask

    ; Set the port to PIC2 and remap the IRQ line to 0-7
    .slave_mask_bit:
        mov dx, PIC2_DATA_PORT
        sub cl, 8

    ; Create our bit mask and store in bl
    .create_mask:
        mov bl, 1
        shl bl, cl

    ; Communicate with the PIC
    .io:
        ; Read in the current value of the IMR
        in al, dx

        ; Or the current value with the bit mask we created
        or al, bl

        ; Write our new IRQ mask to the IMR
        out dx, al

    popad
    ret

;
; Clears a bit in the Interrupt Mask Register (IMR) of the appropriate PIC
; @input al - IRQ line
;
pic_clear_mask:
    pushad

    ; Store the IRQ line into cl
    mov cl, al

    ; Branch on IRQ line to use the right port
    cmp cl, 8
    jge .slave_mask_bit

    ; Set the port to PIC1
    .master_mask_bit:
        mov dx, PIC1_DATA_PORT

        jmp .create_mask

    ; Set the port to PIC2 and remap the IRQ line to 0-7
    .slave_mask_bit:
        mov dx, PIC2_DATA_PORT
        sub cl, 8

    ; Create our bit mask and store in bl
    .create_mask:
        mov bl, 1
        shl bl, cl
        not bl

    ; Communicate with the PIC
    .io:
        ; Read in the current value of the IMR
        in al, dx

        ; Or the current value with the bit mask we created
        and al, bl

        ; Write our new IRQ mask to the IMR
        out dx, al

    popad
    ret

;
; Acknowledges the interrupt from the PIC and tells it that we processed the
; interrupt by sending OCW2 with 
; @input ah - IRQ number (0-15)
;
pic_send_eoi:
    push eax

    ; Load the command we want to send into al
    mov al, OCW2_NS_EOI_CMD

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

;
; Reads the Interrupt Request Register (IRR)
; @output ax - Combined IR registers (master in bits 0-7 and slave in bits 8-15)
;
pic_get_irr:
    ; Output command to read from IRR
    mov al, OCW3_READ_IRR_CMD
    out PIC1_COMMAND_PORT, al
    out PIC2_COMMAND_PORT, al

    ; Read slave bits and move into upper 8 of ax
    in al, PIC2_COMMAND_PORT
    mov ah, al

    ; Read mast bits into lower 8 of ax
    in al, PIC1_COMMAND_PORT

;
; Reads the In-Service Register (ISR)
; @output ax - Combined IS registers (master in bits 0-7 and slave in bits 8-15)
;
pic_get_isr:
    ; Output command to read from IRR
    mov al, OCW3_READ_ISR_CMD
    out PIC1_COMMAND_PORT, al
    out PIC2_COMMAND_PORT, al

    ; Read slave bits and move into upper 8 of ax
    in al, PIC2_COMMAND_PORT
    mov ah, al

    ; Read mast bits into lower 8 of ax
    in al, PIC1_COMMAND_PORT

%endif