%ifndef GDT_ASM
%define GDT_ASM

bits 16

; 
; GDT Definition
;
GDT_start:
    .null_descriptor:
        dd 0
        dd 0
    .code_descriptor:
        ; First 16 bits of the limit
        dw 0xFFFF
        ; First 24 bits of the base
        dw 0 ; 16 bits +
        db 0 ; 8 bits = 24
        ; presence = 1, privilege = 0, type = code/data, executable = 1, conforming = 0, readable = 1, accessed = 0
        db 0b10011010
        ; Flags (granularity = 4KiB, 32-bit = 1, 64-bit = 0) + Last 4 bits of the limit 
        db 0b1100_1111
        ; Last 8 bits of the base
        db 0
    .data_descriptor:
        ; First 16 bits of the limit
        dw 0xFFFF
        ; First 24 bits of the base
        dw 0 ; 16 bits +
        db 0 ; 8 bits = 24
        ; presence = 1, privilege = 0, type = code/data, executable = 1, direction = up, RW = 1, accessed = 0
        db 0b10010010
        ; Flags (granularity = 4KiB, 32-bit = 1, 64-bit = 0) + Last 4 bits of the limit 
        db 0b1100_1111
        ; Last 8 bits of the base
        db 0
GDT_end:

;
; Compute values for GDT descriptor using the GDT definition
;
GDT_descriptor:
    ; Size
    dw GDT_end - GDT_start - 1 
    ; Start
    dd GDT_start

;
; Compute the offsets into the GDT for each segment
;
CODE_SEG equ GDT_start.code_descriptor - GDT_start
DATA_SEG equ GDT_start.data_descriptor - GDT_start

; Reloads all the segment selectors to effectively disable segmentation
;
; Sets the code segment selector to read from the kernel code segment, and all
; other segment selectors to use the kernel data segment
;
gdt_reload_segments:
   ; Reload CS register containing code selector:
   jmp   CODE_SEG:.reload_cs
.reload_cs:
   ; Reload data segment registers:
   mov   ax, DATA_SEG
   mov   ds, ax
   mov   es, ax
   mov   fs, ax
   mov   gs, ax
   mov   ss, ax
   ret

%endif