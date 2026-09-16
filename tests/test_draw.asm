; ============================================
; test_draw.asm
; Classic wireframe triangle with per-vertex color
; ============================================

default rel

%include "constants.inc"

global main

extern CGXInit
extern CGXShutdown
extern CGXPollEvents
extern CGXShouldClose
extern CGXSetClearColor
extern CGXClear
extern CGXSwapBuffers
extern CGXGetKey
extern CGXSetColor
extern CGXDrawPixel
extern CGXDrawLine

section .data
    title db "CGX Test - Draw", 0

    cR dd 0.1
    cG dd 0.1
    cB dd 0.1
    cA dd 1.0

section .text

main:
    push rbp
    mov rbp, rsp
    sub rsp, 48

    ; Init window + graphics
    mov rcx, 800
    mov rdx, 600
    lea r8, [rel title]
    call CGXInit
    cmp eax, 0
    je .error

    ; Clear color
    movss xmm0, [rel cR]
    movss xmm1, [rel cG]
    movss xmm2, [rel cB]
    movss xmm3, [rel cA]
    call CGXSetClearColor

.loop:
    call CGXPollEvents
    call CGXShouldClose
    cmp eax, 1
    .je .done

    ; ESC to close
    mov rcx, CGX_KEY_ESC
    call CGXGetKey
    cmp eax, 1
    jne .render
    jmp .done

.render:
    ; Clear screen
    mov ecx, 0x00004000
    call CGXClear

    ; --- Draw triangle edges
    /*
        Vertices in pixels (with margin):
            A = (400, 100)
            B = (150, 500)
            C = (650, 500)

        Colors:
            A -> red (0x00FF0000)
            B -> green (0x0000FF00)
            C -> blue (0x000000FF)
        */

    ; Edge A->B: red
    mov ecx, 0x00FF0000
    mov rcx, 400
    mov rdx, 100
    mov r8, 150
    mov r9, 500
    call CGXDrawLine

    ; Edge B->C: green
    mov ecx, 0x0000FF00
    call CGXSetColor
    mov rcx, 150
    mov rdx, 500
    mov r8, 650
    mov r9, 500
    call CGXDrawLine

    ; Edge C->A: blue
    mov ecx, 0x000000FF
    mov rcx, 650
    mov rdx, 500
    mov r8, 400
    mov r9, 100
    call CGXDrawLine

    call CGXSwapBuffers
    jmp .loop

.done:
    call CGXShutdown
    xor eax, eax
    mov rsp, rbp
    pop rbp
    ret

.error:
    mov eax, 1
    mov rsp, rbp
    pop rbp
    ret