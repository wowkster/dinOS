org 0x8000
bits 32

halt:
    ; Halt the processor
    hlt
    jmp halt

kernel_msg: db 'This string only exists in the kernel!', 0