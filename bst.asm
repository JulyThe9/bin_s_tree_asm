%include 'stud_io.inc'
%include 'kernel.inc'

%macro pcall 1-*
    %rep %0-1
        %rotate -1
            push dword %1
    %endrep
    %rotate -1
            call %1
            add esp, (%0-1)*4
%endmacro

global _start
extern readcmd

section .data
; reading consts
cmdNum          equ 9
cmdSize         equ 5
; tree consts
nodeNum         equ 8
nodeSize        equ 13
freeOffset      equ 4
leftOffset      equ 5
rightOffset     equ 9


section .bss
; storage cmds for tree building (cmd args)
readnodes       resb cmdSize * cmdNum     ; byte for cmd, 4 bytes for val

; actual tree
root            resb nodeSize * nodeNum + 1
trsize          equ $-root 
rootptr         resd 1

section .text
_start:
        mov eax, esp            ; recording cur stack top (# of cmd args)
        xor ecx, ecx
        mov edi, readnodes

        push dword cmdNum
        push edi
        push eax                ; for the pushed edi
        xor eax, eax
        call readcmd
        add esp, 12

        ;initializing
        xor edi, edi
        mov [rootptr], dword 0
        
        ; esi will play the role of "allocator"
        ; it stores addrs of next free cell for a new
        ; node to be inserted
        mov esi, root

        mov edi, root                   ;pointer to cur free cell to edi 

        mov eax, trsize
        mov [root+eax-1], byte 't'      ; root+trsize is rootptr address        

        mov ecx, cmdNum
        mov edx, readnodes
.lp:    push ecx
        push edx
        pcall mainctrl, edx, rootptr 
        
        pop edx
        add edx, cmdSize

        pop ecx
        loop .lp

        xor ecx, ecx                    ; init sum
        pcall travsum, [rootptr]
        nop

        kernel 1, 0

mainctrl:
        push ebp
        mov ebp, esp
        push edi
        push ebx
        mov edx, [ebp+8]    ; command + data (value)
        mov edi, [ebp+12]   ; rootptr
        mov bl, [edx]       
        cmp bl, 'i'
        jne .checkdel
        
        mov eax, [edx+1]
        pcall insert, eax, edi

        jmp .quit

.checkdel:
        cmp bl, 'd'
        jne .checkpr
        
        mov eax, [edx+1]
        pcall delete, eax, edi

        jmp .quit

.checkpr:
        cmp bl, 'p'
        jne .checksum
        ; print tree, implement later
        jmp .quit

.checksum:
        pcall travsum, [edi] 
.quit:
        pop ebx
        pop edi
        mov esp, ebp
        pop ebp
        ret

travsum:
        push ebp
        mov ebp, esp
        
        cmp dword [ebp+8], 0
        jne .rcall       
        xor ecx, ecx
        jmp .quit
.rcall: 
        push eax
        xor eax, eax

        mov ebx, [ebp+8]
        add ebx, leftOffset
        push dword [ebx]                ; [] because addrs to addrs
        call travsum
        add esp, 4
        add eax, ecx
        mov ebx, [ebp+8]
        add eax, [ebx]

        add ebx, rightOffset
        push dword [ebx]                ; [] because addrs to addrs
        call travsum
        add esp, 4
        add eax, ecx
        mov ecx, eax

        pop eax
.quit:
        mov esp, ebp
        pop ebp
        ret

; takes: query value (4 bytes) 
; and addrs to addrs to val of cur subtree
; returns: eax 0/1 
; and edi addrs to addrs to val == qvalue (addrs to 0 if not found)
search:
        push ebp
        mov ebp, esp
        ; addrs to address to val of cur subtree
        mov edi, [ebp+8]

        cmp dword [edi], 0      ; exists? 0 -> no node, !0 -> is node
        jne .contrsr
        ; let's return edi, [edi]==0 -> not found
        mov eax, 1              ; failure
        jmp .quit
.contrsr:
        mov edx, [edi]          ; now edx has an address of cur query node
        mov edx, [edx]          ; hope this is allowed, now value
        cmp edx, dword [ebp+12] ; compare qnode val and query val
        jne .leftright
        ; let's return edi, [edi]=/=0 -> found
        mov eax, 0              ; success
        jmp .quit

.leftright:
        cmp dword [ebp+12], edx 
        jg .greater
        ; will add 4 to addrs of val, here is addrs to left
        mov eax, leftOffset                     
        jmp .rcall
.greater:
        ; will add 8 to addrs of val, here is addrs to right
        mov eax, rightOffset
.rcall: 
        mov edx, [edi]          ; addrs of qnode
        add edx, eax            ; add 4 or 8 for left or right node addrs

        ; because edx is addrs to addrs we mov it to edi
        ; which served as "ptr to ptr" for us to know
        ; where to insert when inserting
        mov edi, edx

        push dword [ebp+12]     ; push value again
        push dword edx          ; addrs to addrs to left or right
        call search
        add esp, 8
.quit:
        mov esp, ebp
        pop ebp
        ret

;takes: val to insert
;addrs to addrs to root val (addrs to 0 of empty tree)
;returns eax 0/1/2 (0 success, 1 already exists, 2 out of space)
insert:
        push ebp
        mov ebp, esp
        cmp byte [esi], 't'
        jne .isfree
        mov eax, 2              ; no space
        jmp .quit

.isfree:
        push dword [ebp+8]            ; push value again
        push dword [ebp+12]           ; push addrs to addrs
        call search
        add esp, 8

        ; if addrs to 0 returned, then
        ; such value was not found,
        ; and we are in a situation when
        ; there is space, so can insert 
        cmp [edi], dword 0
        je .caninsert
        mov eax, 1                    ; already exists
        jmp .quit

.caninsert:
        mov [edi], esi
        mov eax, [ebp+8]
        mov [esi], eax
        mov [esi+freeOffset], byte 1
        mov [esi+leftOffset], dword 0
        mov [esi+rightOffset], dword 0

; cycle for saerching next free space for the next node
.cycle_sfree:
        add esi, nodeSize
        cmp [esi], byte 't'     ; no more space to traverse, quitting
        je .cycle_sfree_quit     
        cmp [esi + freeOffset], byte 1
        jne .cycle_sfree_quit  ; next node space free, quitting
        jmp .cycle_sfree        ; next node space taken, cont. traverse
.cycle_sfree_quit:        
        mov eax, 0             ; success
.quit:
        mov esp, ebp
        pop ebp
        ret

; eax 0 success, eax 1 not found
delete:
        push ebp
        mov ebp, esp

        push edi

        push dword [ebp+8]            ; push value again
        push dword [ebp+12]           ; push addrs to addrs
        call search
        add esp, 8

        cmp [edi], dword 0
        jne .candelete
        mov eax, 1                    ; already exists
        jmp .quit
        
.candelete:
        mov edx, [edi]                ; [edx] contains value
        add edx, leftOffset           
        cmp [edx], dword 0            ; now [edx] contains addrs of left
        jne .leftChild
        mov edx, [edi]
        add edx, rightOffset
        cmp [edx], dword 0
        jne .rightChild
        
        mov edx, [edi]
        mov [edi], dword 0            ; freeing
        mov [edx], dword 0            ; value to null
        mov [edx+freeOffset], byte 0  ; free
        ; not touching the children because there are none
        mov eax, 0      ; success

        cmp esi, edx    ; comparing del node addrs and cur free space addrs
        jl .quit        ; nothing as we will reach the free edx eventually 
        mov esi, edx    ; free space before cur esi, moving to have no gaps 
        jmp .quit

.leftChild:
        mov edx, [edi]
        add edx, rightOffset
        cmp [edx], dword 0
        jne .bothChildren

        ; left is the only child case

        sub edx, rightOffset
        mov [edx], dword 0            ; value to null
        mov [edx + freeOffset], byte 0  ; free        

        ; reparenting
        add edx, leftOffset    ; addrs of addrs of del node l child
        mov eax, [edx]          ; addrs of of del node l child
        
        ; d node parent's addrs to addrs to left
        ; now contains what d node's addrs to addrs to
        ; left contained
        mov [edi], eax                    
        mov [edx], dword 0      ; addrs to right to null
        
        sub edx, leftOffset
        mov eax, 0      ; success
        cmp esi, edx    ; comparing del node addrs and cur free space addrs
        jl .quit        ; nothing as we will reach the free edx eventually 
        mov esi, edx    ; free space before cur esi, moving to have no gaps 
        jmp .quit

.rightChild:    ; if we are here then right is the only child
        mov edx, [edi]
        mov [edx], dword 0            ; value to null
        mov [edx + freeOffset], byte 0  ; free        

        ; reparenting
        add edx, rightOffset    ; addrs of addrs of del node r child
        mov eax, [edx]          ; addrs of of del node r child
        
        ; d node parent's addrs to addrs to right
        ; now contains what d node's addrs to addrs to
        ; right contained
        mov [edi], eax                    
        mov [edx], dword 0      ; addrs to right to null
        
        sub edx, rightOffset
        mov eax, 0      ; success
        cmp esi, edx    ; comparing del node addrs and cur free space addrs
        jl .quit        ; nothing as we will reach the free edx eventually 
        mov esi, edx    ; free space before cur esi, moving to have no gaps 
        jmp .quit

.bothChildren:
        mov edx, [edi]
        add edx, rightOffset 
        push edx
        call findimmedsucc
        add esp, 4

        ; not needed because ebx only changed in bothChildren,
        ; and bothChildren case can't happen in a recursive call
        ; but keep it for explicit CDECL
        push ebx
        mov ebx, [edx]
        mov ebx, [ebx]          ; successor val
        
        push edx
        push ebx
        call delete 
        add esp, 8

        mov edx, [edi]          ; orig edi due to CDECL of findim...
        mov [edx], ebx             ; replacing val with successor val

        ; deletion taken care by delete call above
        ; eax has its ret value
        ; nothing more to be done

        pop ebx
.quit:
        pop edi
        mov esp, ebp
        pop ebp
        ret

; return addrs to addrs to val in edx
findimmedsucc:
        push ebp
        mov ebp, esp

        xor edx, edx
        mov edx, [ebp + 8]
        mov edx, [edx]      ; edx now has addrs to val
        add edx, leftOffset
        cmp [edx], dword 0  ; checking if there is right child
        jne .rcall
        mov edx, [ebp + 8]
        jmp .quit
.rcall:
        push edx
        call findimmedsucc 
        add esp, 4
.quit:
        mov esp, ebp
        pop ebp
        ret