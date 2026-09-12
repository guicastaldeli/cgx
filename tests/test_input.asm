; ============================================
; test_input.asm - Verify key and mouse input
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
extern CGXGetMouseX
extern CGXGetMouseY
extern CGXGetMouseButton
extern CGXSetWindowTitle
extern MessageBoxA

section .data
    title db "CGX Test - Input", 0
    title_buf db "CGX Input - Input / X=000 Y=000", 0
    cR dd 0.1
    cG dd 0.1
    cB dd 0.1
    cA dd 1.0

    msg_esc_title db "Input Test", 0
    msg_esc db "ESC pressed, closing...", 0
    msg_click_title db "Input Test", 0
    msg_click db "Mouse button pressed", 0

section .text

main:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; Init window + graphics
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

    ; --- Check Esc ---
    mov rcx, CGX_KEY_ESC
    call CGXGetKey
    cmp eax, 1
    jne .check_click

    ; ESC pressed -> close
    xor rcx, rcx
    lea rdx, [rel msg_esc]
    lea r8, [rel msg_esc_title]
    mov r9d, 0
    call MessageBoxA
    jmp .done

.check_click:
    ; --- Check left mouse button ---
    xor ecx, ecx    ; button 0 = left
    call CGXGetMouseButton
    cmp eax, 1
    jne .render

    xor rcx, rcx
    lea rdx, [rel msg_click]
    lea r8, [rel msg_click_title]
    mov r9d, 0
    call MessageBoxA

.render:
    ; Get mouse X
    call CGXGetMouseX
    lea rdi, [rel title_buf + 22]
    call write3digits

    ; Get mouse Y
    call CGXGetMouseY
    lea rdi, [rel title_buf + 28]
    call write3digits

    ; Update window title
    lea rcx, [rel title_buf]
    call CGXSetWindowTitle

    mov ecx, 0x00004000
    call CGXClear
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

; Helper: convert eax (0-999) to 3 ASCII digits at [rdi]
; Input: eax = value, rdi = destination
write3digits:
    push rbx
    mov ebx, 100
    xor edx, edx
    div ebx
    add al, '0'
    mov [rdi], al
    inc rdi

    mov eax, edx
    mov ebx, 10
    xor edx, edx
    div ebx
    add al, '0'
    mov [rdi], al
    inc rdi

    mov eax, edx
    add al, '0'
    mov [rdi], al

    pop rbx
    ret