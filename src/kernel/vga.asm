%ifndef PRINT_ASM
%define PRINT_ASM

%include "mem.asm"
%include "macros.asm"

VIDEO_MEMORY_ADDR equ 0xB8000

SCREEN_ROWS equ 25
SCREEN_COLS equ 80
SCREEN_HEIGHT equ SCREEN_ROWS
SCREEN_WIDTH equ SCREEN_COLS
SCREEN_CAPACITY equ SCREEN_ROWS * SCREEN_COLS

VGA_COLOR_FG_BLACK equ 0x00
VGA_COLOR_FG_BLUE equ 0x01
VGA_COLOR_FG_GREEN equ 0x02
VGA_COLOR_FG_CYAN equ 0x03
VGA_COLOR_FG_RED equ 0x04
VGA_COLOR_FG_MAGENTA equ 0x05
VGA_COLOR_FG_YELLOW equ 0x06
VGA_COLOR_FG_LIGHT_GRAY equ 0x07
VGA_COLOR_FG_DARK_GRAY equ 0x08
VGA_COLOR_FG_BRIGHT_BLUE equ 0x09
VGA_COLOR_FG_BRIGHT_GREEN equ 0x0A
VGA_COLOR_FG_BRIGHT_CYAN equ 0x0B
VGA_COLOR_FG_BRIGHT_RED equ 0x0C
VGA_COLOR_FG_BRIGHT_MAGENTA equ 0x0D
VGA_COLOR_FG_BRIGHT_YELLOW equ 0x0E
VGA_COLOR_FG_WHITE equ 0x0F

; VGA IO Ports
VGA_ADDR_PORT equ 0x3D4
VGA_DATA_PORT equ 0x3D5
VGA_MAX_SCAN_LINE_REGISTER equ 0x09
VGA_CURSOR_START_REGISTER equ 0x0A
VGA_CURSOR_END_REGISTER equ 0x0B
VGA_CURSOR_LOC_LOW_REGISTER equ 0x0F
VGA_CURSOR_LOC_HIGH_REGISTER equ 0x0E

VGA_CURSOR_DISABLE equ 0x20

; Static variable to hold our offset into the video memory
_print_offset: dw 0

; 
; Prints a given string into the VGA video memory in text mode with the provided color
; @input esi - Pointer to the string to print (null terminated)
; @input ah - Color byte to use when printing
;
kprint_color: 
    pushad

    ; If the input is a null pointer, do nothing
    cmp esi, 0
    je .finished

    ; ebx will hold our offset
    xor ebx, ebx

    ; Load a character and break if it's null (the end of the string)
    .print_loop:
        lodsb 

        cmp al, 0
        je .finished

    ; If there is enugh room on the screen for the next character, just print it. Otherwise, scroll the screen first
    .scroll_if_needed:
        mov bx, [_print_offset]
        cmp bx, SCREEN_CAPACITY 
        jne .print_char

        call scroll_screen
        mov bx, SCREEN_COLS * (SCREEN_ROWS - 1)

    ; Calculate the correct offset into the video memory and move the character
    .print_char:
        mov [ebx * 2 + VIDEO_MEMORY_ADDR], ax

    ; Increment the print offset, store it back into memory, and continue
    .continue_loop:
        inc bx
        mov [_print_offset], bx

        ; Update the cursor position
        push eax
        mov ax, bx
        call vga_update_cursor_with_offset
        pop eax

        jmp .print_loop

    .finished:
        popad
        ret

; 
; Prints a given string into the VGA video memory in text mode
; @input esi - Pointer to the string to print (null terminated)
;
kprint:
    pushad

    mov ah, VGA_COLOR_FG_WHITE
    call kprint_color

    popad
    ret  

;
; Prints a given string into the VGA video memory in text mode and moves the cursor down to the next line
; @input esi - Pointer to the string to print (null terminated)
;
kprintln:
    pushad

    ; Print the string
    call kprint

    ; If we're at the end of the text buffer, only scroll. Otherwise, move cursor to start of next line
    mov ax, [_print_offset]
    cmp ax, SCREEN_CAPACITY
    jne .move_cursor

    ; Scroll the screen and keep cursor at end of buffer
    .scroll:
        call scroll_screen
        jmp .finished

    ; Move the cursor to the start of the next line
    .move_cursor:
        ; Calculate the index into the current line
        ; dx := _print_offset % SCREEN_COLS
        xor dx, dx
        mov ax, [_print_offset]
        mov bx, SCREEN_COLS
        div bx

        ; Calculate the number of remaining characters in the current line
        ; bx := 80 - (_print_offset % 80)
        sub bx, dx

        ; Move the print offset to the next line
        ; _print_offset += 80 - (_print_offset % 80)
        mov ax, [_print_offset]
        add ax, bx
        mov word [_print_offset], ax
        call vga_update_cursor_with_offset

    .finished:
        popad
        ret

;
; Prints the given byte as a boolean (0 = false, anything else = true)
; @input al - bool to print
;
kprint_bool:
    pushad
    
    cmp al, 0
    je .false

    .true:
        mov esi, .true_str
        mov ah, VGA_COLOR_FG_BRIGHT_GREEN
        jmp .print

    .false:
        mov esi, .false_str
        mov ah, VGA_COLOR_FG_BRIGHT_RED

    .print:
        call kprint_color

    popad
    ret

    .true_str: db "true", 0
    .false_str: db "false", 0

;
; Prints the value of the zero flag as a boolean
; @input zf - zero flag
;
kprint_zf_as_bool:
    pushad

    lahf
    mov al, ah
    and al, 001000000b
    shr al, 6

    call kprint_bool

    popad
    ret

;
; Prints the given byte as an ASCII character
; @input al - char to print
;
kprint_char:
    pushad
    
    mov [.template], al

    mov esi, .template
    mov ah, VGA_COLOR_FG_BRIGHT_CYAN
    call kprint_color

    popad
    ret

    .template: db "?", 0

;
; Prints a byte as hex ("0x??")
; @input al - byte to print
;
kprint_byte:
    pushad
    
    ; Convert byte into hex chars
    call byte_to_hex

    ; Insert into template string
    mov byte [.template + 2], ah
    mov byte [.template + 3], al

    mov esi, .template
    mov ah, VGA_COLOR_FG_LIGHT_GRAY
    call kprint_color

    popad
    ret

    .template: db "0x??", 0

;
; Prints a word as hex ("0x????")
; @input ax - word to print
;
kprint_word:
    pushad
    
    ; Store the upper byte in bl
    mov bl, ah

    ; Convert first byte into hex chars
    call byte_to_hex

    ; Insert first byte (LSB) into template string
    mov byte [.template + 4], ah
    mov byte [.template + 5], al

    ; Restore the upper byte
    mov al, bl

    ; Convert second byte into hex chars
    call byte_to_hex

    ; Insert second byte (MSB) into template string
    mov byte [.template + 2], ah
    mov byte [.template + 3], al

    mov esi, .template
    mov ah, VGA_COLOR_FG_LIGHT_GRAY
    call kprint_color

    popad
    ret

    .template: db "0x????", 0

;
; Prints a dword as hex ("0x????????")
; @input eax - word to print
;
kprint_dword:
    pushad

    ; Store the upper byte in bl
    mov bl, ah

    ; Convert first byte into hex chars
    call byte_to_hex

    ; Insert first byte (LSB) into template string
    mov byte [.template + 8], ah
    mov byte [.template + 9], al

    ; Restore the upper byte
    mov al, bl

    ; Convert second byte into hex chars
    call byte_to_hex

    ; Insert second byte (MSB) into template string
    mov byte [.template + 6], ah
    mov byte [.template + 7], al

    ; Shift the MSW into the LSW
    shr eax, 16

    ; Store the upper byte in bl
    mov bl, ah

    ; Convert first byte into hex chars
    call byte_to_hex

    ; Insert first byte (LSB) into template string
    mov byte [.template + 4], ah
    mov byte [.template + 5], al

    ; Restore the upper byte
    mov al, bl

    ; Convert second byte into hex chars
    call byte_to_hex

    ; Insert second byte (MSB) into template string
    mov byte [.template + 2], ah
    mov byte [.template + 3], al

    mov esi, .template
    mov ah, VGA_COLOR_FG_LIGHT_GRAY
    call kprint_color

    popad
    ret

    .template: db "0x????????", 0

;
; Accepts an input byte and returns the char codes for it's individual nibbles
;
; @input al - byte to conver to hex
; @ouput al - first nibble (LS)
; @output ah - second nibble (MS)
;
byte_to_hex:
    push ebx

    ; Make a copy of the input byte
    mov ah, al
    
    ; Get least significant nibble in al
    and al, 0x0F

    ; Get most significant nibble in ah
    shr ah, 4

    ; Clear upper bits of ebx so we can use it as an offset into the table
    xor ebx, ebx

    ; Index into the table to get the first char code
    mov bl, al
    mov al, [.table + ebx]

    ; Index into the table to get the second char code
    mov bl, ah
    mov ah, [.table + ebx]

    pop ebx
    ret

    .table: db "0123456789ABCDEF"

;
; Function to clear the entire video buffer
;
clear_screen:
    pushad

     ; memset the entire screen to be empty
    mov eax, VIDEO_MEMORY_ADDR ; ptr

    mov bh, VGA_COLOR_FG_WHITE 
    mov bl, 0

    mov ecx, SCREEN_CAPACITY ; num

    call memset_16

    popad
    ret

;
; Scrolls the screen by one line
;
scroll_screen:
    pushad

    ; memcpy the last 24 rows up
    mov eax, 0
    lea eax, [VIDEO_MEMORY_ADDR + eax] ; dest

    mov ebx, SCREEN_COLS * 2
    lea ebx, [VIDEO_MEMORY_ADDR + ebx] ; src

    mov ecx, SCREEN_COLS * (SCREEN_ROWS - 1) * 2 ; num

    call memcpy

    ; memset the bottom row to be empty
    mov eax, SCREEN_COLS * (SCREEN_ROWS - 1) * 2
    lea eax, [VIDEO_MEMORY_ADDR + eax] ; ptr

    mov bh, VGA_COLOR_FG_WHITE 
    mov bl, 0

    mov ecx, SCREEN_COLS ; num

    call memset_16

    popad
    ret

;
; Prints an error message and halts the processor
; @input esi - Pointer to the error message to print (null terminated)
;
__kpanic:
    ; Disable interrupts
    cli

    mkprint("KERNEL PANIC: ")

    ; Print the error message
    mov esi, eax
    call kprintln

    mkprint("    at ")

    ; Print the file name
    mov esi, ebx
    call kprint

    mkprint(":")

    ; Print the function name
    mov esi, ecx
    call kprint

    mkprint(":")

    ; Print the line number
    mov esi, edx
    call kprintln

    ; Halt the processor
    .halt:
        hlt
        jmp .halt

;
; Enables the VGA cursor in text mode
;
vga_enable_cursor:
    pushad

    ; Set Max Scan Line to 15
    mov al, VGA_MAX_SCAN_LINE_REGISTER
    mov dx, VGA_ADDR_PORT
    out dx, al

    mov al, 0x0F
    mov dx, VGA_DATA_PORT
    out dx, al

    ; Set cursor end line to 15
    mov al, VGA_CURSOR_END_REGISTER
    mov dx, VGA_ADDR_PORT
    out dx, al

    mov al, 0x0F
    mov dx, VGA_DATA_PORT
    out dx, al

    ; Set cursor start line to 14
    mov al, VGA_CURSOR_START_REGISTER
    mov dx, VGA_ADDR_PORT
    out dx, al

    mov al, 0x0E
    mov dx, VGA_DATA_PORT
    out dx, al

    popad
    ret

;
; Disables the VGA cursor in text mode
;
vga_disable_cursor:
    pushad

    mov al, VGA_CURSOR_START_REGISTER
    mov dx, VGA_ADDR_PORT
    out dx, al

    mov al, VGA_CURSOR_DISABLE
    mov dx, VGA_DATA_PORT
    out dx, al

    popad
    ret

;
; Update the VGA test mode cursor position
; @input al - Cursor row
; @input ah - Cursor column
;
vga_update_cursor:
    pushad

    ; bx = offset of row (row * screen width)
    mov bx, 0
    mov bl, al
    imul bx, SCREEN_WIDTH

    ; bx = offset of row + column   
    shr ax, 8
    add bx, ax

    ; Update the cursor position (low byte)
    mov al, VGA_CURSOR_LOC_LOW_REGISTER
    mov dx, VGA_ADDR_PORT
    out dx, al

    mov al, bl
    mov dx, VGA_DATA_PORT
    out dx, al

     ; Update the cursor position (high byte)
    mov al, VGA_CURSOR_LOC_HIGH_REGISTER
    mov dx, VGA_ADDR_PORT
    out dx, al

    mov al, bh
    mov dx, VGA_DATA_PORT
    out dx, al

    popad
    ret

;
; Update the VGA test mode cursor position with a precalculated offset
; @input ax - Cursor offset
;
vga_update_cursor_with_offset:
    pushad

    mov bx, ax

    ; Update the cursor position (low byte)
    mov al, VGA_CURSOR_LOC_LOW_REGISTER
    mov dx, VGA_ADDR_PORT
    out dx, al

    mov al, bl
    mov dx, VGA_DATA_PORT
    out dx, al

     ; Update the cursor position (high byte)
    mov al, VGA_CURSOR_LOC_HIGH_REGISTER
    mov dx, VGA_ADDR_PORT
    out dx, al

    mov al, bh
    mov dx, VGA_DATA_PORT
    out dx, al

    popad
    ret

%endif