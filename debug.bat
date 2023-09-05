:: Launches GDB with support for real mode
gdb.exe -ix "gdb/gdb_init_real_mode.txt" -ex "set tdesc filename gdb/target.xml" -ex "target remote localhost:1234" -ex "br *0x7c00" -ex "c"