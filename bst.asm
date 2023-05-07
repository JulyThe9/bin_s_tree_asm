%include 'stud_io.inc'
global _start

section .data
nodeNum         equ 5
nodeSize        equ 13
freeOffset      equ 4
leftOffset      equ 5
rightOffset     equ 9

section .bss
root            resb nodeSize * nodeNum + 1
trsize          equ $-root 
rootptr         resd 1

section .text
_start:
        ;initializing
        xor edi, edi
        mov [rootptr], dword 0
        
        ; esi will play the role of "allocator"
        ; it stores addrs of next free cell for a new
        ; node to be inserted
        mov esi, root

        mov edi, root             ;pointer to cur free cell to edi
        push edi 

        mov eax, trsize
        mov [root+eax-1], byte 't'      ;root+61 is trsize address

        push rootptr
        push dword 3
        call insert
        add esp, 8

        push rootptr
        push dword 4
        call insert
        add esp, 8
        
        push rootptr
        push dword 2
        call insert
        add esp, 8
        
        push rootptr
        push dword 5
        call insert
        add esp, 8        

        push rootptr
        push dword 9
        call insert
        add esp, 8        

        ; eax -> 2, no space
        ; push rootptr
        ; push dword 1
        ; call insert
        ; add esp, 8        

        pop edi
        push edi

        ; deleting two
        push rootptr
        push dword 2
        call delete
        add esp, 8        

        ; eax -> 2, no space
        push rootptr
        push dword 1
        call insert
        add esp, 8        

        ; deleting one
        push rootptr
        push dword 1
        call delete
        add esp, 8        
        
        ; deleting nine
        push rootptr
        push dword 9
        call delete
        add esp, 8

        ; eax -> 2, no space
        push rootptr
        push dword 10
        call insert
        add esp, 8        

        pop edi

        xor ecx, ecx            ; init sum
        push dword [rootptr]
        call travsum
        add esp, 4

        nop

        FINISH

travsum:
        push ebp
        mov ebp, esp

        ;mov ebx, [ebp+8]        ;root 
        
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

        push dword [ebp+8]            ; push value again
        push dword [ebp+12]           ; push addrs to addrs
        call search
        add esp, 8

        cmp [edi], dword 0
        jne .candelete
        mov eax, 1                    ; already exists
        jmp .quit
        
.candelete:
        mov edx, [edi]
        add edx, leftOffset
        cmp [edx], dword 0
        jne .leftChild
        mov edx, [edi]
        add edx, leftOffset
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
        cmp [edi + rightOffset], dword 0
        jne .bothChildren
        ; only child code
        jmp .quit

.rightChild:    ; if we are here then right is the only child
        ; only child code
        jmp .quit

.bothChildren:
        ; both children code
.quit:
        mov esp, ebp
        pop ebp
        ret