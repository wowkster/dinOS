%ifndef DRIVERS_KEYBOARD_ASM
%define DRIVERS_KEYBOARD_ASM

%include "vga.asm"
%include "interrupt/pic.asm"

;
; A basic driver for interacting with PS/2 Keyboards
;
; https://wiki.osdev.org/PS2_Keyboard#Driver_Model
;

KEYBOARD_PORT equ 0x60

; Possible driver states
KB_SC_STATE_DEFAULT equ 0                                 ; Default state before any scan codes are processed
KB_SC_STATE_WAITING_FOR_TWO_OR_FOUR_BYTE_SCAN_CODE equ 1  ; First byte was 0xE0
KB_SC_STATE_WAITING_FOR_FOUR_BYTE_SCAN_CODE equ 2         ; First byte was 0xE0 and second byte was 0x2A or 0xB7
KB_SC_STATE_WAITING_FOR_SIX_BYTE_SCAN_CODE equ 3          ; First byte was 0xE1

; Static variable to hold the driver state
_kb_driver_state: db 0

; Buffer to hold the scan codes we've recieved (used to decode multibyte scan codes)
_kb_scan_code_buffer: times 6 db 0  ; Static 6 byte buffer to hold all the recieved scan codes
_kb_scan_code_buffer_idx: db 0      ; Static index into the scan code buffer (points to next available space in buffer)

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
; Driver init function called after interrupts are enabled on the system
;
keyboard_driver_init:
    pushad

    mov al, KB_CMD_ECHO
    call kb_queue_command

    mov al, KB_CMD_RESET_SELF_TEST
    call kb_queue_command

    mov al, KB_CMD_SCAN_CODE_SET
    mov bl, KB_CMD_DATA_SET_SCAN_CODE_1
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
    push esi

    ; Read in byte from the keyboard
    in al, KEYBOARD_PORT

    ; Check if the response is an error
    cmp al, KB_RESPONSE_ERROR_1
    je .error

    cmp al, KB_RESPONSE_ERROR_2
    je .error

    ; Check if the response is a self test pass
    cmp al, KB_RESPONSE_SELF_TEST_PASS
    je .command_self_test_pass

    ; Check if the response is a self test fail
    cmp al, KB_RESPONSE_SELF_TEST_FAIL_1
    je .command_self_test_fail

    cmp al, KB_RESPONSE_SELF_TEST_FAIL_2
    je .command_self_test_fail

    ; Check if the byte is a command acknowledgement
    cmp al, KB_RESPONSE_ACK
    je .command_acknowledgement

    ; Check if the byte is a command resend request
    cmp al, KB_RESPONSE_RESEND
    je .command_resend_request

    ; Check if the byte is a command echo
    cmp al, KB_RESPONSE_ECHO
    je .command_echo

    jmp .scan_code

    .error:
        kpanic('keyboard_driver_handle_interrupt', 'Received keyboard error response!')

    .command_self_test_pass:
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
            kpanic('keyboard_driver_handle_interrupt', 'Keyboard command self test error!')

    .command_self_test_fail:
        kpanic('keyboard_driver_handle_interrupt', 'Keyboard self test failed!')

    .command_acknowledgement:
        call kb_cmd_peek_byte

        ; If the last command was not a self test, something went wrong
        cmp al, KB_CMD_RESET_SELF_TEST
        je .finished

        ; Remove the last command from the command queue
        call kb_cmd_rm_from_queue

        ; If there are more commands in the queue, send the next one
        call kb_cmd_output_first_if_not_empty

        jmp .finished

    .command_resend_request:
        ; Resend the last command
        call kb_cmd_output_first_if_not_empty

        jmp .finished

    .command_echo:
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
            kpanic('keyboard_driver_handle_interrupt', 'Keyboard command echo error!')

    .scan_code:
        ; Store the scan code into the scan buffer
        call kb_store_scan_code_byte

        ; Compute the next state of the driver based on the value in the scan buffer
        call kb_process_scan_code_buffer

    .finished:
        pop esi
        pop eax
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
        cmp bl, KB_SC_STATE_DEFAULT
        je .state_default

        cmp bl, KB_SC_STATE_WAITING_FOR_TWO_OR_FOUR_BYTE_SCAN_CODE
        je .state_waiting_for_two_or_four_byte_scan_code

        cmp bl, KB_SC_STATE_WAITING_FOR_FOUR_BYTE_SCAN_CODE
        je .state_waiting_for_four_byte_scan_code

        cmp bl, KB_SC_STATE_WAITING_FOR_SIX_BYTE_SCAN_CODE
        je .state_waiting_for_six_byte_scan_code

    ; When the state is KB_SC_STATE_DEFAULT, there is always only 1 byte in the buffer
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
            mov bl, KB_SC_STATE_WAITING_FOR_TWO_OR_FOUR_BYTE_SCAN_CODE
            mov byte [_kb_driver_state], bl
            jmp .finished

        .move_to_six_byte_state:
            mov bl, KB_SC_STATE_WAITING_FOR_SIX_BYTE_SCAN_CODE
            mov byte [_kb_driver_state], bl
            je .finished

        .one_byte_complete:
            ; Handle the 1 byte scan code
            call kb_handle_complete_one_byte_scan_code
            jmp .reset_kb_scan_code_buffer

    ; When the state is KB_SC_STATE_WAITING_FOR_TWO_OR_FOUR_BYTE_SCAN_CODE, there are
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
            mov bl, KB_SC_STATE_WAITING_FOR_FOUR_BYTE_SCAN_CODE
            mov byte [_kb_driver_state], bl
            jmp .finished

        .two_byte_complete:
            ; Reset the state
            mov bl, KB_SC_STATE_DEFAULT
            mov byte [_kb_driver_state], bl

            ; Handle the 2 byte scan code
            call kb_handle_complete_two_byte_scan_code
            jmp .reset_kb_scan_code_buffer

    ; When the state is KB_SC_STATE_WAITING_FOR_FOUR_BYTE_SCAN_CODE, there are either
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
            mov bl, KB_SC_STATE_DEFAULT
            mov byte [_kb_driver_state], bl

            ; Handle the 4 byte scan code
            call kb_handle_complete_four_byte_scan_code
            jmp .reset_kb_scan_code_buffer

    ; When the state is KB_SC_STATE_WAITING_FOR_SIX_BYTE_SCAN_CODE, there can be
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
            mov bl, KB_SC_STATE_DEFAULT
            mov byte [_kb_driver_state], bl

            ; Handle the 6 byte scan code
            call kb_handle_complete_six_byte_scan_code
            jmp .reset_kb_scan_code_buffer

    ; Reset scan code buffer
    .reset_kb_scan_code_buffer:
        mov bl, 0
        mov byte [_kb_scan_code_buffer_idx], bl

    .finished:
        popad
        ret

;
; Defines end cases for functions that match or dont match a certain predicate
;
%macro matchable 0

    .matched:
        ; Set zero flag
        lahf                      ; Load AH from FLAGS
        or       ah, 001000000b    ; Set bit for ZF
        sahf                      ; Store AH back to Flags

        jmp .finished

    .not_matched:
        ; Clear zero flag
        lahf                      ; Load lower 8 bit from Flags into AH
        and      ah, 010111111b    ; Clear bit for ZF
        sahf                      ; Store AH back to Flags

        jmp .finished

%endmacro

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

;
; Processes a full single byte scan code
;
; Converts scan code into a key code and marks it in the key state buffer
;
kb_handle_complete_one_byte_scan_code:
    pushad

    mov byte al, [_kb_scan_code_buffer]

    ; Print the start of the message
    mov esi, .message
    call kprint

    ; Print the byte to the screen
    call kprint_byte

    ; Print a new line
    mov esi, 0
    call kprintln

    popad
    ret

    .message: db '1 byte scan code: ', 0

;
; Processes a full two byte scan code
;
; Converts scan code into a key code and marks it in the key state buffer
;
kb_handle_complete_two_byte_scan_code:
    pushad

    ; Print the start of the message
    mov esi, .message
    call kprint

    ; Print the first byte to the screen
    mov byte al, [_kb_scan_code_buffer]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the second byte to the screen
    mov byte al, [_kb_scan_code_buffer + 1]
    call kprint_byte

    ; Print a new line
    mov esi, 0
    call kprintln

    popad
    ret

    .message: db '2 byte scan code: ', 0
    .space: db ' ', 0

;
; Processes a full four byte scan code
;
; Converts scan code into a key code and marks it in the key state buffer
;
kb_handle_complete_four_byte_scan_code:
    pushad

    ; Print the start of the message
    mov esi, .message
    call kprint

    ; Print the first byte to the screen
    mov byte al, [_kb_scan_code_buffer]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the second byte to the screen
    mov byte al, [_kb_scan_code_buffer + 1]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the third byte to the screen
    mov byte al, [_kb_scan_code_buffer + 2]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the fourth byte to the screen
    mov byte al, [_kb_scan_code_buffer + 3]
    call kprint_byte

    ; Print a new line
    mov esi, 0
    call kprintln

    popad
    ret

    .message: db '4 byte scan code: ', 0
    .space: db ' ', 0

;
; Processes a full six byte scan code
;
; Converts scan code into a key code and marks it in the key state buffer
;
kb_handle_complete_six_byte_scan_code:
    pushad

    ; Print the start of the message
    mov esi, .message
    call kprint

    ; Print the first byte to the screen
    mov byte al, [_kb_scan_code_buffer]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the second byte to the screen
    mov byte al, [_kb_scan_code_buffer + 1]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the third byte to the screen
    mov byte al, [_kb_scan_code_buffer + 2]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the fourth byte to the screen
    mov byte al, [_kb_scan_code_buffer + 3]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the fifth byte to the screen
    mov byte al, [_kb_scan_code_buffer + 4]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the sixth byte to the screen
    mov byte al, [_kb_scan_code_buffer + 5]
    call kprint_byte

    ; Print a new line
    mov esi, 0
    call kprintln

    popad
    ret

    .message: db '6 byte scan code: ', 0
    .space: db ' ', 0

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
    je .finished

    ; Get the first byte in the command buffer and send it
    call kb_cmd_peek_byte
    out KEYBOARD_PORT, al

    ; If the command byte requires additional data, get the next byte in the buffer and send it too
    call kb_cmd_requires_data 
    jne .finished

    .send_data_byte:
        call io_wait
        call kb_cmd_peek_byte_data
        out KEYBOARD_PORT, al

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
; @input bl - data
;
kb_queue_command_with_data:
    pushad
    pushf
    cli

    ; Enqueue the command
    call kb_cmd_enqueue_byte

    ; Enqueue the data
    mov al, bl
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