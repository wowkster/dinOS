:: Launches GDB with support for real mode
:: TODO: investigate using vscode GUI for gdb - https://andwass.gitlab.io/blog/2019/02/13/debugging-qemu.html
gdb.exe -ix "gdb/gdb_init_protected_mode.txt" -ex "target remote localhost:1234" -ex "br *0x10000" -ex "c"