org 0x7C00
bits 16

main:
    ; Initialize the registers of the processor to a known state
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Setup the stack to a known place in memory (grows down)
    mov sp, 0x7C00

    ; Call print with the address of our message
    mov si, os_boot_msg
    call print

    hlt ; Halt the processor

halt:
    jmp halt

print: 
    ; Preserve registers on the stack
    push si
    push ax
    push bx

print_loop:
    ; Load a character from si register into al 
    lodsb 

    ; If the character is null (the end of the string) jump to the end of the routine
    or al, al
    jz print_done

    ; BIOS interrupt to print char
    mov ah, 0x0E
    mov bh, 0
    int 0x10

    ; Continue the loop
    jmp print_loop

print_done:
    ; Pop preserved registers off the stack
    pop bx
    pop ax
    pop si
    ret

os_boot_msg: db 'Hello World!', 0x0D, 0x0A, 0

times 510-($-$$) db 0
dw 0xAA55
