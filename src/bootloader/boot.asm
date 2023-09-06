%ifndef BOOT_ASM
%define BOOT_ASM

org 0x7C00
bits 16

; The first sector of our disk will contain a header signalling that it 
; contains a FAT12 file system, as well as the boot loader that will load the
; rest of the OS. 
;
; When the BIOS recognizes our floppy disk as bootable using the boot sector
; signature, it will load the entire boot sector into RAM at location
; 0000:7C00, and start executing it immediately. 
;
; Since the BIOS doesn't care about our FAT header, we need to jump over it's
; data to prevent the CPU from trying to interpret the header as executable 
; code. The FAT specification is aware of this, and actually enforces that the
; first 3 bytes of the boot sector be a short jump to the start of the boot code. 
; 
; After jumping over the header to our bootloader code, we will load the kernel
; from the disk, set up the Global Descriptor Table (GDT), make the jump to
; 32-bit protected mode, and finally call the kernel entry point.
;
; Refences:
; - https://dev.to/frosnerd/writing-my-own-boot-loader-3mld
; - https://www.youtube.com/@olivestemlearning
;

; FAT Boot Sector Header
; https://en.wikipedia.org/wiki/Design_of_the_FAT_file_system#Boot_Sector

; Short Jump over the header
jmp short main
nop

; FAT12 OEM Name
fat12_oem:                  db 'MSWIN4.1'

; BIOS Parameter Block
; https://en.wikipedia.org/wiki/BIOS_parameter_block#DOS_3.31_BPB
bpb_bytes_per_sector:       dw 512
bpb_sectors_per_cluster:    db 1
bpb_reserved_sectors:       dw 1
bpb_fat_count:              db 2
bpb_dir_entries_count:      dw 0x0E0
bpb_total_sectors:          dw 2880
bpb_media_descriptor_type:  db 0xF0
bpb_sectors_per_fat:        dw 9
bpb_sectors_per_track:      dw 18
bpb_heads:                  dw 2
bpb_hidden_sectors:         dd 0
bpb_large_sector_count:     dd 0

; Extended BIOS Parameter Block
; https://en.wikipedia.org/wiki/BIOS_parameter_block#DOS_4.0_EBPB
ebpb_drive_number:   db 0
ebpb_flags:          db 0
ebpb_signature:      db 0x29                   ; 4.1
ebpb_volume_id:      db 0x12, 0x34, 0x56, 0x78 ; Volume serial number
ebpb_volume_label:   db 'KAOS       ' 
ebpb_file_system_id: db 'FAT12   '

;
; Beginning of bootloader code
;
; Before the BIOS moves execution to the bootloader, it sets dl to the number
; of the physical drive that was booted from.
;
; Bootloader Memory Layout:
; 0x4E00-69FF - FAT Root Directory (14 * 512 = 7KiB)
; 0x6A00-7BFF - FAT Table (9 * 512 = 4.5KiB)
; 0x7C00-7DFF - MBR Loaded by the BIOS bootsector-loader (512B)
; 0x7E00-7FFF - Bootloader Stack (512B)
; 0x8000-FFFF - Kernel (32KiB)
;
; x86 memory layout reference: https://i.stack.imgur.com/A8gMs.png
;
main:
    ; Initialize the registers of the processor to a known state
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Setup the stack to a known place in memory (grows down)
    mov bp, 0x8000
    mov sp, bp

    ; Store the booted drive number (from BIOS) into memory
    mov [ebpb_drive_number], dl

    ; Read FAT table from disk
    .load_fat_table:
        mov ax, 1                   ; Sector 1 on the disk
        mov bx, FAT_TABLE_ADDR      ; Load into memory at this addr
        mov cl, 9                   ; Read 9 sectors
        call disk_read

    ; Read FAT root dir from disk
    .load_root_dir:
        mov ax, 19                  ; Sector 19 on the disk
        mov bx, FAT_ROOT_DIR_ADDR   ; Load into memory at this addr
        mov cl, 14                  ; Read 14 sectors
        call disk_read

    ; Load the kernel into memory
    .load_kernel:
        mov si, kernel_file_name
        mov bx, KERNEL_ADDR
        call fat_find_and_read_root_file

    ; Print a friendly message
    .print_boot_msg:
        mov si, os_boot_msg
        call print

    .jump_to_kernel:
        jmp 0x8000

halt:
    ; Halt the processor
    hlt
    jmp halt

KERNEL_ADDR equ 0x8000
FAT_TABLE_ADDR equ 0x6A00
FAT_ROOT_DIR_ADDR equ 0x4E00

%include "print.asm"
%include "disk.asm"
%include "fat.asm"

os_boot_msg: db 'KAOS booted!', 0x0D, 0x0A, 0
kernel_file_name: db 'KERNEL  BIN', 0

; Pad the MBR to 510 bytes
times 510-($-$$) db 0

; Magic bytes to signal to the BIOS that this disk is bootable
dw 0xAA55

%endif