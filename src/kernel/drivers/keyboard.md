# Keyboard Driver Documentation

## PS/2 Keyboard Commands

The PS/2 keyboard interface allows us to send certain [commands](https://wiki.osdev.org/PS/2_Keyboard#Commands) to the keyboard in order to set a part of its state, check its compatibility, and other functions.

### Available Commands

| Command                         | Description                                                         |
| ------------------------------- | ------------------------------------------------------------------- |
| KB_CMD_SET_LEDS                 | Sets the state of the keyboard's LEDs                               |
| KB_CMD_ECHO                     | Pings the keyboard and expects the same value in response           |
| KB_CMD_SCAN_CODE_SET            | Allows getting and setting the current scan code set                |
| KB_CMD_IDENTIFY                 | Identifies the type of keyboard we're working with                  |
| KB_CMD_SET_TYPEMATIC_RATE_DELAY | Sets the delay and rate for key repeating                           |
| KB_CMD_ENABLE_SCANNING          | Enables receiving key scan codes                                    |
| KB_CMD_DISABLE_SCANNING         | Disables receiving key scan codes                                   |
| KB_CMD_SET_DEFAULT_PARAMS       | Restores the keyboard to its default state                          |
| KB_CMD_RESEND                   | Tells the keyboard to resend the last byte                          |
| KB_CMD_RESET_SELF_TEST          | Resets the keyboard and forces it to do a POST (Power On Self Test) |

> [!WARNING]
> Receiving data bytes in command responses is not yet implemented!

### kb_queue_command

This function queues a keyboard command into the command queue to be sent once all other queued commands have been processed.

| Register | I/O   | Description                              |
| -------- | ----- | ---------------------------------------- |
| al       | input | The command byte to send to the keyboard |

### kb_queue_command_with_data

This function queues a keyboard command into the command queue as well as its corresponding data byte to be sent once all other queued commands have been processed.

| Register | I/O   | Description                                       |
| -------- | ----- | ------------------------------------------------- |
| al       | input | The command byte to send to the keyboard          |
| ah       | input | The data byte to send along with the command byte |

### kb_wait_for_empty_command_queue

This function will spin until all the currently enqueued commands are sent and processed by the keyboard.

Used to synchronize keyboard commands with the main kernel threads because the driver is interrupt driven.

_This function takes no arguments and does not return anything._

## Key Codes

[Scan Codes](https://wiki.osdev.org/PS2_Keyboard#Scan_Code_Set_1) are translated internally into Key Codes which are dinOS specific values that represent keys on the keyboard. They are organized into a table below:

| -    | 0                           | 1                       | 2                       | 3                          | 4                        | 5                        | 6                        | 7                 | 8                        | 9                  | A                         | B           | C          | D          | E            | F              |
| ---- | --------------------------- | ----------------------- | ----------------------- | -------------------------- | ------------------------ | ------------------------ | ------------------------ | ----------------- | ------------------------ | ------------------ | ------------------------- | ----------- | ---------- | ---------- | ------------ | -------------- |
| 0x00 | 1                           | 2                       | 3                       | 4                          | 5                        | 6                        | 7                        | 8                 | 9                        | 0                  |                           |             |            |            |              |                |
| 0x10 | a                           | b                       | c                       | d                          | e                        | f                        | g                        | h                 | i                        | j                  | k                         | l           | m          | n          | o            | p              |
| 0x20 | q                           | r                       | s                       | t                          | u                        | v                        | w                        | x                 | y                        | z                  |                           |             |            |            |              |                |
| 0x30 | `                           | -                       | =                       | [                          | ]                        | \\                       | ;                        | '                 | ,                        | .                  | /                         |             |            |            |              |                |
| 0x40 | Enter                       | Tab                     | Space                   |                            |                          |                          |                          |                   |                          |                    |                           |             |            |            |              |                |
| 0x50 | Left Shift                  | Right Shift             | Left Ctrl               | Right Ctrl                 | Left Alt                 | Right Alt (or AltGr)     | Left GUI                 | Right GUI         |                          |                    |                           |             |            | CapsLock   | NumLock      | ScrollLock     |
| 0x60 | ESC                         | Backspace               | Delete                  | Insert                     | Home                     | End                      | Page Up                  | Page Down         |                          |                    |                           |             |            |            | Print Screen | Pause          |
| 0x70 | Up Arrow                    | Left Arrow              | Down Arrow              | Right Arrow                |                          |                          |                          |                   |                          |                    |                           |             |            |            |              |                |
| 0x80 |                             |                         |                         |                            |                          |                          |                          |                   |                          |                    |                           |             |            |            |              |                |
| 0x90 | (multimedia) previous track | (multimedia) next track | (multimedia) play       | (multimedia) stop          | (multimedia) mute        | (multimedia) volume down | (multimedia) volume up   |                   |                          |                    |                           |             |            |            |              | "apps" (Menu)  |
| 0xA0 | (multimedia) calculator     | (multimedia) www home   | (multimedia) www search | (multimedia) www favorites | (multimedia) www refresh | (multimedia) www stop    | (multimedia) www forward | (multimedia) back | (multimedia) my computer | (multimedia) email | (multimedia) media select |             |            |            |              |                |
| 0xB0 | (ACPI) power                | (ACPI) sleep            | (ACPI) wake             |                            |                          |                          |                          |                   |                          |                    |                           |             |            |            |              |                |
| 0xC0 |                             |                         |                         |                            |                          |                          |                          |                   |                          |                    |                           |             |            |            |              |                |
| 0xD0 | (keypad) 0                  | (keypad) 1              | (keypad) 2              | (keypad) 3                 | (keypad) 4               | (keypad) 5               | (keypad) 6               | (keypad) 7        | (keypad) 8               | (keypad) 9         | (keypad) /                | (keypad) \* | (keypad) - | (keypad) + | (keypad) .   | (keypad) Enter |
| 0xE0 | F1                          | F2                      | F3                      | F4                         | F5                       | F6                       | F7                       | F8                | F9                       | F10                | F11                       | F12         |            |            |              |                |
| 0xF0 | F13                         | F14                     | F15                     | F16                        | F17                      | F18                      | F19                      | F20               | F21                      | F22                | F23                       | F24         |            |            |              |                |

## Key Events

Accepting keyboard input is useless if you cant consume the keys being pressed, so the following section is about the key event subscription model.

### Key Event Queue

As scan codes come in from the keyboard, the keyboard driver decodes them into dinOS [Key Codes](#Key_Codes). 
When a full key code is decoded, a key event packet is created and added to the key event queue.
The OS can then, at its leisure, pull key events from the queue or await a key event using [kb_get_next_key_event](#kb_get_next_key_event).

### Key Event Packet

Key events are encoded as 32-bit values in the following format:

```c
struct kb_key_event_packet {
    uint8_t key_code;        // Translated keycode from scan code

    char    ascii_character; // Translated ascii character (if applicable or 0 otherwise)

    uint8_t key_state;       // The new state of the key
                             //   0 - key up
                             //   1 - key down

    uint8_t modifiers;       // Bit mask of modifier keys states:
                             //   0 - shift state
                             //   1 - ctrl state
                             //   2 - alt state
                             //   3 - caps lock state
                             //   4 - num lock state
                             //   5 - scroll lock state
}
```

### kb_get_next_key_event

This function will get the next key event from the key event queue or block until one is available.

| Register | I/O    | Description          |
| -------- | ------ | -------------------- |
| eax      | Output | The key event packet |

### kb_key_event_has_shift

This function will check to see if a key event packet has the shift modifier key pressed

| Register | I/O    | Description          |
| -------- | ------ | -------------------- |
| eax      | Input  | The key event packet |
| zf       | Output | Set if the event has the shift modifier pressed |

### kb_key_event_has_ctrl

This function will check to see if a key event packet has the ctrl modifier key pressed

| Register | I/O    | Description          |
| -------- | ------ | -------------------- |
| eax      | Input  | The key event packet |
| zf       | Output | Set if the event has the ctrl modifier pressed |

### kb_key_event_has_alt

This function will check to see if a key event packet has the alt modifier key pressed

| Register | I/O    | Description          |
| -------- | ------ | -------------------- |
| eax      | Input  | The key event packet |
| zf       | Output | Set if the event has the alt modifier pressed |