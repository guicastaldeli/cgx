; ============================================
; core/buffer.asm
; Vertex/Index buffer pool
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"

extern VirtualAlloc
extern VirtualFree

extern _cgxCoreState
extern CGXState

global _cgxCoreBufferInit
global _cgxCoreBufferCreate
global _cgxCoreBufferDelete
global _cgxCoreBufferBind
global _cgxCoreBufferGetData
global _cgxCoreBufferGetSize

MEM_COMMIT              equ 0x00001000
MEM_RESERVE             equ 0x00002000
MEM_RELEASE             equ 0x00008000
PAGE_READWRITE          equ 0x04
INITIAL_CAPACITY        equ 16

section .text

; --------------------------------------------
; _cgxCoreBufferInit
; Initialized the buffer pool
; Output: eax = 1, 0 fail
; --------------------------------------------
_cgxCoreBufferInit:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; Allocate initial pool: INTIIAL_CAPACITY * Buffer_size bytes
    xor rcx, rcx
    mov rdx, INITIAL_CAPACITY * Buffer_size
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail

    mov [rel _cgxCoreState + CGXState.bufferPool], rax
    mov dword [rel _cgxCoreState + CGXState.bufferCapacity], INITIAL_CAPACITY
    mov dword [rel _cgxCoreState + CGXState.bufferCount], 0
    mov dword [rel _cgxCoreState + CGXState.nextBufferId], 1

    mov eax, 1
    jmp .done
.fail:
    xor eax, eax

.done:
    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreBufferCreate
; Input: rcx = data ptr, rdx = size in bytes, 
;        r8d = usage
;        r9d = buffer type (VERTEX/INDEX)
; Output: eax = buffer id (>0), or 0 on failure
; --------------------------------------------
_cgxCoreBufferCreate:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32

    mov r12, rcx        ; data ptr
    mov r13, rdx        ; size
    mov r14d, r8d       ; usage
    mov r15d, r9d       ; type

    ; Find a free slot
    mov rbx, [rel _cgxCoreState + CGXState.bufferPool]
    mov ecx, [rel _cgxCoreState + CGXState.bufferCapacity]
    xor eax, eax        ; index

.findSlot:
    cmp eax, ecx
    jge .growPool

    ; slot = pool + index * Buffer_size
    mov edx, eax
    imul edx, Buffer_size
    mov rdi, rbx
    add rdi, rdx

    cmp byte [rdi + Buffer.inUse], 0
    je .slotFound
    inc eax
    jmp .findSlot
.growPool:
    jmp .fail
.slotFound:
    ; rdi = free slot
    ; rbx = pool base
    ; eax = slot index
    ; r12 = data ptr (src)
    ; r13 = size
    ; r14d = usage
    ; r15d = type

    mov rbx, rdi

    ; Save nextBufferId
    mov edx, [rel _cgxCoreState + CGXState.nextBufferId]
    push rdx

    ; Allocate data buffer
    xor rcx, rcx
    mov rdx, r13
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .alloc_fail

    mov r8, rax

    ; Copt src -> dst
    mov rdi, r8         ; dst
    mov rsi, r12        ; src
    mov rcx, r13        ; byte count
    rep movsb

    ; Restore nextBufferId
    pop rdx

    ; Fill slot (rbx = slot ptr, r8 = data ptr, rdx = id)
    mov [rbx + Buffer.id], edx
    mov [rdx + Buffer.data], r8
    mov [rbx + Buffer.size], r13
    mov [rbx + Buffer.usage], r14d
    mov [rbx + Buffer.type], r15d
    mov byte [rbx + Buffer.inUse], 1

    ; Increment id and count
    inc dword [rel _cgxCoreState + CGXState.nextBufferId]
    inc dword [rel _cgxCoreState + CGXState.bufferCount]

    mov eax, edx        ; return id
    jmp .done

.alloc_fail:
    pop rdx
    jmp .fail
.fail:
    xor eax, eax

.done:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreBufferDelete
; Input: ecx = buffer id
; Output: eax = 1, 0 fail
; --------------------------------------------
_cgxCoreBufferDelete:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 32

    mov r12d, ecx       ; id to delete

    mov rbx, [rel _cgxCoreState + CGXState.bufferPool]
    mov ecx, [rel _cgxCoreState + CGXState.bufferCapacity]
    xor eax, eax

.scan:
    cmp eax, ecx
    jge .notFound

    mov edx, eax
    imul edx, Buffer_size
    mov rdi, rbx
    add rdi, rdx

    cmp byte [rdi + Buffer.inUse], 0
    je .next

    cmp dword [rdi + Buffer.id], r12d
    je .found
.next:
    inc eax
    jmp .scan
.found:
    ; Free the data
    mov rcx, [rdi + Buffer.data]
    test rcx, rcx
    jz .markFree

    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree
.markFree:
    mov byte [rdi + Buffer.inUse], 0
    mov qword [rdi + Buffer.data], 0
    dec dword [rel _cgxCoreState + CGXState.bufferCount]

    mov eax, 1
    jmp .done

.notFound:
    xor eax, eax

.done:
    add rsp, 32
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreBufferBind
; Input: ecx = buffer id, edx = type (VERTEX/INDEX)
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreBufferBind:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 32

    mov r12d, ecx       ; id
    mov r13d, edx       ; type

    mov rbx, [rel _cgxCoreState + CGXState.bufferPool]
    mov ecx, [rel _cgxCoreState + CGXState.bufferCapacity]
    xor eax, eax

.scan:
    cmp eax, ecx
    jge .notFound

    mov edx, eax
    imul edx, Buffer_size
    mov rdi, rbx
    add rdi, rdx

    cmp byte [rdi + Buffer.inUse], 0
    je .next

    cmp dword [rdi + Buffer.id], r12d
    je .found
.next:
    inc eax
    jmp .scan
.found:
    ; Store bound id in state
    cmp r13d, CGX_BUFFER_INDEX
    je .bindEBO

    ; Bind VBO  
    mov [rel _cgxCoreState + CGXState.boundVBO], r12d
    mov eax, 1
    jmp .done

.bindEBO:
    mov [rel _cgxCoreState + CGXState.boundEBO], r12d
    mov eax, 1
    jmp .done

.notFound:
    xor eax, eax

.done:
    add rsp, 32
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreBufferGetData
; Input: ecx = buffer id
; Output: rax = data pointer, or 0 if not found...
; --------------------------------------------
_cgxCoreBufferGetData:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 32

    mov r12d, ecx
    mov rbx, [rel _cgxCoreState + CGXState.bufferPool]
    mov ecx, [rel _cgxCoreState + CGXState.bufferCapacity]
    xor eax, eax

.scan:
    cmp eax, ecx
    jge .notFound

    mov edx, eax
    imul edx, Buffer_size
    mov rdi, rbx
    add rdi, rdx

    cmp byte [rdi + Buffer.inUse], 0
    je .next

    cmp dword [rdi + Buffer.id], r12d
    je .found
.next:
    inc eax
    jmp .scan

.found:
    mov rax, [rdi + Buffer.data]
    jmp .done
.notFound:
    xor eax, eax

.done:
    add rsp, 32
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreBufferGetSize
; Input: ecx = buffer id
; Output: rax = size in bytes, or 0 if not found...
; --------------------------------------------
_cgxCoreBufferGetSize:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 32

    mov r12d, ecx
    mov rbx, [rel _cgxCoreState + CGXState.bufferPool]
    mov ecx, [rel _cgxCoreState + CGXState.bufferCapacity]
    xor eax, eax

.scan:
    cmp eax, ecx
    jge .notFound

    mov edx, eax
    imul edx, Buffer_size
    mov rdi, rbx
    add rdi, rdx

    cmp byte [rdi + Buffer.inUse], 0
    je .next

    cmp dword [rdi + Buffer.id], r12d
    je .found
.next:
    inc eax
    jmp .scan

.found:
    mov rax, [rdi + Buffer.size]
    jmp .done
.notFound:
    xor eax, eax

.done:
    add rsp, 32
    pop r12
    pop rbx
    pop rbp
    ret