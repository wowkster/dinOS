%ifndef KB_MACROS_ASM
%define KB_MACROS_ASM

;
; Defines end cases for functions that match or dont match a certain predicate
;
%macro matchable 0

    .matched:
        push eax

        ; Set zero flag
        lahf                      ; Load AH from FLAGS
        or       ah, 001000000b    ; Set bit for ZF
        sahf                      ; Store AH back to Flags

        pop eax
        jmp .finished

    .not_matched:
        push eax

        ; Clear zero flag
        lahf                      ; Load lower 8 bit from Flags into AH
        and      ah, 010111111b    ; Clear bit for ZF
        sahf                      ; Store AH back to Flags

        pop eax
        jmp .finished

%endmacro

%endif