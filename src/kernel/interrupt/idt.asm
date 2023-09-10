%ifndef IDT_ASM
%define IDT_ASM

%include "interrupt/pic.asm"
%include "interrupt/isr.asm"

IDT_TYPE_EXCEPTION equ 0x8F ; 0b1000_1111 (DPL = 0, Gate Type = 32-bit trap gate)
IDT_TYPE_SOFTWARE equ 0xEF ; 0b1000_1111 (DPL = 3, Gate Type = 32-bit trap gate)
IDT_TYPE_IRQ equ 0x8E ; 0b1000_1110 (DPL = 0, Gate Type = 32-bit interrupt gate)

; Reserve room for 256 IDT entries
IDT_start:
    times 256 dq 0
IDT_end:

;
; Compute values for GDT descriptor using the GDT definition
;
IDT_descriptor:
    ; Size
    dw IDT_end - IDT_start - 1 
    ; Start
    dd IDT_start

idt_init:
    pushad

    ; Macro to register a default exception handler
    %macro register_eception_handler 1
        mov eax, isr_exception
        mov bl, IDT_TYPE_EXCEPTION
        mov ecx, %1
        call idt_update
    %endmacro

    ; Register all possible exception handlers to use our default
    %assign i 0 
    %rep    32 
        register_eception_handler i
    %assign i i+1 
    %endrep

    ; Keyboard handler
    mov eax, isr_keyboard
    mov bl, IDT_TYPE_IRQ
    mov ecx, PIC1_OFFSET + 1
    call idt_update

    ; Spurious Interrupt handler
	; mov	eax,	isr_spurious_interrupt
	; mov	bl,	IDT_TYPE_IRQ
	; mov	ecx,	255
	; call idt_update

    ; Load IDTR
    lidt [IDT_descriptor]

    popad
    ret

;
; Inserts an interrupt handler into the IDT
; @input eax - pointer to interrupt handler
; @input bl - interrupt type
; @input ecx - entry number
;
idt_update:
    pushad

    ; Calculate start address of entry
    lea edx, [IDT_start + ecx * 8]
    
    ; Lower 16 bits of offset
    mov word [edx], ax

    ; Segment selector (code segment)
    mov word [edx + 2], 0x08

    ; Reserved
    mov byte [edx + 4], 0

    ; Gate Flags
    mov byte [edx + 5], bl

    ; Upper 16 bits of offset
    shr eax, 16
    mov word [edx + 6], ax

    popad
    ret

%endif