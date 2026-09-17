; ============================================
; core/vao.asm
; Vertex Array Object pool
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"

extern VirtualAlloc
extern VirtualFree

extern _cgxCoreState
extern CGXState

global _cgxCoreVAOInit
global _cgxCoreVAOCreate
global _cgxCoreVAODelete
global _cgxCoreVAOBind
global _cgxCoreVAOAttribPointer
global _cgxCoreVAOEnableAttrib
global _cgxCoreVAODisableAttrib
global _cgxCoreVAOGetAttrib

MEM_COMMIT                  equ 0x00001000
MEM_RESERVE                 equ 0x00002000
MEM_RELEASE                 equ 0x00008000
PAGE_READWRITE              equ 0x04
INITIAL_VAO_CAPACITY        equ 16

section .text

; --------------------------------------------
; _cgxCoreVAOInit
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreVAOInit:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    xor rcx, rcx
    mov rdx, INTIAL_VAO_CAPACITY * VAO_size
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail

    mov [rel _cgxCoreState + CGXState.vaoPool], rax
    mov dword [rel _cgxCoreState + CGXState.vaoCapacity], INITIAL_VAO_CAPACITY
    mov dword [rel _cgxCoreState + CGXState.vaoCount], 0
    mov dword [rel _cgxCoreState + CGXState.nextVaoId], 1
    mov dword [rel _cgxCoreState + CGXState.boundVAO], 0

    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreVAOCreate
; Output: eax = vao id (>0), 0 on failure
; --------------------------------------------
_cgxCoreVAOCreate:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 32

    ; Find free slot
    mov rbx, [rel _cgxCoreState + CGXState.vaoPool]
    mov ecx, [rel _cgxCoreState + CGXState.vaoCapacity]
    xor eax, eax

.findSlot:
    cmp eax, ecx
    jge .fail

    mov edx, eax
    imul edx, VAO_size
    mov rdi, rbx
    add rdi, rdx

    cm byte [rdi + VAO.inUse], 0
    je .slotFound
    inc eax
    jmp .findSlot
.slotFound:
    ; Clear the slot (all bytes zero)
    push rax
    push rdi

    mov rcx, VAO_size
    xor eax, eax
    rep stosb

    pop rdi
    pop rax

    ; Assign id and mark in use
    mov edx, [rel _cgxCoreState + CGXState.nextVaoId]
    mov [rdi + VAO.id], edx
    mov byte [rdi + VAO.inUse], 1

    inc dword [rel _cgxCoreState + CGXState.nextVaoId]
    inc dword [rel _cgxCoreState + CGXState.vaoCount]

    mov eax, edx
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 32
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreVAODelete
; Input: ecx = vao id
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreVAODelete:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 32

    mov r12d, ecx
    mov rbx, [rel _cgxCoreState + CGXState.vaoPool]
    mov ecx, [rel _cgxCoreState + CGXState.vaoCapacity]
    xor eax, eax

.scan:
    cmp eax, ecx
    jge .notFound

    mov edx, eax
    imul edx, VAO_size
    mov rdi, rbx
    add rdi, rdx

    cmp byte [rdi + VAO.inUse], 0
    je .next

    cmp dword [rdi + VAO.id], r12d
    je .found
.next:
    inc eax
    jmp .scan

.found:
    mov byte [rdi + VAO.inUse], 0
    dec dword [rel _cgxCoreState + CGXState.vaoCount]

    cmp dword [rel _cgxCoreState + CGXState.boundVAO], r12d
    jne .noUnbind
    mov dword [rel _cgxCoreState + CGXState.boundVAO], 0

.noUnbind:
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
; _cgxCoreVAOBind
; Input: ecx = vao id
; Output: eax 1 ok, 0 fail
; --------------------------------------------
_cgxCoreVAOBind:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 32

    mov r12d, ecx
    mov rbx, [rel _cgxCoreState + CGXState.vaoPool]
    mov ecx, [rel _cgxCoreState + CGXState.vaoCapacity]
    xor eax, eax

.scan:
    cmp eax, ecx
    jge .notFound

    mov edx, eax
    imul edx, VAO_size
    mov rdi, rbx
    add rdi, rdx

    cmp byte [rdi + VAO.inUse], 0
    je .next

    cmp dword [rdi + VAO.id], r12d
    je .found
.next:
    inc eax
    jmp .scan

.found:
    mov [rel _cgxCoreState + CGXState.boundVAO], r12d
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
; _cgxCoreVAOFindBound
; Helper: returns rdi = pointer to bound VAO, or 0
; --------------------------------------------
_cgxCoreVAOFindBound:
    
