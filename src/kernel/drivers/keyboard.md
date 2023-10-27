# Keyboard Driver Documentation

## Public Functions

The following are publicly exposed functions from the keyboard driver for use in other parts of the kernel.

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

## Keyboard Packets

Accepting keyboard input is useless if you cant consume the keys being pressed, so the following section is about the keyboard packet subscription model.

> [!WARNING]
> This function is not yet implemented

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
