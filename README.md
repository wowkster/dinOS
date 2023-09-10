# dinOS

A 32-bit hobby operating system written in x86 assembly made to explore low level computing and the x86 architecture.
It features a multi-stage bootloader which includes FAT12 drivers and a spec compliant BIOS disk IO wrapper.
The kernel is still in the very early stages but supports interrupt handling, VGA text mode drivers, and memory paging.

- Stage 1 bootloader written in x86 assembly
  - BIOS disk IO wrapper
  - FAT12 file system driver
  - Stage 2 loader
  - Error tolerant design with error messages
  - All fits into 512 byte boot sector (448 bytes when you subtract space occupied by BPB)
- Stage 2 bootloader written in x86 assembly
  - Kernel loader
  - GDT initializer
  - 32-bit protected mode initializer
- Kernel written in x86 assembly (for now)
  - VGA text mode drivers
  - PIC programming
  - IDT setup
  - Interrupt handling
  - Memory Paging
