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

        mov byte cl, [ebx + edi]
        mov byte [eax + edi], cl

        inc edi
        jmp .move_byte

    .finished:
        popad
        ret
        
%endif