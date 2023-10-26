%ifndef MACROS_ASM
%define MACROS_ASM

%macro __mkprint_macro 1
    push esi

    mov esi, %%data
    call kprint

    pop esi
    jmp %%finished

    %%data:
        db %1, 0

    %%finished:
%endmacro

%define mkprint(string) \
    __mkprint_macro string

%macro __mkprintln_macro 0
    push esi

    mov esi, 0
    call kprintln

    pop esi
%endmacro

%define mkprintln() \
    __mkprintln_macro

%macro __mkprintln_macro 1
    push esi

    mov esi, %%data
    call kprintln

    pop esi
    jmp %%finished

    %%data:
        db %1, 0

    %%finished:
%endmacro


%define mkprintln(string) \
    __mkprintln_macro string

%macro __mkprintln_ok_macro 0
    push esi
    push eax

    mov esi, %%msg
    mov ah, VGA_COLOR_FG_BRIGHT_GREEN
    call kprint_color
    
    mov esi, 0
    call kprintln
    
    pop eax
    pop esi
    jmp %%finished

    %%msg:
        db 'OK', 0

    %%finished:
%endmacro

%define mkprintln_ok() \
    __mkprintln_ok_macro

%macro __kpanic_macro 4
    mov eax, %%panic_message
    mov ebx, %%file_name
    mov ecx, %%function_name
    mov edx, %%line_number
    call __kpanic

    %%function_name:
        db %1, 0

    %%panic_message:
        db %2, 0

    %%file_name:
        db %3, 0

    %%line_number:
        db %4, 0
%endmacro

%define kpanic(function_name, panic_message) \
    __kpanic_macro function_name, panic_message, __FILE__, %str(__LINE__)

%strcat nasm_version %str(__NASM_MAJOR__), '.', %str(__NASM_MINOR__), '.', %str(__NASM_SUBMINOR__)

%endif