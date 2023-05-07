#!/bin/bash
nasm -l bst.lst -f elf -g bst.asm
ld -m elf_i386 bst.o -o bst