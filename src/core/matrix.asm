; ============================================
; core/matrix.asm
; Matrix stack management
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"

extern _cgxCoreState
extern CGXState

global _cgxCoreMatrixInit
global _cgxCoreMatrixMode
global _cgxCoreLoadIdentity
global _cgxCorePushMatrix
global _cgxCorePopMatrix

STACK_DEPTH         equ 32
MATRIX_SIZE         equ 64      ; 16 floats * 4 bytes

section .text

; --------------------------------------------
; _cgxCoreMatrixInit
; Initialized both matrix stacks to identity
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreMatrixInit:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 32

    ; Default mode: MODELVIEW
    mov dword [rel _cgxCoreState + CGXState.matrixMode], CGX_MODELVIEW

    ; Both stacks start at top = 0
    mov dword [rel _cgxCoreState + CGXState.mvTop], 0
    mov dword [rel _cgxCoreState + CGXState.projTop], 0

    ; Load identity into both stack bottoms
    lea rdi, [rel _cgxCoreState + CGXState.mvStack]
    call _writeIdentity
    lea rdi, [rel _cgxCoreState + CGXState.projStack]
    call _writeIdentity

    mov eax, 1
    add rsp, 32
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _writeIdentity
; Input: rdi = destination (64 bytes)
; Writes identity matrix in column-major order
; Clobbers: eax, rcx, rdi
; --------------------------------------------
_writeIdentity:
    ; Set everything to 0
    xor eax, eax
    mov ecx, 16
.clear:
    mov [rdi], eax
    add rdi, 4
    dec ecx
    jnz .clear

    ; Set diagonal to 1.0f
    mov eax, 0x3F800000
    mov [rdi - 64 + 0], eax     ; M[0][0]
    mov [rdi - 64 + 20], eax    ; M[1][1]
    mov [rdi - 64 + 40], eax    ; M[2][2]
    mov [rdi - 64 + 60], eax    ; M[3][3]
    ret

; --------------------------------------------
; _cgxCoreMatrixMode
; Input: eax = mode
; --------------------------------------------
_cgxCoreMatrixMode:
    mov [rel _cgxCoreState + CGXState.matrixMode], ecx
    ret

; --------------------------------------------
; _cgxCoreLoadIdentity
; Sets current top of current stack of identity
; --------------------------------------------
_cgxCoreLoadIdentity:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; Get current top
    mov eax, [rel _cgxCoreState + CGXState.matrixMode]
    cmp eax, CGX_PROJECTION
    je .proj

    ; MODELVIEW
    mov eax, [rel _cgxCoreState + CGXState.mvTop]
    shl eax, 6          ; * 64
    lea rdi, [rel _cgxCoreState + CGXState.mvStack]
    add rdi, rax
    call _writeIdentity
    jmp .done

.proj:
    mov eax, [rel _cgxCoreState + CGXState.projTop]
    shl eax, 6
    lea rdi, [rel _cgxCoreState + CGXState.projStack]
    add rdi, rax
    call _writeIdentity

.done:
    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; _cgxCorePushMatrix
; Pushes a copy of current matrix onto stack
; Output: eax = 1 ok, 0 overflow
; --------------------------------------------
_cgxCorePushMatrix:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 32

    mov eax, [rel _cgxCoreState + CGXState.matrixMode]
    cmp eax, CGX_PROJECTION
    je .proj

    ; MODELVIEW
    mov eax, [rel _cgxCoreState + CGXState.mvTop]
    cmp eax, STACK_DEPTH - 1
    jge .overflow

    ; src = stack[top]
    mov edx, eax
    shl edx, 6
    lea rsi, [rel _cgxCoreState + CGXState.mvStack]
    add rsi, rdx

    ; dst = stack[top + 1]
    add edx, 64
    lea rdi, [rel _cgxCoreState + CGXState.mvStack]
    add rdi, rdx

    ; Copy 64 bytes
    mov edx, 16
    rep movsd

    inc dword [rel _cgxCoreState + CGXState.mvTop]
    mov eax, 1
    jmp .done

.proj:
    mov eax, [rel _cgxCoreState + CGXState.projTop]
    cmp eax, STACK_DEPTH - 1
    jge .overflow

    mov edx, eax
    shl edx, 6
    lea rsi, [rel _cgxCoreState + CGXState.projStack]
    add rsi, rdx

    add edx, 64
    lea rdi, [rel _cgxCoreState + CGXState.projStack]
    add rdi, rdx

    mov ecx, 16
    rep movsd

    inc dword [rel _cgxCoreState + CGXState.projTop]
    mov eax, 1
    jmp .done

.overflow:
    xor eax, eax

.done:
    add rsp, 32
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCorePopMatrix
; Pops current matrix off the stack
; Output: eax = 1 ok, 0 underflow
; --------------------------------------------
_cgxCorePopMatrix:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    mov eax, [rel _cgxCoreState + CGXState.matrixMode]
    cmp eax, CGX_PROJECTION
    je .proj

    ; MODELVIEW
    mov eax, [rel _cgxCoreState + CGXState.mvTop]
    test eax, eax
    jz .underflow

    dec dword [rel _cgxCoreState + CGXState.mvTop]
    mov eax, 1
    jmp .done

.proj:
    mov eax, [rel _cgxCoreState + CGXState.projTop]
    test eax, eax
    jz .underflow

    dec dword [rel _cgxCoreState + CGXState.projTop]
    mov eax, 1
    jmp .done

.underflow:
    xor eax, eax

.done:
    mov rsp, rbp
    pop rbp
    ret
