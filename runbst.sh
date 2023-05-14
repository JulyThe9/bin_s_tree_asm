#!/bin/bash
nasm -f elf -g -dOS_LINUX bst.asm
nasm -f elf -g -dOS_LINUX ioargs.asm
ld -m elf_i386 bst.o ioargs.o -o bst