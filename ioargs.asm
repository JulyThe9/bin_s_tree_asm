;; bin_s_tree/ioargs.asm ;;

%include 'macros.inc'

; convenient for the clearing macros later on
%define strbuffsdef 12

; funcs
global readcmd
global readinp
global storenumstr
global printtree
global printnum


section .data
lf      db 0x0A
help1msg db "Available commands: i<number> d<number> p c s", 10
help1len equ $-help1msg
warr1msg db "Warning: too many cmd line args, truncated to max", 10
warr1len equ $-warr1msg

section .bss

; command parsing case:
; 1 for the action letter (i/d/p)
; 10 for digits in 4294967295 (max 32 bit uint)
; 1 for \n
; number printing case:
; 10 bytes for number, 2 bytes free
strbuff     resb strbuffsdef
strbsize    equ $-strbuff

; printtree buffer
; 10 - max num of digits
; 8 - node num
; 1*8 - that many spaces (byte)
; ['9']['4']['3']['2'][32]['3']['2'][32]...
; lengths serve as delimiters (instead of null-terminators)
; TODO: FIGURE OUT WHY GLOBAL/EXTERN nodeNum didn't work
treevals        resb 10*16 + 1*16
treevlength     resd 1          ; how many bytes of treevals occupied
treevptr        resd 1


; command buffer
; 1 byte for action, 4 bytes for (optional) arg
buff        resb 1+4
bsize       equ $-buff

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
        ; TODO [edx] first byte to reg, not to address memory n times
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

        dec eax             ; -1 for command byte    
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
        jne .checkcleartr
        
        mov [edi], byte 'p'

        mov ecx, 1
        jmp .quit

.checkcleartr:
        cmp [edx], byte 'c'
        jne .checksum
        
        mov [edi], byte 'c'

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
        jle .oknum

        push eax
        kernel 4, 2, warr1msg, warr1len
        pop eax
        mov ecx, eax

.oknum:
        xor eax, eax
        push eax
.lp:
        mov edx, [esi]
        push ecx             ; storing ecx for loop

        push buff
        push edx
        call mainioctrl
        add esp, 8

        cmp ecx, 0
        je .cont

        ; could have written directly to readcmds (edi)
        ; without buff whatsoever (see readinp)
        ; but will keep it for now for explicitness
        mov cl, [buff]
        mov [edi], cl
        mov ecx, [buff+1]
        mov [edi+1], ecx
        mov [buff+1], dword 0   ; clearing the buff, 1 will be rewritten
        add edi, 5
                                ; might be better done with loc vars
        inc dword [esp+4]       ; inc eax for a successfully read command
.cont:
        pop ecx                 ; restoring ecx for loop
        add esi, 4
        
        loop .lp
.quit:
        pop eax
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

readinp:
        push ebp
        mov ebp, esp
        
        push edi                ; CDECL
        
        mov edi, [ebp+8]        ; addrs where to write

        ; strbuff will store the parsed string
        ; the result will go directly into readcmds (ebp+8)
        kernel 3, 0, strbuff, strbsize
        cmp eax, 0
        je .quit
        
        push eax                ; to return # of read b with syscall 3
        xor ecx, ecx            ; to see the result of cmd parsing
        push edi
        push strbuff
        call mainioctrl
        add esp, 8
        pop eax
.quit:
        pop edi
        mov esp, ebp
        pop ebp
        ret

storenumstr:
        push ebp
        mov ebp, esp

        push esi
        push edi

        cmp [treevptr], dword 0
        jne .cont
        mov [treevptr], dword treevals

.cont   push dword [ebp+8]      ; num to convert (pushing for uniformity)
        call numtostr
        add esp, 4

        ; edi num start
        ; ecx how many chars we wrote
        push ecx

        mov esi, edi
        mov edi, [treevptr]

.lp:    mov dl, byte [esi]
        mov [edi], dl
        ; because strbuff is right before treevals in memory
        ; when we are done iterating and increasing esi (works with
        ; strbuff), it's pointing to treevals, so wihtout push/pop
        ; the contents of treeval can be changed through esi later
        ; (an interesting bug I discovered)
        inc esi
        inc edi
        loop .lp

        mov [edi], byte 32          ; space
        inc edi
        
        ; increase total length of occupied treevals bytes
        pop ecx
        inc ecx             ; for space
        add [treevlength], ecx
        
        ; for further call
        mov [treevptr], edi

        ; clearing the buffer
        clearbytes strbuff, strbuffsdef    
.quit:
        mov edi, treevals
        pop edi
        pop esi
        mov esp, ebp
        pop ebp
        ret

printtree:
        push ebp
        mov ebp, esp
        kernel 4, 1, treevals, [treevlength]
        call printnewline

        ; resetting the buffer data (but not the buffer itself)
        ; for the next storenumstr calls
        mov [treevptr], dword treevals
        mov [treevlength], dword 0
.quit:
        mov esp, ebp
        pop ebp
        ret

printnum:
        push ebp
        mov ebp, esp
        push edi

        push dword [ebp+8]      ; num to convert (pushing for uniformity)
        call numtostr
        add esp, 4

        kernel 4, 1, edi, ecx   ; how many chars we wrote
        call printnewline

        ; clearing the buffer
        clearbytes strbuff, strbuffsdef    
.quit:
        pop edi
        mov esp, ebp
        pop ebp
        ret

numtostr:
        push ebp
        mov ebp, esp

        xor edx, edx            ; edx:eax used for the dividend
        lea edi, [strbuff + strbsize - 1]
        mov ecx, 10
        mov eax, [ebp+8]        ; num to convert

        ; not more than 10 digits because elf_i386 and eax (4 bytes)
        ; but TODO: might write a check, not to mess up memory
.again: 
        div ecx
        mov [edi], dl           ; remainder < 10, 1 digit, lowest bits
        add [edi], byte 48           ; converting to asci
        cmp eax, 0
        je .cont
        dec edi
        mov edx, 0              ; edx:eax pair in div, so need to null edx
        jmp short .again
.cont:
        lea ecx, [strbuff + strbsize]
        sub ecx, edi

.quit:
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