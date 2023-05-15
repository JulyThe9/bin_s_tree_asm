;; bin_s_tree/ioargs.asm ;;

%include 'kernel.inc'

global readcmd

section .data
lf      db 0x0A
help1msg db "Available commands: i<number> d<number> p", 10
help1len equ $-help1msg
warr1msg db "Warning: too many cmd line args, truncated to max", 10
warr1len equ $-warr1msg

section .bss

; 1 for the action letter (i/d/p)
; 10 for digits in 4294967295 (max 32 bit uint)
; 1 for \n
; LATER

buff    resb 1+4
bsize   equ $-buff

readnodes resb 5*5

section .text
mainioctrl:
        push ebp
        mov ebp, esp
        push ebx
        push edi

        xor ecx, ecx

        mov edx, [ebp+8]    ; addrs to stirng to parse
        mov edi, [ebp+12]   ; addrs to return buffer
        cmp [edx], byte 'i'
        jne .checkdel
        
        mov bl, 'i'
        inc edx             ; start counting from digit
        push edx            ; str address
        call findstrlen
        add esp, 4

        push eax            ; how many bytes we read
        push edx            ; str address
        call atoi   
        add esp, 8

        cmp edx, 0
        je .missval

        ; check number exceeding max
        
        mov [edi], bl
        inc edi 
        mov [edi], eax

        mov ecx, 5
        jmp .quit

.checkdel:
        cmp [edx], byte 'd'
        jne .checkpr

        mov bl, 'd'
        inc edx             ; start counting from digit
        push edx            ; str address
        call findstrlen
        add esp, 4

        push eax            ; how many bytes we read
        push edx            ; str address
        call atoi   
        add esp, 8

        cmp edx, 0
        je .missval

        ; check number exceeding max
        
        mov [edi], bl
        inc edi
        mov [edi], eax

        mov ecx, 5
        jmp .quit

.checkpr:
        cmp [edx], byte 'p'
        jne .checksum
        
        mov [edi], byte 'p'

        mov ecx, 1
        jmp .quit

.checksum:
        cmp [edx], byte 's'
        jne .wrongcmd
    
        mov [edi], byte 's'

        mov ecx, 1
        jmp .quit

.missval:
.wrongcmd:
        kernel 4, 2, help1msg, help1len
.quit:
        pop edi
        pop ebx
        mov esp, ebp
        pop ebp
        ret

readcmd:
        push ebp
        mov ebp, esp
        mov esi, [ebp+8]
        mov edi, [ebp+12]
        mov ecx, [esi]
        sub ecx, 1
        cmp ecx, dword 0
        je .quit
        add esi, 8

        mov eax, [ebp+16]
        cmp ecx, eax        ; checking if too many cmd line args
        jle .lp

        push eax
        kernel 4, 2, warr1msg, warr1len
        pop eax

        mov ecx, eax

.lp:    mov edx, [esi]
        push ecx             ; storing ecx for loop

        push buff
        push edx
        call mainioctrl
        add esp, 8

        cmp ecx, 0
        je .cont
        mov cl, [buff]
        mov [edi], cl
        mov ecx, [buff+1]
        mov [edi+1], ecx
        mov [buff+1], dword 0 ; clearing the buff, 1 will be rewritten
        add edi, 5

.cont:
        pop ecx             ; restoring ecx for loop
        add esi, 4
        
        loop .lp
.quit:
        mov esp, ebp
        pop ebp
        ret

atoi:
        push ebp
        mov ebp, esp
        push ebx
        mov edx, [ebp+8]        ; our string
        mov ebx, [ebp+12]       ; how many bytes to read
        xor eax, eax            ; zero a "result so far"
.top:
        movzx ecx, byte [edx]   ; get a character
        cmp ecx, '0'            ; valid?
        jb .quit
        cmp ecx, '9'
        ja .quit
        sub ecx, '0'            ; "convert" character to number
        imul eax, 10            ; multiply "result so far" by ten
        add eax, ecx            ; add in current digit
        dec ebx
        inc edx                 ; ready for next one
        cmp ebx, 0              ; checking if we read intended num of chars
        jle .quit               ; until done
        jmp .top
.quit:
        sub edx, [ebp+8]        ; to see how many chars we have read
        pop ebx
        mov esp, ebp
        pop ebp
        ret

printnewline:
        kernel 4, 1, lf, 1
        ret

findstrlen:
        push ebp
        mov ebp, esp
        push esi
        xor eax, eax
        mov esi, [ebp+8]
.lp:
        cmp [esi], byte 0   ; cmd args are null-terminated (on Unix)
        je .quit
        inc eax
        inc esi
        jmp short .lp
.quit:
        pop esi
        mov esp, ebp
        pop ebp
        ret