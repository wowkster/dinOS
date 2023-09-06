org 0x8000
bits 16

main:
    ; Load function pointers from the boot sector
    mov [print_fp], ax
    mov [fat_find_and_read_root_file_fp], bx

    mov si, kernel_boot_msg
    call [print_fp]

halt:
    ; Halt the processor
    hlt
    jmp halt

kernel_boot_msg: db "We loaded the kernel from disk and setup function pointers!", 0x0D, 0x0A, 0

; Pointers to functions in the boot sector (used to remove code duplication)
print_fp: dw 0
fat_find_and_read_root_file_fp: dw 0