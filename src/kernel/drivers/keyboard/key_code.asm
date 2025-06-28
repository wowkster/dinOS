%ifndef KEY_CODE_ASM
%define KEY_CODE_ASM

%include "drivers/keyboard/keyboard.asm"

KB_KC_1 equ 0x00
KB_KC_2 equ 0x01
KB_KC_3 equ 0x02
KB_KC_4 equ 0x03
KB_KC_5 equ 0x04
KB_KC_6 equ 0x05
KB_KC_7 equ 0x06
KB_KC_8 equ 0x07
KB_KC_9 equ 0x08
KB_KC_0 equ 0x09

KB_KC_A equ 0x10
KB_KC_B equ 0x11
KB_KC_C equ 0x12
KB_KC_D equ 0x13
KB_KC_E equ 0x14
KB_KC_F equ 0x15
KB_KC_G equ 0x16
KB_KC_H equ 0x17
KB_KC_I equ 0x18
KB_KC_J equ 0x19
KB_KC_K equ 0x1A
KB_KC_L equ 0x1B
KB_KC_M equ 0x1C
KB_KC_N equ 0x1D
KB_KC_O equ 0x1E
KB_KC_P equ 0x1F
KB_KC_Q equ 0x20
KB_KC_R equ 0x21
KB_KC_S equ 0x22
KB_KC_T equ 0x23
KB_KC_U equ 0x24
KB_KC_V equ 0x25
KB_KC_W equ 0x26
KB_KC_X equ 0x27
KB_KC_Y equ 0x28
KB_KC_Z equ 0x29

KB_KC_GRAVE_ACCENT equ 0x30
KB_KC_MINUS equ 0x31
KB_KC_EQUALS equ 0x32
KB_KC_LEFT_BRACKET equ 0x33
KB_KC_RIGHT_BRACKET equ 0x34
KB_KC_BACKSLASH equ 0x35
KB_KC_SEMICOLON equ 0x36
KB_KC_APOSTROPHE equ 0x37
KB_KC_COMMA equ 0x38
KB_KC_PERIOD equ 0x39
KB_KC_SLASH equ 0x3A

KB_KC_ENTER equ 0x40
KB_KC_TAB equ 0x41
KB_KC_SPACE equ 0x42

KB_KC_LEFT_SHIFT equ 0x50
KB_KC_RIGHT_SHIFT equ 0x51
KB_KC_LEFT_CTRL equ 0x52
KB_KC_RIGHT_CTRL equ 0x53
KB_KC_LEFT_ALT equ 0x54
KB_KC_RIGHT_ALT equ 0x55
KB_KC_LEFT_GUI equ 0x56
KB_KC_RIGHT_GUI equ 0x57

KB_KC_CAPS_LOCK equ 0x5D
KB_KC_NUM_LOCK equ 0x5E
KB_KC_SCROLL_LOCK equ 0x5F

KB_KC_ESC equ 0x60
KB_KC_BACKSPACE equ 0x61
KB_KC_DELETE equ 0x62
KB_KC_INSERT equ 0x63
KB_KC_HOME equ 0x64
KB_KC_END equ 0x65
KB_KC_PAGE_UP equ 0x66
KB_KC_PAGE_DOWN equ 0x67

KB_KC_PRT_SCN equ 0x6E
KB_KC_PAUSE equ 0x6F

KB_KC_UP_ARROW equ 0x70
KB_KC_LEFT_ARROW equ 0x71
KB_KC_DOWN_ARROW equ 0x72
KB_KC_RIGHT_ARROW equ 0x73

KB_KC_MULTIMEDIA_PREV_TRACK equ 0x90
KB_KC_MULTIMEDIA_NEXT_TRACK equ 0x91
KB_KC_MULTIMEDIA_PLAY equ 0x92
KB_KC_MULTIMEDIA_STOP equ 0x93
KB_KC_MULTIMEDIA_MUTE equ 0x94
KB_KC_MULTIMEDIA_VOLUME_DOWN equ 0x95
KB_KC_MULTIMEDIA_VOLUME_UP equ 0x96

KB_KC_APPS equ 0x9F

KB_KC_MULTIMEDIA_CALCULATOR equ 0xA0
KB_KC_MULTIMEDIA_WWW_HOME equ 0xA1
KB_KC_MULTIMEDIA_WWW_SEARCH equ 0xA2
KB_KC_MULTIMEDIA_WWW_FAVORITES equ 0xA3
KB_KC_MULTIMEDIA_WWW_REFRESH equ 0xA4
KB_KC_MULTIMEDIA_WWW_STOP equ 0xA5
KB_KC_MULTIMEDIA_WWW_FORWARD equ 0xA6
KB_KC_MULTIMEDIA_WWW_BACK equ 0xA7
KB_KC_MULTIMEDIA_MY_COMPUTER equ 0xA8
KB_KC_MULTIMEDIA_EMAIL equ 0xA9
KB_KC_MULTIMEDIA_MEDIA_SELECT equ 0xAA

KB_KC_ACPI_POWER equ 0xB0
KB_KC_ACPI_SLEEP equ 0xB1
KB_KC_ACPI_WAKE equ 0xB2

KB_KC_KEYPAD_0 equ 0xD0
KB_KC_KEYPAD_1 equ 0xD1
KB_KC_KEYPAD_2 equ 0xD2
KB_KC_KEYPAD_3 equ 0xD3
KB_KC_KEYPAD_4 equ 0xD4
KB_KC_KEYPAD_5 equ 0xD5
KB_KC_KEYPAD_6 equ 0xD6
KB_KC_KEYPAD_7 equ 0xD7
KB_KC_KEYPAD_8 equ 0xD8
KB_KC_KEYPAD_9 equ 0xD9
KB_KC_KEYPAD_SLASH equ 0xDA
KB_KC_KEYPAD_ASTERISK equ 0xDB
KB_KC_KEYPAD_MINUS equ 0xDC
KB_KC_KEYPAD_PLUS equ 0xDD
KB_KC_KEYPAD_PERIOD equ 0xDE
KB_KC_KEYPAD_ENTER equ 0xDF

KB_KC_F1 equ 0xE0
KB_KC_F2 equ 0xE1
KB_KC_F3 equ 0xE2
KB_KC_F4 equ 0xE3
KB_KC_F5 equ 0xE4
KB_KC_F6 equ 0xE5
KB_KC_F7 equ 0xE6
KB_KC_F8 equ 0xE7
KB_KC_F9 equ 0xE8
KB_KC_F10 equ 0xE9
KB_KC_F11 equ 0xEA
KB_KC_F12 equ 0xEB

KB_KC_F13 equ 0xF0
KB_KC_F14 equ 0xF1
KB_KC_F15 equ 0xF2
KB_KC_F16 equ 0xF3
KB_KC_F17 equ 0xF4
KB_KC_F18 equ 0xF5
KB_KC_F19 equ 0xF6
KB_KC_F20 equ 0xF7
KB_KC_F21 equ 0xF8
KB_KC_F22 equ 0xF9
KB_KC_F23 equ 0xFA
KB_KC_F24 equ 0xFB

KB_KC_UNUSED equ 0xFF

_kb_key_code_to_primary_ascii_char_lookup_table:
    .0x00: db '1', '2', '3', '4'
    .0x04: db '5', '6', '7', '8'
    .0x08: db '9', '0', 0,   0
    .0x0C: db 0,   0,   0,   0
    .0x10: db 'a', 'b', 'c', 'd'
    .0x14: db 'e', 'f', 'g', 'h'
    .0x18: db 'i', 'j', 'k', 'l'
    .0x1C: db 'm', 'n', 'o', 'p'
    .0x20: db 'q', 'r', 's', 't'
    .0x24: db 'u', 'v', 'w', 'x'
    .0x28: db 'y', 'z', 0,   0
    .0x2C: db 0,   0,   0,   0
    .0x30: db '`', '-', '=', '['
    .0x34: db ']', '\', ';', "'"
    .0x38: db ',', '.', '/', 0
    .0x3C: db 0,   0,   0,   0
    .0x40: db 0,   0,   ' ', 0
    .0x44: db 0,   0,   0,   0
    .0x48: db 0,   0,   0,   0
    .0x4C: db 0,   0,   0,   0
    .0x50: db 0,   0,   0,   0
    .0x54: db 0,   0,   0,   0
    .0x58: db 0,   0,   0,   0
    .0x5C: db 0,   0,   0,   0
    .0x60: db 0,   0,   0,   0
    .0x64: db 0,   0,   0,   0
    .0x68: db 0,   0,   0,   0
    .0x6C: db 0,   0,   0,   0
    .0x70: db 0,   0,   0,   0
    .0x74: db 0,   0,   0,   0
    .0x78: db 0,   0,   0,   0
    .0x7C: db 0,   0,   0,   0
    .0x80: db 0,   0,   0,   0
    .0x84: db 0,   0,   0,   0
    .0x88: db 0,   0,   0,   0
    .0x8C: db 0,   0,   0,   0
    .0x90: db 0,   0,   0,   0
    .0x94: db 0,   0,   0,   0
    .0x98: db 0,   0,   0,   0
    .0x9C: db 0,   0,   0,   0
    .0xA0: db 0,   0,   0,   0
    .0xA4: db 0,   0,   0,   0
    .0xA8: db 0,   0,   0,   0
    .0xAC: db 0,   0,   0,   0
    .0xB0: db 0,   0,   0,   0
    .0xB4: db 0,   0,   0,   0
    .0xB8: db 0,   0,   0,   0
    .0xBC: db 0,   0,   0,   0
    .0xC0: db 0,   0,   0,   0
    .0xC4: db 0,   0,   0,   0
    .0xC8: db 0,   0,   0,   0
    .0xCC: db 0,   0,   0,   0
    .0xD0: db 0,   0,   0,   0
    .0xD4: db 0,   0,   0,   0
    .0xD8: db 0,   0,   0,   0
    .0xDC: db 0,   0,   0,   0
    .0xE0: db 0,   0,   0,   0
    .0xE4: db 0,   0,   0,   0
    .0xE8: db 0,   0,   0,   0
    .0xEC: db 0,   0,   0,   0
    .0xF0: db 0,   0,   0,   0
    .0xF4: db 0,   0,   0,   0
    .0xF8: db 0,   0,   0,   0
    .0xFC: db 0,   0,   0,   0

_kb_key_code_to_secondary_ascii_char_lookup_table:
    .0x00: db '!', '@', '#', '$'
    .0x04: db '%', '^', '&', '*'
    .0x08: db '(', ')', 0,   0
    .0x0C: db 0,   0,   0,   0
    .0x10: db 'A', 'B', 'C', 'D'
    .0x14: db 'E', 'F', 'G', 'H'
    .0x18: db 'I', 'J', 'K', 'L'
    .0x1C: db 'M', 'N', 'O', 'P'
    .0x20: db 'Q', 'R', 'S', 'T'
    .0x24: db 'U', 'V', 'W', 'X'
    .0x28: db 'Y', 'Z', 0,   0
    .0x2C: db 0,   0,   0,   0
    .0x30: db '~', '_', '+', '{'
    .0x34: db '}', '|', ':', '"'
    .0x38: db '<', '>', '?', 0
    .0x3C: db 0,   0,   0,   0
    .0x40: db 0,   0,   ' ', 0
    .0x44: db 0,   0,   0,   0
    .0x48: db 0,   0,   0,   0
    .0x4C: db 0,   0,   0,   0
    .0x50: db 0,   0,   0,   0
    .0x54: db 0,   0,   0,   0
    .0x58: db 0,   0,   0,   0
    .0x5C: db 0,   0,   0,   0
    .0x60: db 0,   0,   0,   0
    .0x64: db 0,   0,   0,   0
    .0x68: db 0,   0,   0,   0
    .0x6C: db 0,   0,   0,   0
    .0x70: db 0,   0,   0,   0
    .0x74: db 0,   0,   0,   0
    .0x78: db 0,   0,   0,   0
    .0x7C: db 0,   0,   0,   0
    .0x80: db 0,   0,   0,   0
    .0x84: db 0,   0,   0,   0
    .0x88: db 0,   0,   0,   0
    .0x8C: db 0,   0,   0,   0
    .0x90: db 0,   0,   0,   0
    .0x94: db 0,   0,   0,   0
    .0x98: db 0,   0,   0,   0
    .0x9C: db 0,   0,   0,   0
    .0xA0: db 0,   0,   0,   0
    .0xA4: db 0,   0,   0,   0
    .0xA8: db 0,   0,   0,   0
    .0xAC: db 0,   0,   0,   0
    .0xB0: db 0,   0,   0,   0
    .0xB4: db 0,   0,   0,   0
    .0xB8: db 0,   0,   0,   0
    .0xBC: db 0,   0,   0,   0
    .0xC0: db 0,   0,   0,   0
    .0xC4: db 0,   0,   0,   0
    .0xC8: db 0,   0,   0,   0
    .0xCC: db 0,   0,   0,   0
    .0xD0: db 0,   0,   0,   0
    .0xD4: db 0,   0,   0,   0
    .0xD8: db 0,   0,   0,   0
    .0xDC: db 0,   0,   0,   0
    .0xE0: db 0,   0,   0,   0
    .0xE4: db 0,   0,   0,   0
    .0xE8: db 0,   0,   0,   0
    .0xEC: db 0,   0,   0,   0
    .0xF0: db 0,   0,   0,   0
    .0xF4: db 0,   0,   0,   0
    .0xF8: db 0,   0,   0,   0
    .0xFC: db 0,   0,   0,   0

;
; Gets the ASCII char representation of a key code (if applicable) based on the current state of modifier keys
; @input al - key code
; @output al - character or 0 if not applicable
;
kb_key_code_to_ascii_char:
    push ebx 
    push ecx 

    ; If the ctrl key is pressed, return 0
    call kb_is_ctrl_pressed
    je .return_null

    ; If the alt key is pressed, return 0
    call kb_is_alt_pressed
    je .return_null

    ; Choose which lookup table to use based on the state of the shift key
    call kb_is_shift_pressed
    je .use_secondary_lookup_table

    .use_primary_lookup_table:
        mov ecx, _kb_key_code_to_primary_ascii_char_lookup_table

        jmp .look_up_from_table

    .use_secondary_lookup_table:
        mov ecx, _kb_key_code_to_secondary_ascii_char_lookup_table

    .look_up_from_table:
        ; Get the key code from the lookup table
        mov ebx, 0
        mov bl, al
        mov al, [ecx + ebx]

        jmp .finished

    .return_null:
        mov al, 0

    .finished:
        pop ecx
        pop ebx
        ret

%endif