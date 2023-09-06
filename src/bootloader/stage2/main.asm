org 0x1000
bits 16

; The second stage of out bootloader is responsible for, loading the kernel 
; into memory, setting up the Global Descriptor Table (GDT), making the jump to
; 32-bit protected mode, and finally calling the kernel entry point.

main:
    ; Load function pointers from the boot sector
    mov [print_fp], ax
    mov [fat_find_and_read_root_file_fp], bx

    mov si, stage2_boot_msg
    call [print_fp]

halt:
    ; Halt the processor
    hlt
    jmp halt

stage2_boot_msg: db "We loaded stage 2 from disk and set up function pointers!", 0x0D, 0x0A, 0

; Pointers to functions in the boot sector (used to remove code duplication)
print_fp: dw 0
fat_find_and_read_root_file_fp: dw 0