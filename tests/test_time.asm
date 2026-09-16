; ============================================
; test_time.asm - FPS counter in window title
; ============================================

default rel

%include "constants.inc"

extern CGXInit
extern CGXShutdown
extern CGXPollEvents
extern CGXShouldClose
extern CGXSetClearColor
extern CGXClear
extern CGXSwapBuffers
extern CGXGetKey
extern CGXSetWindowTitle
extern CGXGetTime
extern CGXGetTimeDelta

section .data
    title db "CGX Test - Time", 0
    title_buf db "FPS=000 Frame=0000000000", 0

    cR dd 0.1
    cG dd 0.1
    cB dd 0.2
    cA dd 1.0

    ; 1.0 as double
    one_double dq 1.0

section .bss
    frames              resd 1
    fpsTime             resd 1
    currentFps          resd 1

section .text

; --------------------------------------------
; write3digits
; Input: eax = value (0-999), rdi = destination
; --------------------------------------------
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
    mov al, '0'
    mov [rdi], al
    inc rdi

    mov eax, edx
    add al, '0'
    mov [rdi], al

    pop rbx
    ret

; --------------------------------------------
; write10digits
; Input: rax = value (0 - 9999999999), rdi = destination
; Writes 10 ASCII digits (right to left)
; --------------------------------------------
write10digits:
    push rbx
    mov rcx, 10
.loop10:
    xor edx, edx
    mov rbx, 10
    div rbx
    add dl, '0'
    dec rcx
    mov [rdi + rcx], dl
    test rcx, rcx
    jnz .loop10
    pop rbx
    ret

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

    ; Set clear color
    movss xmm0, [rel cR]
    movss xmm1, [rel cG]
    movss xmm2, [rel cB]
    movss xmm3, [rel cA]
    call CGXSetClearColor

    ; Init counters
    mov dword [rel frames], 0
    call CGXGetTime
    cvttsd2si rax, xmm0
    mov [rel fpsTimer], rax

.loop:
    call CGXPollEvents
    call CGXShouldClose
    cmp eax, 1
    je .done

    ; ESC to close...
    mov rcx, CGX_KEY_ESC
    call CGXGetKey
    cmp eax, 1
    jne .render
    jmp .done

.render:
    ; Count frame
    inc dword [rel frames]

    ; Check if 1 sec passed...
    call CGXGetTime
    cvttsd2si rax, xmm0
    mov rcx, [rel fpsTimer]
    sub rax, rcx
    cmp rax, 1
    jl .draw

    ; 1 sec elapsed - record FPS...
    mov eax, [rel frames]
    mov [rel currentFps], eax
    mov dword [rel frames], 0

    ; Reset fpsTimer
    call CGXGetTime
    cvttsd2si rax, xmm0
    mov [rel fpsTimer], rax

.draw
    ; Update title: "FPS=### Frame=##########"
    mov eax, [rel currentFps]
    lea rdi, [rel title_buf + 4]
    call write3digits

    ; Frame count (10 digits) - placeholder
    mov rax, [rel frames]
    lea rdi, [rel title_buf + 16]
    call write10digits

    lea rcx, [rel title_buf]
    call CGXSetWindowTitle

    ; Clear + present
    mov eax, 0x000040000
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

