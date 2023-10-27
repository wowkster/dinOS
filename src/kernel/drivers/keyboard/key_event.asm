%ifndef KB_KEY_EVENT_ASM
%define KB_KEY_EVENT_ASM

%include "drivers/keyboard/keyboard.asm"

KB_KE_MODIFIER_SHIFT equ 0x01
KB_KE_MODIFIER_CTRL equ 0x02
KB_KE_MODIFIER_ALT equ 0x04
KB_KE_MODIFIER_CAPS_LOCK equ 0x08
KB_KE_MODIFIER_NUM_LOCK equ 0x10
KB_KE_MODIFIER_SCROLL_LOCK equ 0x20

_kb_key_event_queue:
    times 64 dd 0
_kb_key_event_queue_idx:
    db 0

;
; Creates a key event packet from the given key code using the current state of the modifier keys
; @input al - key code
; @output eax - key event packet
;
kb_create_key_event_packet:
    push ebx

    ; Keep a copy of the key code
    mov bl, al

    ; Pack upper 16 bits of packet
    mov ah, al
    call kb_key_code_to_ascii_char
    shl eax, 16

    ; Pack lower 16 bits of packet
    mov al, bl
    call kb_is_key_pressed
    jne .key_up

    .key_down:
        mov ah, 1
        jmp .store_modifier_keys

    .key_up:
        mov ah, 0

    .store_modifier_keys:
        mov al, 0

    .store_shift_state:
        call kb_is_shift_pressed
        jne .store_ctrl_state

        or al, 0x01

    .store_ctrl_state:
        call kb_is_ctrl_pressed
        jne .store_alt_state

        or al, 0x02

    .store_alt_state:
        call kb_is_alt_pressed
        jne .finished

        or al, 0x04

    ; TODO: store lock key states

    .finished:
        pop ebx
        ret

;
; Enqueues a key event packet to the key event queue
; @input eax - key event packet
;
kb_key_evt_enqueue:
    pushad

    ; Get the current index into the queue buffer
    mov ebx, 0
    mov byte bl, [_kb_key_event_queue_idx]

    ; Panic if the key event queue is full
    cmp bl, 64
    je .key_evt_queue_full

    ; Store the command into the next available slot in the buffer
    mov dword [_kb_key_event_queue + ebx * 4], eax

    ; Increment the buffer index and store it back
    inc ebx
    mov byte [_kb_key_event_queue_idx], bl

    popad
    ret

    .key_evt_queue_full:
        kpanic('kb_key_evt_enqueue', 'Keyboard key event queue is full!')

;
; Removes the first packet in the key event queue
; @output eax - key event packet
;
kb_key_evt_dequeue:
    push ebx
    push ecx
    push edx

    ; Get the current index into the queue buffer
    xor ecx, ecx
    mov byte cl, [_kb_key_event_queue_idx]

    ; Panic if the key event queue is empty
    cmp cl, 0
    je .evt_queue_empty

    ; Get the first packet in the queue
    mov dword edx, [_kb_key_event_queue]

    ; Shift all the events in the queue down by 1
    lea eax, [_kb_key_event_queue]
    lea ebx, [_kb_key_event_queue + 4]
    dec cl
    shl ecx, 2
    call memcpy

    ; Store the new buffer index back
    shr ecx, 2
    mov byte [_kb_key_event_queue_idx], cl

    ; Return the dequeued packet
    mov eax, edx

    pop edx
    pop ecx
    pop ebx
    ret

    .evt_queue_empty:
        kpanic('kb_key_evt_dequeue', 'Keyboard key event queue is empty!')

;
; Gets the next key event from the key event queue or blocks until one is available
; @output eax - key event packet
;
kb_get_next_key_event:
    push ebx

    .spin_loop:
        pushf
        cli

        xor ebx, ebx
        mov byte bl, [_kb_key_event_queue_idx]

        cmp bl, 0
        jne .finished

        popf
        pause
        jmp .spin_loop

    .finished:
        call kb_key_evt_dequeue

        popf
        pop ebx
        ret

;
; Checks to see if the given key event has the specified modifier key pressed
; @input eax - key event packet
;
%macro create_key_event_has_modifier 2
    kb_key_event_has_%{1}:
        pushad

    and al, %2
    jz .not_matched

    jmp .matched

    matchable

    .finished:
        popad
        ret
%endmacro

create_key_event_has_modifier shift,       KB_KE_MODIFIER_SHIFT
create_key_event_has_modifier ctrl,        KB_KE_MODIFIER_CTRL
create_key_event_has_modifier alt,         KB_KE_MODIFIER_ALT
create_key_event_has_modifier caps_lock,   KB_KE_MODIFIER_CAPS_LOCK
create_key_event_has_modifier num_lock,    KB_KE_MODIFIER_NUM_LOCK
create_key_event_has_modifier scroll_lock, KB_KE_MODIFIER_SCROLL_LOCK

%endif