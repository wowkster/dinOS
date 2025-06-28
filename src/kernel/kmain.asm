bits 32
org 0x10000

%include "macros.asm"

%define enumerate_driver_init_functions(O) \
    O keyboard_driver_init

%macro call_with_ok 1
    mkprint(%str(%1))
    mkprint('...')

    call %1
    mkprintln_ok()
%endmacro

kmain:
    .clear_vga_buffer:
        call clear_screen
        call vga_disable_cursor

    ; Kernel boot message
    mkprint('dinOS version 0.0.1-beta-x86 (nasm version ')
    mkprint(nasm_version)
    mkprintln(')')
    mkprintln()

    ; Initialize interrupts    
    call_with_ok init_interrupts

    ; Initialize drivers
    enumerate_driver_init_functions(call_with_ok)

    ; Enable cursor and prep for keyboard key event
    call vga_enable_cursor
    mkprintln()

    call print_shell_prompt

    ; Create room on the stack for the key event

    push ebp
    mov ebp, esp
    sub esp, 4

    ; Consume key events
    .keyboard_loop:
        ; Poll the keyboard driver
        call kb_get_next_key_event

        ; Store the key event on the stack
        mov [ebp - 4], eax

        ; Skip event unless its a key down event
        cmp ah, 1
        jne .keyboard_loop

        ; Check the keycode to see what kind of operation we need to do
        mov al, [ebp - 1]

        cmp al, KB_KC_ENTER
        je .handle_enter

        cmp al, KB_KC_BACKSPACE
        je .handle_backspace

        ; If the prompt buffer is already full then we ignore this character
        xor ebx, ebx
        mov bl, [_prompt_buffer_idx]
        cmp bl, PROMPT_BUFFER_MAX_LEN
        jge .keyboard_loop

        ; If the character is not printable, don't print it
        mov al, [ebp - 2]
        cmp al, 0
        je .keyboard_loop

        ; Print the character
        call kprint_char

        ; Push to the prompt buffer
        mov [_prompt_buffer + ebx], al
        inc bl
        mov [_prompt_buffer_idx], bl

        jmp .keyboard_loop

    .handle_enter:
        ; Parse and execute the command
        mkprintln()

        ; Reset the prompt buffer length
        mov bl, 0
        mov [_prompt_buffer_idx], bl

        ; Print the new prompt
        call print_shell_prompt

        jmp .keyboard_loop

    .handle_backspace:
        ; If the prompt buffer is already empty then we ignore this key event
        xor ebx, ebx
        mov bl, [_prompt_buffer_idx]
        cmp bl, 0
        je .keyboard_loop

        ; Decrement the prompt buffer length
        dec bl
        mov [_prompt_buffer_idx], bl

        call kprint_backspace
        jmp .keyboard_loop

print_shell_prompt:
    pushad

    mkprint_color("root@dinos", VGA_COLOR_FG_BRIGHT_GREEN)
    mkprint(":")
    mkprint_color("~", VGA_COLOR_FG_BRIGHT_BLUE)
    mkprint("$ ")

    popad
    ret

halt:
    ; Halt the processor
    hlt
    jmp halt

_prompt_buffer: times 255 db 0
_prompt_buffer_idx: db 0

PROMPT_BUFFER_MAX_LEN equ 64

%include "vga.asm"
%include "interrupt/init.asm"
