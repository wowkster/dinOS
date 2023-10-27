%ifndef DRIVERS_KEYBOARD_ASM
%define DRIVERS_KEYBOARD_ASM

%include "vga.asm"
%include "interrupt/pic.asm"

%include "drivers/keyboard/macros.asm"
%include "drivers/keyboard/commands.asm"
%include "drivers/keyboard/key_code.asm"
%include "drivers/keyboard/key_event.asm"

;
; A basic driver for interacting with PS/2 Keyboards
;
; https://wiki.osdev.org/PS2_Keyboard#Driver_Model
;

KEYBOARD_PORT equ 0x60

; Possible driver states
KB_STATE_DEFAULT equ 0                                 ; Default state before any scan codes are processed
KB_STATE_WAITING_FOR_TWO_OR_FOUR_BYTE_SCAN_CODE equ 1  ; First byte was 0xE0
KB_STATE_WAITING_FOR_FOUR_BYTE_SCAN_CODE equ 2         ; First byte was 0xE0 and second byte was 0x2A or 0xB7
KB_STATE_WAITING_FOR_SIX_BYTE_SCAN_CODE equ 3          ; First byte was 0xE1
KB_STATE_WAITING_FOR_COMMAND_RESPONSE equ 4               ; Waiting for a command response from the keyboard

; Static variable to hold the driver state
_kb_driver_state: db 0

; Buffer to hold the scan codes we've recieved (used to decode multibyte scan codes)
_kb_scan_code_buffer: times 6 db 0  ; Static 6 byte buffer to hold all the recieved scan codes
_kb_scan_code_buffer_idx: db 0      ; Static index into the scan code buffer (points to next available space in buffer)

;
; Driver init function called after interrupts are enabled on the system
;
keyboard_driver_init:
    pushad

    mov al, KB_CMD_ECHO
    call kb_queue_command

    mov al, KB_CMD_RESET_SELF_TEST
    call kb_queue_command

    mov al, KB_CMD_SCAN_CODE_SET
    mov ah, KB_CMD_DATA_SET_SCAN_CODE_1
    call kb_queue_command_with_data

    mov al, KB_CMD_DISABLE_SCANNING
    call kb_queue_command

    mov al, KB_CMD_ENABLE_SCANNING
    call kb_queue_command

    call kb_wait_for_empty_command_queue

    popad
    ret

;
; Handler for keyboard interrupts as they come in from the PS/2 controller
;
keyboard_driver_handle_interrupt:
    push eax
    push ebx

    ; Read in byte from the keyboard
    in al, KEYBOARD_PORT

    ; Check if the byte indicates an error
    cmp al, KB_RESPONSE_ERROR_1
    je .error

    cmp al, KB_RESPONSE_ERROR_2
    je .error

    ; Get the driver state   
    mov ebx, 0
    mov byte bl, [_kb_driver_state]

    ; Branch to the correct case based on the driver state
    cmp bl, KB_STATE_WAITING_FOR_COMMAND_RESPONSE
    je .command_response

    jmp .scan_code

    .error:
        kpanic('keyboard_driver_handle_interrupt', 'Received keyboard error response!')

    .command_response:
        ; Call out to helper to process the command response
        call kb_handle_command_response

        jmp .finished

    .scan_code:
        ; Store the scan code into the scan buffer
        call kb_store_scan_code_byte

        ; Compute the next state of the driver based on the value in the scan buffer
        call kb_process_scan_code_buffer

    .finished:
        pop ebx
        pop eax
        ret

;
; Handles the logic for processing a command response from the keyboard
; @input al - response byte
;
kb_handle_command_response:
    pushad

    ; Check if the response is a self test pass
    cmp al, KB_RESPONSE_SELF_TEST_PASS
    je .self_test_pass

    ; Check if the response is a self test fail
    cmp al, KB_RESPONSE_SELF_TEST_FAIL_1
    je .self_test_fail

    cmp al, KB_RESPONSE_SELF_TEST_FAIL_2
    je .self_test_fail

    ; Check if the byte is a command acknowledgement
    cmp al, KB_RESPONSE_ACK
    je .acknowledgement

    ; Check if the byte is a command resend request
    cmp al, KB_RESPONSE_RESEND
    je .resend_request

    ; Check if the byte is a command echo
    cmp al, KB_RESPONSE_ECHO
    je .echo

    ; If none of the cases matched, something went wrong
    kpanic('kb_handle_command_response', 'Keyboard command response error!')

    .self_test_pass:
        call kb_cmd_peek_byte

        ; If the last command was not a self test, something went wrong
        cmp al, KB_CMD_RESET_SELF_TEST
        jne .self_test_error

        ; Otherwise, remove the self test command from the queue
        call kb_cmd_rm_from_queue

        ; If there are more commands in the queue, send the next one
        call kb_cmd_output_first_if_not_empty

        jmp .finished

        .self_test_error:
            kpanic('kb_handle_command_response', 'Keyboard command self test error!')

    .self_test_fail:
        kpanic('kb_handle_command_response', 'Keyboard self test failed!')

    .acknowledgement:
        call kb_cmd_peek_byte

        ; If the last command was not a self test, something went wrong
        cmp al, KB_CMD_RESET_SELF_TEST
        je .finished

        ; Remove the last command from the command queue
        call kb_cmd_rm_from_queue

        ; If there are more commands in the queue, send the next one
        call kb_cmd_output_first_if_not_empty

        jmp .finished

    .resend_request:
        ; Resend the last command
        call kb_cmd_output_first_if_not_empty

        jmp .finished

    .echo:
        call kb_cmd_peek_byte

        ; If the last command was not an echo, something went wrong
        cmp al, KB_CMD_ECHO
        jne .echo_error

        ; Otherwise, remove the echo command from the queue
        call kb_cmd_rm_from_queue

        ; If there are more commands in the queue, send the next one
        call kb_cmd_output_first_if_not_empty

        jmp .finished

        .echo_error:
            kpanic('kb_handle_command_response', 'Keyboard command echo error!')

    .finished:
        popad
        ret

;
; Stores the requested scan code into the scan buffer for processing
; @input al - scan code
;
kb_store_scan_code_byte:
    pushad

    ; Store the scan code byte into the next available slot in the buffer
    mov ebx, 0
    mov byte bl, [_kb_scan_code_buffer_idx]
    mov byte [_kb_scan_code_buffer + ebx], al

    ; Increment the buffer index
    inc ebx
    mov byte [_kb_scan_code_buffer_idx], bl

    popad
    ret

;
; Looks at the scan buffer and changes the state based on its value
;
; This is where invalid scan codes are discarded
;
kb_process_scan_code_buffer:
    pushad

    ; Get the length of the scan code buffer
    mov ebx, 0
    mov byte bl, [_kb_driver_state]
    
    ; Branch to the correct case based on its length
    .branch_to_buffer_len_case:
        cmp bl, KB_STATE_DEFAULT
        je .state_default

        cmp bl, KB_STATE_WAITING_FOR_TWO_OR_FOUR_BYTE_SCAN_CODE
        je .state_waiting_for_two_or_four_byte_scan_code

        cmp bl, KB_STATE_WAITING_FOR_FOUR_BYTE_SCAN_CODE
        je .state_waiting_for_four_byte_scan_code

        cmp bl, KB_STATE_WAITING_FOR_SIX_BYTE_SCAN_CODE
        je .state_waiting_for_six_byte_scan_code

    ; When the state is KB_STATE_DEFAULT, there is always only 1 byte in the buffer
    .state_default:
        ; Check if the first byte is a valid single byte scan code
        call kb_is_one_byte_scancode_valid
        je .one_byte_complete

        ; If the first byte is the start of an extended multibyte scan code,
        ; determine the new state and then wait for more bytes
        mov byte al, [_kb_scan_code_buffer]

        ; Could be the start of a 2 byte scan code or a 4 byte scan code
        cmp al, 0xE0
        je .move_to_two_or_four_byte_state

        ; Has to be the start of a 6 byte scan code
        cmp al, 0xE1
        je .move_to_six_byte_state

        ; If neither cases matched, the scan code must be invalid
        je .reset_kb_scan_code_buffer

        .move_to_two_or_four_byte_state:
            mov bl, KB_STATE_WAITING_FOR_TWO_OR_FOUR_BYTE_SCAN_CODE
            mov byte [_kb_driver_state], bl
            jmp .finished

        .move_to_six_byte_state:
            mov bl, KB_STATE_WAITING_FOR_SIX_BYTE_SCAN_CODE
            mov byte [_kb_driver_state], bl
            je .finished

        .one_byte_complete:
            ; Handle the 1 byte scan code
            call kb_translate_one_byte_scan_code_to_key_code
            call kb_handle_key_code

            jmp .reset_kb_scan_code_buffer

    ; When the state is KB_STATE_WAITING_FOR_TWO_OR_FOUR_BYTE_SCAN_CODE, there are
    ; always 2 bytes in the buffer and the first byte is always 0xE0
    .state_waiting_for_two_or_four_byte_scan_code:
        ; Check if the first 2 bytes are a valid single byte scan code
        call kb_is_two_byte_scancode_valid
        je .two_byte_complete

        ; If the first 2 bytes themselves are not a valid scan code, it could
        ; be the start of a 4 byte scan code. The second byte of a 4 byte scan
        ; code must be either 0x2A or 0xB7
        mov byte al, [_kb_scan_code_buffer + 1]

        cmp al, 0x2A
        je .move_to_four_byte_state

        cmp al, 0xB7
        je .move_to_four_byte_state

        ; If neither cases matched, the scan code must be invalid
        jmp .reset_kb_scan_code_buffer

        .move_to_four_byte_state:
            mov bl, KB_STATE_WAITING_FOR_FOUR_BYTE_SCAN_CODE
            mov byte [_kb_driver_state], bl
            jmp .finished

        .two_byte_complete:
            ; Reset the state
            mov bl, KB_STATE_DEFAULT
            mov byte [_kb_driver_state], bl

            ; Handle the 2 byte scan code
            call kb_translate_two_byte_scan_code_to_key_code
            call kb_handle_key_code

            jmp .reset_kb_scan_code_buffer

    ; When the state is KB_STATE_WAITING_FOR_FOUR_BYTE_SCAN_CODE, there are either
    ; 3 or 4 bytes in the scan code buffer
    .state_waiting_for_four_byte_scan_code:       
        ; Get the current buffer length and branch
        mov byte cl, [_kb_scan_code_buffer_idx] 
        
        cmp cl, 3
        je .three_byte_case        
        
        cmp cl, 4
        je .four_byte_case

        .three_byte_case:
            ; Get the third byte of the scan code buffer
            mov byte al, [_kb_scan_code_buffer + 2]
            
            ; The 3rd byte must always be 0xE0
            cmp al, 0xE0
            je .finished

            ; Any other values are invalid
            jmp .reset_kb_scan_code_buffer

        .four_byte_case:
            ; If there are 4 bytes, check if the current scan code is a valid 4 byte scan code
            call kb_is_four_byte_scancode_valid
            je .four_byte_complete

            ; If the value is invalid, throw it away and ignore it
            jmp .reset_kb_scan_code_buffer

        .four_byte_complete:
            ; Reset the state
            mov bl, KB_STATE_DEFAULT
            mov byte [_kb_driver_state], bl

            ; Handle the 4 byte scan code
            call kb_translate_four_byte_scan_code_to_key_code
            call kb_handle_key_code

            jmp .reset_kb_scan_code_buffer

    ; When the state is KB_STATE_WAITING_FOR_SIX_BYTE_SCAN_CODE, there can be
    ; anywhere from 2 to 6 bytes in the scan code buffer
    .state_waiting_for_six_byte_scan_code:
        ; Get the current buffer length and branch
        mov byte cl, [_kb_scan_code_buffer_idx] 

        ; If there are less than 6 bytes in the buffer, just keep reading
        ; We could short circuit if we get an invalid scan code but thats a lot of work
        cmp cl, 6
        jl .finished

        .six_byte_case:
            ; Check to make sure that the 6 bytes in the scan code buffer make 
            ; a valid scan code (pause pressed)
            call kb_is_six_byte_scancode_valid
            je .six_byte_complete

            ; If the value is invalid, throw it away and ignore it
            jmp .reset_kb_scan_code_buffer

        .six_byte_complete:
            ; Reset the state
            mov bl, KB_STATE_DEFAULT
            mov byte [_kb_driver_state], bl

            ; Handle the 6 byte scan code
            call kb_translate_two_byte_scan_code_to_key_code
            call kb_handle_key_code

            jmp .reset_kb_scan_code_buffer

    ; Reset scan code buffer
    .reset_kb_scan_code_buffer:
        mov bl, 0
        mov byte [_kb_scan_code_buffer_idx], bl

    .finished:
        popad
        ret

; ====================================================================
;                         Scan Code Validation
; ====================================================================

;
; Checks to see if a single byte scan code is within the valid range(s)
;
kb_is_one_byte_scancode_valid:
    pushad

    ; Get the first byte in the buffer
    mov byte al, [_kb_scan_code_buffer]

    ; cl = byte index into the table
    mov ecx, 0
    mov cl, al
    shr cl, 3

    ; bl = the byte from the table
    mov byte bl, [.table + ecx] 

    ; cl = bit index into the byte
    mov cl, al
    and cl, 0b0000_0111 

    ; Check if cl-th bit is set 
    shr bl, cl
    and bl, 1

    ; If the result was 0, the bit was not set
    jz .not_matched

    ; Otherwise, it was set
    jmp .matched

    matchable

    .finished:
        popad
        ret

    ; Each row represents 8 byte values. If the bit is set, that scan code is valid.
    ; Generally if the most significant bit of a scan code is set, then it denotes a
    ; key release and otherwise it denotes a key press. This means the table actually 
    ; looks the same from 0x00-7f and 0x80-ff
    .table:
        db 0b1111_1110 ; 0x00-07
        db 0b1111_1111 ; 0x08-0f
        db 0b1111_1111 ; 0x10-17
        db 0b1111_1111 ; 0x18-1f
        db 0b1111_1111 ; 0x20-27
        db 0b1111_1111 ; 0x28-2f
        db 0b1111_1111 ; 0x30-37
        db 0b1111_1111 ; 0x38-3f
        db 0b1111_1111 ; 0x40-47
        db 0b1111_1111 ; 0x48-4f
        db 0b1000_1111 ; 0x50-57
        db 0b0000_0001 ; 0x58-5f
        db 0b0000_0000 ; 0x60-67
        db 0b0000_0000 ; 0x68-6f
        db 0b0000_0000 ; 0x70-77
        db 0b0000_0000 ; 0x78-7f
        db 0b1111_1110 ; 0x80-87
        db 0b1111_1111 ; 0x88-8f
        db 0b1111_1111 ; 0x90-97
        db 0b1111_1111 ; 0x98-9f
        db 0b1111_1111 ; 0xa0-a7
        db 0b1111_1111 ; 0xa8-af
        db 0b1111_1111 ; 0xb0-b7
        db 0b1111_1111 ; 0xb8-bf
        db 0b1111_1111 ; 0xc0-c7
        db 0b1111_1111 ; 0xc8-cf
        db 0b1000_1111 ; 0xd0-d7
        db 0b0000_0001 ; 0xd8-df
        db 0b0000_0000 ; 0xe0-e7
        db 0b0000_0000 ; 0xe8-ef
        db 0b0000_0000 ; 0xf0-f7
        db 0b0000_0000 ; 0xf8-ff

;
; Checks to see if a two byte scan code is within the valid range(s)
;
kb_is_two_byte_scancode_valid:
    pushad

    ; Get the first 2 bytes in the buffer
    mov byte ah, [_kb_scan_code_buffer]
    mov byte al, [_kb_scan_code_buffer + 1]

    ; All valid 2 byte scan codes start with 0xe0
    cmp ah, 0xe0
    jne .not_matched

    ; cl = byte index into the table
    mov ecx, 0
    mov cl, al
    shr cl, 3

    ; bl = the byte from the table
    mov byte bl, [.table + ecx] 

    ; cl = bit index into the byte
    mov cl, al
    and cl, 0b0000_0111 

    ; Check if cl-th bit is set 
    shr bl, cl
    and bl, 1

    ; If the result was 0, the bit was not set
    jz .not_matched

    ; Otherwise, it was set
    jmp .matched

    matchable

    .finished:
        popad
        ret

    ; Each row represents 8 byte values. If the bit is set, that scan code is valid.
    ; Generally if the most significant bit of a scan code is set, then it denotes a
    ; key release and otherwise it denotes a key press. This means the table actually 
    ; looks the same from 0x00-7f and 0x80-ff
    .table:
        db 0b0000_0000 ; 0x00-07
        db 0b0000_0000 ; 0x08-0f
        db 0b0000_0001 ; 0x10-17
        db 0b0011_0010 ; 0x18-1f
        db 0b0001_0111 ; 0x20-27
        db 0b0100_0000 ; 0x28-2f
        db 0b0010_0101 ; 0x30-37
        db 0b0000_0001 ; 0x38-3f
        db 0b1000_0000 ; 0x40-47
        db 0b1010_1011 ; 0x48-4f
        db 0b0000_1111 ; 0x50-57
        db 0b1111_1000 ; 0x58-5f
        db 0b0000_1000 ; 0x60-67
        db 0b0011_1111 ; 0x68-6f
        db 0b0000_0000 ; 0x70-77
        db 0b0000_0000 ; 0x78-7f
        db 0b0000_0000 ; 0x80-87
        db 0b0000_0000 ; 0x88-8f
        db 0b0000_0001 ; 0x90-97
        db 0b0011_0010 ; 0x98-9f
        db 0b0001_0111 ; 0xa0-a7
        db 0b0100_0000 ; 0xa8-af
        db 0b0010_0101 ; 0xb0-b7
        db 0b0000_0001 ; 0xb8-bf
        db 0b1000_0000 ; 0xc0-c7
        db 0b1010_1011 ; 0xc8-cf
        db 0b0000_1111 ; 0xd0-d7
        db 0b1111_1000 ; 0xd8-df
        db 0b0000_1000 ; 0xe0-e7
        db 0b0011_1111 ; 0xe8-ef
        db 0b0000_0000 ; 0xf0-f7
        db 0b0000_0000 ; 0xf8-ff

;
; Checks to see if a four byte scan code is within the valid range
;
kb_is_four_byte_scancode_valid:
    pushad

    mov byte al, [_kb_scan_code_buffer + 1]
    mov byte ah, [_kb_scan_code_buffer + 3]

    cmp al, 0x2A
    je .print_screen_pressed

    cmp al, 0xB7
    je .print_screen_released

    jmp .not_matched

    .print_screen_pressed:
        cmp ah, 0x37
        je .matched

        jmp .not_matched

    .print_screen_released:
        cmp ah, 0xAA
        je .matched

        jmp .not_matched

    matchable

    .finished:
        popad
        ret
    
;
; Checks to see if a six byte scan code is within the valid range
;
kb_is_six_byte_scancode_valid:
    pushad

    mov byte al, [_kb_scan_code_buffer + 1]
    cmp al, 0x1D
    jne .not_matched

    mov byte al, [_kb_scan_code_buffer + 2]
    cmp al, 0x45
    jne .not_matched

    mov byte al, [_kb_scan_code_buffer + 3]
    cmp al, 0xE1
    jne .not_matched

    mov byte al, [_kb_scan_code_buffer + 4]
    cmp al, 0x9D
    jne .not_matched

    mov byte al, [_kb_scan_code_buffer + 5]
    cmp al, 0xC5
    jne .not_matched

    jmp .matched

    matchable

    .finished:
        popad
        ret

; ===================================================================
;                        Scan Code Translation
; ===================================================================

; Lookup table to scan code set 1 (one byte scan codes)
; We only need the first 128 entries because the MSB is reserved for the key state 
_kb_scan_code_set_1_one_byte_lookup_table:
    .0x00: db KB_KC_UNUSED,     KB_KC_ESC,          KB_KC_1,            KB_KC_2
    .0x04: db KB_KC_3,          KB_KC_4,            KB_KC_5,            KB_KC_6
    .0x08: db KB_KC_7,          KB_KC_8,            KB_KC_9,            KB_KC_0
    .0x0C: db KB_KC_MINUS,      KB_KC_EQUALS,       KB_KC_BACKSPACE,    KB_KC_TAB
    .0x10: db KB_KC_Q,          KB_KC_W,            KB_KC_E,            KB_KC_R
    .0x14: db KB_KC_T,          KB_KC_Y,            KB_KC_U,            KB_KC_I
    .0x18: db KB_KC_O,          KB_KC_P,            KB_KC_LEFT_BRACKET, KB_KC_RIGHT_BRACKET
    .0x1C: db KB_KC_ENTER,      KB_KC_LEFT_CTRL,    KB_KC_A,            KB_KC_S
    .0x20: db KB_KC_D,          KB_KC_F,            KB_KC_G,            KB_KC_H
    .0x24: db KB_KC_J,          KB_KC_K,            KB_KC_L,            KB_KC_SEMICOLON
    .0x28: db KB_KC_APOSTROPHE, KB_KC_GRAVE_ACCENT, KB_KC_LEFT_SHIFT,   KB_KC_BACKSLASH
    .0x2C: db KB_KC_Z,          KB_KC_X,            KB_KC_C,            KB_KC_V
    .0x30: db KB_KC_B,          KB_KC_N,            KB_KC_M,            KB_KC_COMMA
    .0x34: db KB_KC_PERIOD,     KB_KC_SLASH,        KB_KC_RIGHT_SHIFT,  KB_KC_KEYPAD_ASTERISK
    .0x38: db KB_KC_LEFT_ALT,   KB_KC_SPACE,        KB_KC_CAPS_LOCK,    KB_KC_F1
    .0x3C: db KB_KC_F2,         KB_KC_F3,           KB_KC_F4,           KB_KC_F5
    .0x40: db KB_KC_F6,         KB_KC_F7,           KB_KC_F8,           KB_KC_F9
    .0x44: db KB_KC_F10,        KB_KC_NUM_LOCK,     KB_KC_SCROLL_LOCK,  KB_KC_KEYPAD_7
    .0x48: db KB_KC_KEYPAD_8,   KB_KC_KEYPAD_9,     KB_KC_KEYPAD_MINUS, KB_KC_KEYPAD_4
    .0x4C: db KB_KC_KEYPAD_5,   KB_KC_KEYPAD_6,     KB_KC_KEYPAD_PLUS,  KB_KC_KEYPAD_1
    .0x50: db KB_KC_KEYPAD_2,   KB_KC_KEYPAD_3,     KB_KC_KEYPAD_0,     KB_KC_KEYPAD_PERIOD
    .0x54: db KB_KC_UNUSED,     KB_KC_UNUSED,       KB_KC_UNUSED,       KB_KC_F11
    .0x58: db KB_KC_F12,        KB_KC_UNUSED,       KB_KC_UNUSED,       KB_KC_UNUSED
    .0x5C: db KB_KC_UNUSED,     KB_KC_UNUSED,       KB_KC_UNUSED,       KB_KC_UNUSED
    .0x60: db KB_KC_UNUSED,     KB_KC_UNUSED,       KB_KC_UNUSED,       KB_KC_UNUSED
    .0x64: db KB_KC_UNUSED,     KB_KC_UNUSED,       KB_KC_UNUSED,       KB_KC_UNUSED
    .0x68: db KB_KC_UNUSED,     KB_KC_UNUSED,       KB_KC_UNUSED,       KB_KC_UNUSED
    .0x6C: db KB_KC_UNUSED,     KB_KC_UNUSED,       KB_KC_UNUSED,       KB_KC_UNUSED
    .0x70: db KB_KC_UNUSED,     KB_KC_UNUSED,       KB_KC_UNUSED,       KB_KC_UNUSED
    .0x74: db KB_KC_UNUSED,     KB_KC_UNUSED,       KB_KC_UNUSED,       KB_KC_UNUSED
    .0x78: db KB_KC_UNUSED,     KB_KC_UNUSED,       KB_KC_UNUSED,       KB_KC_UNUSED
    .0x7C: db KB_KC_UNUSED,     KB_KC_UNUSED,       KB_KC_UNUSED,       KB_KC_UNUSED

;
; Converts a one byte scan code in the scan code buffer into a key code
; @output al - key code
; @output ah - key state (0 = pressed, 1 = released)
;
kb_translate_one_byte_scan_code_to_key_code:
    push ebx 

    ; Get the scan code from the buffer
    mov al, [_kb_scan_code_buffer]

    ; If the MSB is set, it is a key release
    mov ah, al
    shr ah, 7

    ; Remove the state bit from the scan code
    and al, 0x7F

    ; Get the key code from the lookup table
    mov ebx, 0
    mov bl, al
    mov al, [_kb_scan_code_set_1_one_byte_lookup_table + ebx]

    .finished:
        pop ebx
        ret

; Lookup table to scan code set 1 (two byte scan codes)
; We only need the first 128 entries because the MSB is reserved for the key state 
_kb_scan_code_set_1_two_byte_lookup_table:
    .0x00: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x04: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x08: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x0C: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x10: db KB_KC_MULTIMEDIA_PREV_TRACK, KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x14: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x18: db KB_KC_UNUSED,                KB_KC_MULTIMEDIA_NEXT_TRACK,   KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x1C: db KB_KC_KEYPAD_ENTER,          KB_KC_RIGHT_CTRL,              KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x20: db KB_KC_MULTIMEDIA_MUTE,       KB_KC_MULTIMEDIA_CALCULATOR,   KB_KC_MULTIMEDIA_PLAY,          KB_KC_UNUSED
    .0x24: db KB_KC_MULTIMEDIA_STOP,       KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x28: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x2C: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_MULTIMEDIA_VOLUME_DOWN,   KB_KC_UNUSED
    .0x30: db KB_KC_MULTIMEDIA_VOLUME_UP,  KB_KC_UNUSED,                  KB_KC_MULTIMEDIA_WWW_HOME,      KB_KC_UNUSED
    .0x34: db KB_KC_UNUSED,                KB_KC_KEYPAD_SLASH,            KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x38: db KB_KC_RIGHT_ALT,             KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x3C: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x40: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x44: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_HOME
    .0x48: db KB_KC_UP_ARROW,              KB_KC_PAGE_UP,                 KB_KC_UNUSED,                   KB_KC_LEFT_ARROW
    .0x4C: db KB_KC_UNUSED,                KB_KC_RIGHT_ARROW,             KB_KC_UNUSED,                   KB_KC_END
    .0x50: db KB_KC_DOWN_ARROW,            KB_KC_PAGE_DOWN,               KB_KC_INSERT,                   KB_KC_DELETE
    .0x54: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x58: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_LEFT_GUI
    .0x5C: db KB_KC_RIGHT_GUI,             KB_KC_APPS,                    KB_KC_ACPI_POWER,               KB_KC_ACPI_SLEEP
    .0x60: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_ACPI_WAKE
    .0x64: db KB_KC_UNUSED,                KB_KC_MULTIMEDIA_WWW_SEARCH,   KB_KC_MULTIMEDIA_WWW_FAVORITES, KB_KC_MULTIMEDIA_WWW_REFRESH
    .0x68: db KB_KC_MULTIMEDIA_WWW_STOP,   KB_KC_MULTIMEDIA_WWW_FORWARD,  KB_KC_MULTIMEDIA_WWW_BACK,      KB_KC_MULTIMEDIA_MY_COMPUTER
    .0x6C: db KB_KC_MULTIMEDIA_EMAIL,      KB_KC_MULTIMEDIA_MEDIA_SELECT, KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x70: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x74: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x78: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_UNUSED
    .0x7C: db KB_KC_UNUSED,                KB_KC_UNUSED,                  KB_KC_UNUSED,                   KB_KC_UNUSED

;
; Converts a two byte scan code in the scan code buffer into a key code
;
; NOTE: This function assumes that the scan code in the buffer has already been validated as a valid two byte scan code
; @output al - key code
; @output ah - key state (0 = pressed, 1 = released)
;
kb_translate_two_byte_scan_code_to_key_code:
    push ebx 

    ; Get the scan code from the buffer (first byte is always 0xE0)
    mov al, [_kb_scan_code_buffer + 1]

    ; If the MSB is set, it is a key release
    mov ah, al
    shr ah, 7

    ; Remove the state bit from the scan code
    and al, 0x7F

    ; Get the key code from the lookup table
    mov ebx, 0
    mov bl, al
    mov al, [_kb_scan_code_set_1_two_byte_lookup_table + ebx]

    .finished:
        pop ebx
        ret

;
; Converts a four byte scan code in the scan code buffer into a key code
;
; Since only 1 key encodes to a 4 byte scan code, we only need to check the key state
;
; NOTE: This function assumes that the scan code in the buffer has already been validated as a valid four byte scan code
; @output al - key code
; @output ah - key state (0 = pressed, 1 = released)
;
kb_translate_four_byte_scan_code_to_key_code:
    ; Get the scan code from the buffer (first byte is always 0xE0)
    mov al, [_kb_scan_code_buffer + 1]

    ; If the MSB is set, it is a key release
    mov ah, al
    shr ah, 7

    mov al, KB_KC_PRT_SCN

    ret

;
; Converts a six byte scan code in the scan code buffer into a key code
;
; Since only 1 key encodes to a 6 byte scan code, and it never sends a key release so this funciton returns a constant but is still here for completeness
;
; NOTE: This function assumes that the scan code in the buffer has already been validated as a valid six byte scan code
; @output al - key code
; @output ah - key state (0 = pressed, 1 = released)
;
kb_translate_six_byte_scan_code_to_key_code:
    mov al, KB_KC_PAUSE
    mov ah, 0

    ret

; ====================================================================
;                         Key Code State Logic
; ====================================================================

; 256 bit buffer for storing the depression state of each key (0 = not pressed, 1 = pressed)
_kb_key_pressed_state_buffer:
    times 32 db 0

;
; Get the depression state of a key in the key state buffer
; @input al - key code
; @output zf - is pressed (0 = key is up, 1 = key is down)
;
kb_is_key_pressed:
    pushad

    ; cl = byte index into the table
    mov ecx, 0
    mov cl, al
    shr cl, 3

    ; bl = the byte from the table
    mov byte bl, [_kb_key_pressed_state_buffer + ecx] 

    ; cl = bit index into the byte
    mov cl, al
    and cl, 0b0000_0111 

    ; Check if cl-th bit is set 
    shr bl, cl
    and bl, 1

    ; If the result was 0, the bit was not set (the key is up)
    jz .not_matched

    jmp .matched

    matchable

    .finished:
        popad
        ret

;
; Set the key depression state for a key in the key state buffer
; @input al - key code
; @input ah - is pressed (0 = key is up, 1 = key is down)
;
kb_set_key_pressed:
    pushad

    ; dl = byte index into the table
    mov edx, 0
    mov dl, al
    shr dl, 3

    ; bl = the byte from the table
    mov byte bl, [_kb_key_pressed_state_buffer + edx] 

    ; cl = bit index into the byte
    mov cl, al
    and cl, 0b0000_0111 

    cmp ah, 0
    je .clear_bit

    .set_bit:
        shl ah, cl
        or bl, ah

        jmp .set_byte

    .clear_bit:
        mov ah, 1
        shl ah, cl
        not ah
        and bl, ah

    .set_byte:
        mov byte [_kb_key_pressed_state_buffer + edx], bl

    popad
    ret

;
; Checks if either of the provided modifier keys are pressed
; @output zf - is pressed (0 = key is up, 1 = key is down)
;
%macro create_is_modifier_pressed 2-*
    kb_is_%{1}_pressed:
        pushad

        %rotate 1
        %rep %0 - 1
            mov al, %1
            call kb_is_key_pressed
            je .matched
            
            %rotate 1
        %endrep

        jmp .not_matched
        
        matchable

        .finished:
            popad
            ret
%endmacro

create_is_modifier_pressed shift, KB_KC_LEFT_SHIFT, KB_KC_RIGHT_SHIFT
create_is_modifier_pressed ctrl, KB_KC_LEFT_CTRL, KB_KC_RIGHT_CTRL
create_is_modifier_pressed alt, KB_KC_LEFT_ALT, KB_KC_RIGHT_ALT

;
; Generic function called by scan code handlers after a scan code has been translated to a 1 byte key code
; @input al - key code
; @input ah - key state (0 = pressed, 1 = released)
;
kb_handle_key_code:
    pushad

    ; The KeyState enum is represented in the opposite way that keys are stored in the key pressed state buffer
    ; i.e. KeyState::Pressed = 0 and KeyState::Released = 1 while the key pressed state buffer stores 0 = not pressed and 1 = pressed
    xor ah, 1

    ; Set the key state in the key state buffer
    call kb_set_key_pressed

    ; Create the key event packet from the key code
    call kb_create_key_event_packet

    ; Enqueue the key event packet to be consumed by the operating system
    call kb_key_evt_enqueue

    .finished:
        popad
        ret

%endif