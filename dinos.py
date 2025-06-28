#!/usr/bin/env python3

import os
import sys
import subprocess

class ansi_colors:
    RED = '\033[91m'
    GRAY = '\033[90m'
    DEFAULT = '\033[0m'

## Run the given program with the given arguments
def execute_program(program: str, arguments: list[str]):
    print(ansi_colors.GRAY +
          f"Executing command: {program} {' '.join(arguments)}" + ansi_colors.DEFAULT)
    os.execvp(program, [program, *arguments])


## Run qemu with the given additional arguments
def run_qemu(additional_arguments: list[str] = []):
    program = "qemu-system-i386"
    arguments = ["-monitor", "stdio", "-fda",
                 "./build/main.img", "-name", "dinOS"]
    arguments.extend(additional_arguments)

    execute_program(program, arguments)

class ProcessorMode:
    REAL = 0
    PROTECTED = 1

## Run gdb for the given processor mode
def run_gdb(mode: ProcessorMode):
    # TODO: investigate using vscode GUI for gdb - https://andwass.gitlab.io/blog/2019/02/13/debugging-qemu.html

    program = "gdb"

    match mode:
        case ProcessorMode.REAL:
            # Launches GDB with support for real mode
            arguments = ["-ix", "gdb/gdb_init_real_mode.txt", "-ex", "set tdesc filename gdb/target.xml",
                         "-ex", "target remote localhost:1234", "-ex", "br *0x7c00", "-ex", "c"]

            execute_program(program, arguments)

        case ProcessorMode.PROTECTED:
            # Launches GDB with support for protected mode
            arguments = ["-ix", "gdb/gdb_init_protected_mode.txt", "-ex",
                         "target remote localhost:1234", "-ex", "br *0x10000", "-ex", "c"]

            execute_program(program, arguments)

        case _:
            raise Exception("Invalid processor mode")

## Print the help message
def print_help():
    print("dinOS - a simple operating system written in x86 Assembly")
    print()
    print("Usage: dinos.py [command]")
    print()
    print("Commands:")
    print("  run             (default) Run the operating system")
    print("  debug           Run the operating system in debug mode")
    print("  gdb <mode>      Run GDB for the operating system (in either real or protected mode))")
    print("  build           Build the operating system image from source")
    print("  clean           Clean the build directory")
    print("  check           Check that all dependencies are installed")
    print("  help            Show this help message")
    exit(0)

## Print the given error message and exit
def print_error(message: str):
    print(message, file=sys.stderr)
    exit(1)

## If too many arguments are given, print an error and exit
def expect_argc(argc: int):
    if len(sys.argv) > argc:
        print_error(f"Unexpected argument `{sys.argv[argc]}`. Run 'dinos.py help' for more information.")
        exit(1)

## Check that the given dependency is installed
def check_dependency(name: str, program_args: list[str]):
    try:
        subprocess.call(program_args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except FileNotFoundError:
        print_error(f"{name} is not installed. Please install it and try again.")

## Ensure that the dependencies are installed
def ensure_dependencies():
    check_dependency("QEMU", ["qemu-system-i386", "--version"])
    check_dependency("Make", ["make", "--version"])
    check_dependency("NASM", ["nasm", "-v"])
    check_dependency("dosfstools", ["mkfs.fat"])
    check_dependency("dosfstools", ["mcopy"])
    
    print("All dependencies are installed.")

if __name__ == "__main__":

    # If no arguments are given, run qemu
    if len(sys.argv) == 1:
        run_qemu()

    # Otherwise, run the command
    match sys.argv[1]:
        case 'run':
            expect_argc(2)
            run_qemu()

        case 'debug':
            expect_argc(2)
            run_qemu(["-boot", "a", "-s", "-S"])

        case 'help':
            expect_argc(2)
            print_help()

        case 'gdb':
            if len(sys.argv) == 2:
                print_error(
                    "No mode given. Valid modes are 'real' and 'protected'.")

            expect_argc(3)

            match sys.argv[2]:
                case 'real':
                    run_gdb(mode = ProcessorMode.REAL)
                case 'protected':
                    run_gdb(mode = ProcessorMode.PROTECTED)
                case _:
                    print_error(
                        f"Invalid mode `{sys.argv[2]}`. Valid modes are 'real' and 'protected'.")
                    
        case 'build':
            expect_argc(2)
            execute_program("make", [])
        
        case 'clean':
            expect_argc(2)
            execute_program("make", ["clean"])
        
        case 'check':
            expect_argc(2)
            ensure_dependencies()

        case _:
            print_error(
                f"Invalid command `{sys.argv[1]}`. Run 'dinos.py help' for more information.")
            exit(1)
