; ============================================
; test_clear.asm - Verify window + clear
; ============================================

default rel

global main

extern CGXInit
extern CGXShutdown
extern CGXPollEvents
extern CGXShouldClose
extern CGXSetClearColor
extern CGXClear
extern CGXSwapBuffers

section .data
    title db "CGX Test - Clear", 0
    cR dd 0.2
    cG dd 0.2
    cB dd 0.4
    cA dd 1.0

section .text

main:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; Init: width, height, title
    mov rcx, 800
    mov rdx, 600
    lea r8, [rel title]
    call CGXInit
    cmp eax, 0
    je .error

    ; Set clear color
    movss xmm0, [rel cR]
    movss xmm1, [rel cG]
    movss xmm2, [rel cB]
    movss xmm3, [rel cA]
    call CGXSetClearColor

.loop:
    call CGXPollEvents
    call CGXShouldClose
    cmp eax, 1
    je .done

    mov ecx, 0x00004000     ; CGX_COLOR_BIT
    call CGXClear

    call CGXSwapBuffers
    jmp .loop

.done:
    call CGXShutdown
    xor eax, eax
    mov rsp, rbp
    pop rbp
    ret

error:
    mov eax, 1
    mov rsp, rbp
    pop rbp
    ret