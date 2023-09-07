org 0x1000
bits 16

; The second stage of out bootloader is responsible for, loading the kernel 
; into memory, setting up the Global Descriptor Table (GDT), making the jump to
; 32-bit protected mode, and finally calling the kernel entry point.

main:
    ; Load function pointers from the boot sector
    .load_function_pointers:
        mov [print_fp], ax
        mov [fat_find_and_read_root_file_fp], bx

        mov si, stage2_start_msg
        call [print_fp]

    ; Load the kernel from the disk using the FAT driver from the boot sector
    .load_kernel_from_disk:
        mov si, kernel_file_name
        mov ax, KERNEL_ADDR_SEGMENT
        mov es, ax
        mov bx, KERNEL_ADDR_OFFSET
        call [fat_find_and_read_root_file_fp]

        mov si, kernel_load_msg
        call [print_fp]

    ; Switch over the CPU into 32-bit protected mode with flat memory
    ; addressing (No page table just yet)
    .switch_to_32_bits:
        ; Disable all CPU interrupts
        cli
        
        ; Load our GDT
        lgdt [GDT_descriptor]
        
        ; Switch to protected mode
        mov eax, cr0
        or eax, 1
        mov cr0, eax

        ; Reload the segment registers
        call gdt_reload_segments

    [bits 32]
    ; Set up kernel stack
    .create_kernel_stack:
        mov ebp, KERNEL_STACK_ADDR
        mov esp, ebp

    ; Call the kernel entry point
    .jump_to_kernel:
        jmp KERNEL_ADDR

;
; Halt the processor if the kernel exited for some reason
; 
halt:
    hlt
    jmp halt

; Address Constants
KERNEL_STACK_ADDR equ 0x10000
KERNEL_ADDR_SEGMENT equ 0x1000
KERNEL_ADDR_OFFSET equ 0x0000
KERNEL_ADDR equ KERNEL_ADDR_SEGMENT * 0x10 + KERNEL_ADDR_OFFSET

%include "gdt.asm"

; Pointers to functions in the boot sector (used to remove code duplication)
print_fp: dw 0
fat_find_and_read_root_file_fp: dw 0

; String Data
stage2_start_msg: db 'Loaded stage 2 from disk! Loading kernel...', 0x0D, 0x0A, 0
kernel_load_msg: db 'Loaded kernel from disk! Entering protected mode...', 0x0D, 0x0A, 0
kernel_file_name: db 'KERNEL  BIN', 0