; ============================================
; core/depth.asm
; Depth buffer management
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"

extern VirtualAlloc
extern VirtualFree

extern _cgxCoreState
extern CGXState

global _cgxCoreDepthInit
global _cgxCoreDepthFree
global _cgxCoreDepthClear
global _cgxCoreSetDepth
global _cgxCoreDepthTest

MEM_COMMIT              equ 0x00001000
MEM_RESERVE             equ 0x00002000
MEM_RELEASE             equ 0x00008000
PAGE_READWRITE          equ 0x04

section .text

; --------------------------------------------
; _cgxCoreDepthInit
; Input: ecx = width, edx = height
; Output: eax = 1 ok, 0 fail
; Allocates depth buffer (float per pixel)
; --------------------------------------------
_cgxCoreDepthInit:
    push rbp
    mov rbp, rsp
    sub rsp 32

    ; size = width * height * 4
    mov eax, ecx
    imul eax, edx
    shl eax, 2
    mov r8, rax         ; save size

    xor rcx, rcx
    mov rdx, r8
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail

    mov [rel _cgxCoreState + CGXState.depthBuffer], rax

    ; Default depth func = CGX_LESS
    mov dword [rel _cgxCoreState + CGXState.depthFunc], CGX_LESS
    mov byte [rel _cgxCoreState + CGXState.depthTestEnabled], 0
    mov dword [rel _cgxCoreState + CGXState.drawDepth], 0x3F800000      ; 1.0f

    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreDepthFree
; --------------------------------------------
_cgxCoreDepthFree:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    mov rcx, [rel _cgxCoreState + CGXState.depthBuffer]
    test rcx, rcx
    jz .done

    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree

    mov qword [rel _cgxCoreState + CGXState.depthBuffer], 0

.done:
    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreDepthClear
; Fills depth buffer with 1.0f (farthest)
; --------------------------------------------
_cgxCoreDepthClear:
    push rbp
    mov rbp, rsp

    mov rdi, [rel _cgxCoreState + CGXState.depthBuffer]
    test rdi, rdi
    jz .done

    mov ecx, [rel _cgxCoreState + CGXState.width]
    imul ecx, [rel _cgxCoreState + CGXState.height]

    mov eax, 0x3F800000         ; 1.0f

.fillLoop:
    mov [rdi], eax
    add rdi, 4
    dec ecx
    jnz .fillLoop

.done:
    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreSetDepth
; Input: xmm0 = depth [0, 1]
; Stores as current draw depth
; --------------------------------------------
_cgxCoreSetDepth:
    movss [rel _cgxCoreState + CGXState.drawDepth], xmm0
    ret

; --------------------------------------------
; _cgxCoreDepthTest
; Input: ecx = x, edx = y, xmm0 = candidate depth
; Output: eax = 1 (pass) or 0 (fail)
; If pass, writes candidate into depth buffer
; --------------------------------------------
_cgxCoreDepthTest:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 32

    ; If depth test disabled, always pass
    cmp byte [rel _cgxCoreState + CGXState.depthTestEnabled], 0
    je .pass_no_write

    ; Bounds check
    cmp ecx, 0
    jl .fail
    cmp edx, 0
    jl .fail

    mov eax, [rel _cgxCoreState + CGXState.width]
    cmp ecx, eax
    jge .fail

    mov eax, [rel _cgxCoreState + CGXState.height]
    cmp edx, eax
    jge .fail

    ; Compute index = y * width + x
    mov eax, edx
    mov r8d, [rel _cgxCoreState + CGXState.width]
    imul eax, r8d
    add eax, ecx

    ; ptr = depthBuffer + index * 4
    mov rbx, [rel _cgxCoreState + CGXState.depthBuffer]
    shl eax, 2
    add rbx, rax

    ; Load current depth
    movss xmm1, [rbx]

    ; Dispatch on depthFunc
    mov eax, [rel _cgxCoreState + CGXState.depthFunc]

    cmp eax, CGX_LESS           ; CGX_LESS
    je .testLess
    cmp eax, CGX_LEQUAL         ; CGX_LEQUAL
    je .testLequal
    cmp eax, CGX_GREATER        ; CGX_GREATER
    je .testGreater
    cmp eax, CGX_GEQUAL         ; CGX_GEQUAL
    je .testGequal
    cmp eax, CGX_EQUAL          ; CGX_EQUAL
    je .testEqual
    cmp eax, CGX_NOTEQUAL       ; CGX_NOTEQUAL
    je .testNotEqual
    cmp eax, CGX_ALWAYS         ; CGX_ALWAYS
    je .pass_write
    cmp eax, CGX_NEVER          ; CGX_NEVER
    je .fail

    jmp .fail

;;;;;;;;;

;
; Less
;
.testLess:
    comiss xmm0, xmm1
    jb .pass_write
    jmp .fail

;
; Lequal
;
.testLequal:
    comiss xmm0, xmm1
    jbe .pass_write
    jmp .fail

;
; Greater
;
.testGreater:
    comiss xmm0, xmm1
    ja .pass_write
    jmp .fail

;
; Gequal
;
.testGequal:
    comiss xmm0, xmm1
    jae .pass_write
    jmp .fail

;
; Equal
;
.testEqual:
    comiss xmm0, xmm1
    je .pass_write
    jmp .fail

;
; Not Equal
;
testNotEqual:
    comiss xmm0, xmm1
    jne .pass_wite
    jmp .fail

;;;;;;;;;

.pass_write:
    movss [rbx], xmm0       ; update depth buffer
    mov eax, 1
    jmp .done
pass_no_write:
    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 32
    pop rbx
    pop rbp
    ret