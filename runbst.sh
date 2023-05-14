#!/bin/bash
nasm -f elf -g bst.asm
nasm -f elf -g ioargs.asm
ld -m elf_i386 bst.o ioargs.o -o bst