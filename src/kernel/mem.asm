%ifndef MEM_ASM
%define MEM_ASM

;
; Copies a specified number of bytes from src to dest
; @input eax - dest
; @input ebx - src
; @input ecx - num
;
memcpy:
    pushad

    ; Internally we can optimize this function by copying 4 bytes at a time instead of 1

    ; edx = ecx % 4
    ; i.e. Number of individual bytes that need to be copied
    mov edx, ecx
    and edx, 0b0000_0011 ; number from 0-3

    ; ecx = (ecx - (ecx % 4)) / 4
    ; i.e. Number of dwords that need to be copied
    sub ecx, edx
    shr ecx, 2

    .move_dwords_if_needed:
        mov edi, 0

    .move_dword:
        cmp edi, ecx
        je .move_bytes_if_needed

        ; Copy dword from src to dest
        mov dword esi, [ebx + 4 * edi]
        mov dword [eax + 4 * edi], esi

        inc edi
        jmp .move_dword

    .move_bytes_if_needed:
        mov edi, 0

        ; Add to src and dest the number of bytes we copied so far
        shl ecx, 2
        add eax, ecx
        add ebx, ecx

    .move_byte:
        cmp edi, edx
        je .finished

        ; Copy byte from src to dest
        mov byte cl, [ebx + edi]
        mov byte [eax + edi], cl

        inc edi
        jmp .move_byte

    .finished:
        popad
        ret

;
; Sets the first num bytes of the block of memory pointed by ptr to the specified value
; @input eax - ptr
; @input bl - value
; @input ecx - num
;
memset:
    pushad

    ; Internally we can optimize this function by setting 4 bytes at a time instead of 1

    ; edx = ecx % 4
    ; i.e. Number of individual bytes that need to be set
    mov edx, ecx
    and edx, 0b0000_0011 ; number from 0-3

    ; ecx = (ecx - (ecx % 4)) / 4
    ; i.e. Number of dwords that need to be set
    sub ecx, edx
    shr ecx, 2

    .set_dwords_if_needed:
        mov edi, 0

        ; Repeat bl into all bytes of ebx
        mov bh, bl ; 0x????VVVV
        shl ebx, 8 ; 0x??VVVV00
        mov bl, bh ; 0x??VVVVVV
        shl ebx, 8 ; 0xVVVVVV00
        mov bl, bh ; 0xVVVVVVVV

    .set_dword:
        cmp edi, ecx
        je .set_bytes_if_needed

        ; Set dword
        mov dword [eax + 4 * edi], ebx

        inc edi
        jmp .set_dword

    .set_bytes_if_needed:
        mov edi, 0

        ; Add to ptr the number of bytes we copied so far
        shl ecx, 2
        add eax, ecx

    .set_byte:
        cmp edi, edx
        je .finished

        ; Set byte
        mov byte [eax + edi], bl

        inc edi
        jmp .set_byte

    .finished:
        popad
        ret
        
%endif