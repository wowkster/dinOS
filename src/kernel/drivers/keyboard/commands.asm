%ifndef KB_COMMAND_ASM
%define KB_COMMAND_ASM

%include "drivers/keyboard/keyboard.asm"

; PS/2 Keyboard Commands
; https://wiki.osdev.org/PS/2_Keyboard#Commands
KB_CMD_SET_LEDS equ 0xED
KB_CMD_ECHO equ 0xEE
KB_CMD_SCAN_CODE_SET equ 0xF0
KB_CMD_IDENTIFY equ 0xF2
KB_CMD_SET_TYPEMATIC_RATE_DELAY equ 0xF3
KB_CMD_ENABLE_SCANNING equ 0xF4
KB_CMD_DISABLE_SCANNING equ 0xF5
KB_CMD_SET_DEFAULT_PARAMS equ 0xF6
KB_CMD_RESEND equ 0xFE
KB_CMD_RESET_SELF_TEST equ 0xFF

; Set LED Data
KB_CMD_DATA_LED_SCROLL_LOCK equ 0b0000_0001
KB_CMD_DATA_LED_NUM_LOCK equ 0b0000_0010
KB_CMD_DATA_LED_CAPS_LOCK equ 0b0000_0100

; Get/Set Scan Code Data
KB_CMD_DATA_GET_SCAN_CODE equ 0x00
KB_CMD_DATA_SET_SCAN_CODE_1 equ 0x01
KB_CMD_DATA_SET_SCAN_CODE_2 equ 0x02
KB_CMD_DATA_SET_SCAN_CODE_3 equ 0x03

; PS/2 Keyboard Responses
; https://wiki.osdev.org/PS/2_Keyboard#Commands
KB_RESPONSE_ERROR_1 equ 0x00
KB_RESPONSE_ERROR_2 equ 0xFF
KB_RESPONSE_SELF_TEST_PASS equ 0xAA
KB_RESPONSE_SELF_TEST_FAIL_1 equ 0xFC
KB_RESPONSE_SELF_TEST_FAIL_2 equ 0xFD
KB_RESPONSE_ECHO equ 0xEE
KB_RESPONSE_ACK equ 0xFA
KB_RESPONSE_RESEND equ 0xFE

; Internal command queue implemented as an array
_kb_cmd_buffer: times 64 db 0 ; Static 64 byte buffer to hold all the kb command we will ever need
_kb_cmd_buffer_idx: db 0      ; Static index into the command buffer (points to next available space in buffer)

;
; Enqueue a byte into the command queue
; @input al - command
;
kb_cmd_enqueue_byte:
    pushad

    ; Get the current index into the command buffer
    mov ebx, 0
    mov byte bl, [_kb_cmd_buffer_idx]

    ; Panic if the command buffer is full
    cmp bl, 64
    je .cmd_buffer_full

    ; Store the command into the next available slot in the buffer
    mov byte [_kb_cmd_buffer + ebx], al

    ; Increment the buffer index and store it back
    inc ebx
    mov byte [_kb_cmd_buffer_idx], bl

    popad
    ret

    .cmd_buffer_full:
        kpanic('kb_cmd_enqueue_byte', 'Keyboard command buffer is full!')

;
; Removes the first byte in the command queue
;
kb_cmd_dequeue_byte:
    pushad

    ; Get the current index into the command buffer
    xor ecx, ecx
    mov byte cl, [_kb_cmd_buffer_idx]

    ; Panic if the command buffer is empty
    cmp cl, 0
    je .cmd_buffer_empty

    ; Shift all the commands in the buffer down by 1
    lea eax, [_kb_cmd_buffer]
    lea ebx, [_kb_cmd_buffer + 1]
    dec cl
    call memcpy

    ; Store the new buffer index back
    mov byte [_kb_cmd_buffer_idx], cl

    popad
    ret

    .cmd_buffer_empty:
        kpanic('kb_cmd_deqeue', 'Keyboard command buffer is empty!')

;
; Peeks at the next byte in the command queue
; @output al - command byte
;
kb_cmd_peek_byte:
    push ecx

    ; Get the current index into the command buffer
    xor ecx, ecx
    mov byte cl, [_kb_cmd_buffer_idx]

    ; Panic if the command buffer is empty
    cmp cl, 0
    je .cmd_buffer_empty

    ; Get the first byte in the command buffer
    mov byte al, [_kb_cmd_buffer]

    pop ecx
    ret

    .cmd_buffer_empty:
        kpanic('kb_cmd_peek_byte', 'Keyboard command buffer is empty!')

;
; Peeks at the next command in the command queue for its data byte
; @output al - command data byte
;
kb_cmd_peek_byte_data:
    push ecx

    ; Get the current index into the command buffer
    xor ecx, ecx
    mov byte cl, [_kb_cmd_buffer_idx]

    ; Panic if the command buffer is not big enough
    cmp cl, 2
    jl .cmd_buffer_empty

    ; Get the seconds byte in the command buffer
    mov byte al, [_kb_cmd_buffer + 1]

    pop ecx
    ret

    .cmd_buffer_empty:
        kpanic('kb_cmd_peek_byte_data', 'Keyboard command buffer is less than 2 bytes in length!')

;
; Checks to see if a command byte has a data byte as well
; @input al - command byte
;
kb_cmd_requires_data:
    pushad
    
    cmp al, KB_CMD_SET_LEDS
    je .matched

    cmp al, KB_CMD_SCAN_CODE_SET
    je .matched

    cmp al, KB_CMD_SET_TYPEMATIC_RATE_DELAY
    je .matched

    jmp .not_matched

    matchable

    .finished:
        popad
        ret

;
; Sends the first command in the queue to the keyboard if the queue is not empty
;
kb_cmd_output_first_if_not_empty:
    pushad

    ; Get the current index into the command buffer
    xor ecx, ecx
    mov byte cl, [_kb_cmd_buffer_idx]

    ; If there are no commands in the buffer, do nothing
    cmp cl, 0
    je .no_commands_in_queue

    ; Get the first byte in the command buffer and send it
    call kb_cmd_peek_byte
    out KEYBOARD_PORT, al

    ; If the command byte requires additional data, get the next byte in the buffer and send it too
    call kb_cmd_requires_data 
    jne .set_command_state

    .send_data_byte:
        call io_wait
        call kb_cmd_peek_byte_data
        out KEYBOARD_PORT, al

    .set_command_state:
        ; Set the state to waiting for command response
        mov byte [_kb_driver_state], KB_STATE_WAITING_FOR_COMMAND_RESPONSE

        jmp .finished

    .no_commands_in_queue:
        ; Set the state to default
        mov byte [_kb_driver_state], KB_STATE_DEFAULT

    .finished:
        popad
        ret

;
; Remove a command and its data byte (is present) from the command queue
;
kb_cmd_rm_from_queue:
    pushad

    ; Get the first command byte in the buffer
    call kb_cmd_peek_byte

    ; Remove the first byte in the buffer
    call kb_cmd_dequeue_byte

    ; If the command byte requires additional data, remove the next byte in the buffer
    call kb_cmd_requires_data
    jne .finished

    .remove_data_byte:
        call kb_cmd_dequeue_byte

    .finished:
        popad
        ret

;
; Adds a command to the command queue and then sends it to the keyboard if the queue was previously empty
; @input al - command
;
kb_queue_command:
    pushad
    pushf
    cli

    ; Enqueue the command
    call kb_cmd_enqueue_byte

    ; Get the current index into the command buffer
    xor ecx, ecx
    mov byte cl, [_kb_cmd_buffer_idx]

    ; If there is more than 1 command byte in the buffer, do nothing (already being handled)
    cmp cl, 1
    jg .finished

    ; Otherwise, there are no commands being processed so we need to send it to the keyboard
    call kb_cmd_output_first_if_not_empty

    .finished:
        popf
        popad
        ret

;
; Adds a command and a data byte to the command queue and then sends it to the keyboard if the queue was previously empty
; @input al - command
; @input ah - data
;
kb_queue_command_with_data:
    pushad
    pushf
    cli

    ; Enqueue the command
    call kb_cmd_enqueue_byte

    ; Enqueue the data
    mov al, ah
    call kb_cmd_enqueue_byte

    ; Get the current index into the command buffer
    xor ecx, ecx
    mov byte cl, [_kb_cmd_buffer_idx]

    ; If there are more than 2 command bytes in the buffer, do nothing (already being handled)
    cmp cl, 2
    jg .finished

    ; Otherwise, there are no commands being processed so we need to send it to the keyboard
    call kb_cmd_output_first_if_not_empty

    .finished:
        popf
        popad
        ret

;
; Waits for the command queue to be empty (spinloop)
;
kb_wait_for_empty_command_queue:
    pushad

    .spin_loop:
        xor ecx, ecx
        mov byte cl, [_kb_cmd_buffer_idx]

        cmp cl, 0
        je .finished

        pause
        jmp .spin_loop

    .finished:
        popad
        ret

%endif