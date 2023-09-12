%ifndef DRIVERS_KEYBOARD_ASM
%define DRIVERS_KEYBOARD_ASM

%include "vga.asm"

;
; A basic driver for interacting with PS/2 Keyboards
;
; https://wiki.osdev.org/PS2_Keyboard#Driver_Model
;

KEYBOARD_PORT equ 0x60

; Possible driver states
STATE_DEFAULT equ 0                                 ; Default state before any scan codes are processed
STATE_WAITING_FOR_TWO_OR_FOUR_BYTE_SCAN_CODE equ 1  ; First byte was 0xE0
STATE_WAITING_FOR_FOUR_BYTE_SCAN_CODE equ 2         ; First byte was 0xE0 and second byte was 0x2A or 0xB7
STATE_WAITING_FOR_SIX_BYTE_SCAN_CODE equ 3          ; First byte was 0xE1

; Static variable to hold the driver state
_driver_state: db 0

; Buffer to hold the scan codes we've recieved (used to decode multibyte scan codes)
_scan_code_buffer: times 6 db 0  ; Static 6 byte buffer to hold all the recieved scan codes
_scan_code_buffer_idx: db 0      ; Static index into the scan code buffer (points to next available space in buffer)

;
; Handler for keyboard interrupts as they come in from the PS/2 controller
;
keyboard_driver_handle_interrupt:
    push eax
    push esi

    ; Read in scan code
    in al, KEYBOARD_PORT

    ; Store the scan code into the scan buffer
    call keyboard_driver_store_scan_code_byte

    ; Compute the next state of the driver based on the value in the scan buffer
    call keyboard_driver_process_scan_code_buffer

    pop esi
    pop eax
    ret

;
; Stores the requested scan code into the scan buffer for processing
; @input al - scan code
;
keyboard_driver_store_scan_code_byte:
    pushad

    ; Store the scan code byte into the next available slot in the buffer
    mov ebx, 0
    mov byte bl, [_scan_code_buffer_idx]
    mov byte [_scan_code_buffer + ebx], al

    ; Increment the buffer index
    inc ebx
    mov byte [_scan_code_buffer_idx], bl

    popad
    ret

;
; Looks at the scan buffer and changes the state based on its value
;
; This is where invalid scan codes are discarded
;
keyboard_driver_process_scan_code_buffer:
    pushad

    ; Get the length of the scan code buffer
    mov ebx, 0
    mov byte bl, [_driver_state]
    
    ; Branch to the correct case based on its length
    .branch_to_buffer_len_case:
        cmp bl, STATE_DEFAULT
        je .state_default

        cmp bl, STATE_WAITING_FOR_TWO_OR_FOUR_BYTE_SCAN_CODE
        je .state_waiting_for_two_or_four_byte_scan_code

        cmp bl, STATE_WAITING_FOR_FOUR_BYTE_SCAN_CODE
        je .state_waiting_for_four_byte_scan_code

        cmp bl, STATE_WAITING_FOR_SIX_BYTE_SCAN_CODE
        je .state_waiting_for_six_byte_scan_code

    ; When the state is STATE_DEFAULT, there is always only 1 byte in the buffer
    .state_default:
        ; Check if the first byte is a valid single byte scan code
        call keyboard_driver_is_one_byte_scancode_valid
        je .one_byte_complete

        ; If the first byte is the start of an extended multibyte scan code,
        ; determine the new state and then wait for more bytes
        mov byte al, [_scan_code_buffer]

        ; Could be the start of a 2 byte scan code or a 4 byte scan code
        cmp al, 0xE0
        je .move_to_two_or_four_byte_state

        ; Has to be the start of a 6 byte scan code
        cmp al, 0xE1
        je .move_to_six_byte_state

        ; If neither cases matched, the scan code must be invalid
        je .reset_scan_code_buffer

        .move_to_two_or_four_byte_state:
            mov bl, STATE_WAITING_FOR_TWO_OR_FOUR_BYTE_SCAN_CODE
            mov byte [_driver_state], bl
            jmp .finished

        .move_to_six_byte_state:
            mov bl, STATE_WAITING_FOR_SIX_BYTE_SCAN_CODE
            mov byte [_driver_state], bl
            je .finished

        .one_byte_complete:
            ; Handle the 1 byte scan code
            call keyboard_driver_handle_complete_one_byte_scan_code
            jmp .reset_scan_code_buffer

    ; When the state is STATE_WAITING_FOR_TWO_OR_FOUR_BYTE_SCAN_CODE, there are
    ; always 2 bytes in the buffer and the first byte is always 0xE0
    .state_waiting_for_two_or_four_byte_scan_code:
        ; Check if the first 2 bytes are a valid single byte scan code
        call keyboard_driver_is_two_byte_scancode_valid
        je .two_byte_complete

        ; If the first 2 bytes themselves are not a valid scan code, it could
        ; be the start of a 4 byte scan code. The second byte of a 4 byte scan
        ; code must be either 0x2A or 0xB7
        mov byte al, [_scan_code_buffer + 1]

        cmp al, 0x2A
        je .move_to_four_byte_state

        cmp al, 0xB7
        je .move_to_four_byte_state

        ; If neither cases matched, the scan code must be invalid
        jmp .reset_scan_code_buffer

        .move_to_four_byte_state:
            mov bl, STATE_WAITING_FOR_FOUR_BYTE_SCAN_CODE
            mov byte [_driver_state], bl
            jmp .finished

        .two_byte_complete:
            ; Reset the state
            mov bl, STATE_DEFAULT
            mov byte [_driver_state], bl

            ; Handle the 2 byte scan code
            call keyboard_driver_handle_complete_two_byte_scan_code
            jmp .reset_scan_code_buffer

    ; When the state is STATE_WAITING_FOR_FOUR_BYTE_SCAN_CODE, there are either
    ; 3 or 4 bytes in the scan code buffer
    .state_waiting_for_four_byte_scan_code:       
        ; Get the current buffer length and branch
        mov byte cl, [_scan_code_buffer_idx] 
        
        cmp cl, 3
        je .three_byte_case        
        
        cmp cl, 4
        je .four_byte_case

        .three_byte_case:
            ; Get the third byte of the scan code buffer
            mov byte al, [_scan_code_buffer + 2]
            
            ; The 3rd byte must always be 0xE0
            cmp al, 0xE0
            je .finished

            ; Any other values are invalid
            jmp .reset_scan_code_buffer

        .four_byte_case:
            ; If there are 4 bytes, check if the current scan code is a valid 4 byte scan code
            call keyboard_driver_is_four_byte_scancode_valid
            je .four_byte_complete

            ; If the value is invalid, throw it away and ignore it
            jmp .reset_scan_code_buffer

        .four_byte_complete:
            ; Reset the state
            mov bl, STATE_DEFAULT
            mov byte [_driver_state], bl

            ; Handle the 4 byte scan code
            call keyboard_driver_handle_complete_four_byte_scan_code
            jmp .reset_scan_code_buffer

    ; When the state is STATE_WAITING_FOR_SIX_BYTE_SCAN_CODE, there can be
    ; anywhere from 2 to 6 bytes in the scan code buffer
    .state_waiting_for_six_byte_scan_code:
        ; Get the current buffer length and branch
        mov byte cl, [_scan_code_buffer_idx] 

        ; If there are less than 6 bytes in the buffer, just keep reading
        ; We could short circuit if we get an invalid scan code but thats a lot of work
        cmp cl, 6
        jl .finished

        .six_byte_case:
            ; Check to make sure that the 6 bytes in the scan code buffer make 
            ; a valid scan code (pause pressed)
            call keyboard_driver_is_six_byte_scancode_valid
            je .six_byte_complete

            ; If the value is invalid, throw it away and ignore it
            jmp .reset_scan_code_buffer

        .six_byte_complete:
            ; Reset the state
            mov bl, STATE_DEFAULT
            mov byte [_driver_state], bl

            ; Handle the 6 byte scan code
            call keyboard_driver_handle_complete_six_byte_scan_code
            jmp .reset_scan_code_buffer

    ; Reset scan code buffer
    .reset_scan_code_buffer:
        mov bl, 0
        mov byte [_scan_code_buffer_idx], bl

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
keyboard_driver_is_one_byte_scancode_valid:
    pushad

    ; Get the first byte in the buffer
    mov byte al, [_scan_code_buffer]

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
keyboard_driver_is_two_byte_scancode_valid:
    pushad

    ; Get the first 2 bytes in the buffer
    mov byte ah, [_scan_code_buffer]
    mov byte al, [_scan_code_buffer + 1]

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
keyboard_driver_is_four_byte_scancode_valid:
    pushad

    mov byte al, [_scan_code_buffer + 1]
    mov byte ah, [_scan_code_buffer + 3]

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
keyboard_driver_is_six_byte_scancode_valid:
    pushad

    mov byte al, [_scan_code_buffer + 1]
    cmp al, 0x1D
    jne .not_matched

    mov byte al, [_scan_code_buffer + 2]
    cmp al, 0x45
    jne .not_matched

    mov byte al, [_scan_code_buffer + 3]
    cmp al, 0xE1
    jne .not_matched

    mov byte al, [_scan_code_buffer + 4]
    cmp al, 0x9D
    jne .not_matched

    mov byte al, [_scan_code_buffer + 5]
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
keyboard_driver_handle_complete_one_byte_scan_code:
    pushad

    mov byte al, [_scan_code_buffer]

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
keyboard_driver_handle_complete_two_byte_scan_code:
    pushad

    ; Print the start of the message
    mov esi, .message
    call kprint

    ; Print the first byte to the screen
    mov byte al, [_scan_code_buffer]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the second byte to the screen
    mov byte al, [_scan_code_buffer + 1]
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
keyboard_driver_handle_complete_four_byte_scan_code:
    pushad

    ; Print the start of the message
    mov esi, .message
    call kprint

    ; Print the first byte to the screen
    mov byte al, [_scan_code_buffer]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the second byte to the screen
    mov byte al, [_scan_code_buffer + 1]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the third byte to the screen
    mov byte al, [_scan_code_buffer + 2]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the fourth byte to the screen
    mov byte al, [_scan_code_buffer + 3]
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
keyboard_driver_handle_complete_six_byte_scan_code:
    pushad

    ; Print the start of the message
    mov esi, .message
    call kprint

    ; Print the first byte to the screen
    mov byte al, [_scan_code_buffer]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the second byte to the screen
    mov byte al, [_scan_code_buffer + 1]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the third byte to the screen
    mov byte al, [_scan_code_buffer + 2]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the fourth byte to the screen
    mov byte al, [_scan_code_buffer + 3]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the fifth byte to the screen
    mov byte al, [_scan_code_buffer + 4]
    call kprint_byte

    ; Print a space
    mov esi, .space
    call kprint

    ; Print the sixth byte to the screen
    mov byte al, [_scan_code_buffer + 5]
    call kprint_byte

    ; Print a new line
    mov esi, 0
    call kprintln

    popad
    ret

    .message: db '6 byte scan code: ', 0
    .space: db ' ', 0

%endif