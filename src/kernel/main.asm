org 0x8000
bits 16

main:
    mov si, kernel_boot_msg
    call print

halt:
    ; Halt the processor
    hlt
    jmp halt

kernel_boot_msg: db "We loaded the kernel from disk!", 0x0D, 0x0A, 0

%include "src/bootloader/print.asm"