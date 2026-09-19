; ============================================
; test_rotating_triangle.asm
; Triangle rotating around Z axis
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
extern CGXGetTimeDelta
extern CGXCreateVertexBuffer
extern CGXCreateIndexBuffer
extern CGXBindVertexBuffer
extern CGXBindIndexBuffer
extern CGXCreateVertexArray
extern CGXBindVertexArray
extern CGXVertexAttribPointer
extern CGXEnableVertexAttribArray
extern CGXDrawElements
extern CGXEnable
extern CGXMatrixMode
extern CGXLoadIdentity
extern CGXRotate
extern CGXOrtho
extern MessageBoxA

section .data
    title db "CGX Test - Rotating Triangle", 0

    cR dd 0.05
    cG dd 0.05
    cB dd 0.1
    cA dd 1.0

    vertices:
        dd  0.0,  0.5, 0.0,   1.0, 0.0, 0.0
        dd -0.5, -0.5, 0.0,   0.0, 1.0, 0.0
        dd  0.5, -0.5, 0.0,   0.0, 0.0, 1.0
    vertices_size equ 72

    indices:
        dd 0, 1, 2
    indices_size equ 12

    ; Ortho bounds
    ortho_l dd -1.0
    ortho_r dd 1.0
    ortho_b dd -1.0
    ortho_t dd 1.0
    ortho_n dd -1.0
    ortho_f dd 1.0

    ; Rotation axis
    axis_x dd 0.0
    axis_y dd 0.0
    axis_z dd 1.0

    msg_err_title db "Rotating Triangle", 0
    msg_err db "Test FAILED", 0

section .bss
    angle         resd 1

section .text

main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 48

    mov rcx, 800
    mov rdx, 600
    lea r8, [rel title]
    call CGXInit
    cmp eax, 0
    je .error

    movss xmm0, [rel cR]
    movss xmm1, [rel cG]
    movss xmm2, [rel cB]
    movss xmm3, [rel cA]
    call CGXSetClearColor

    ; Enable depth test
    mov rcx, CGX_DEPTH_TEST
    call CGXEnable

    ; --- Create buffers ---
    lea rcx, [rel vertices]
    mov rdx, vertices_size
    mov r8d, CGX_STATIC
    call CGXCreateVertexBuffer
    test eax, eax
    jz .error
    mov ebx, eax

    lea rcx, [rel indices]
    mov rdx, indices_size
    mov r8d, CGX_STATIC
    call CGXCreateIndexBuffer
    test eax, eax
    jz .error
    mov r12d, eax

    call CGXCreateVertexArray
    test eax, eax
    jz .error
    mov r13d, eax

    ; --- Bind buffers ---
    mov ecx, r13d
    call CGXBindVertexArray

    mov ecx, ebx
    call CGXBindVertexBuffer

    mov ecx, r12d
    call CGXBindIndexBuffer

    ; Attrib 0: position
    mov rcx, 0
    mov rdx, 3
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 24
    mov qword [rsp + 40], 0
    call CGXVertexAttribPointer

    ; Attrib 1: color
    mov rcx, 1
    mov rdx, 3
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 24
    mov qword [rsp + 40], 12
    call CGXVertexAttribPointer

    mov rcx, 0
    call CGXEnableVertexAttribArray
    mov rcx, 1
    call CGXEnableVertexAttribArray

    ; Setup projeciton
    mov rcx, CGX_PROJECTION
    call CGXMatrixMode
    call CGXLoadIdentity

    ; CGXOrtho(l, r, b, t, b, f)
    movss xmm0, [rel ortho_l]
    movss xmm1, [rel ortho_r]
    movss xmm2, [rel ortho_b]
    movss xmm3, [rel ortho_t]
    movss xmm4, [rel ortho_n]
    movss xmm5, [rel ortho_f]
    movss [rsp + 32], xmm4
    movss [rsp + 40], xmm5
    call CGXOrtho

    ; Init angle
    mov dword [rel angle], 0

.loop:
    call CGXPollEvents
    call CGXShouldClose
    cmp eax, 1
    je .done

    ; ESC to exit
    mov rcx, CGX_KEY_ESC
    call CGXGetKey
    cmp ax, 1
    jne .render
    jmp .done

.render:
    mov ecx, CGX_COLOR_BIT | CGX_DEPTH_BIT
    call CGXClear

    ; Setup modelview
    mov rcx, CGX_MODELVIEW
    call CGXMatrixMode
    call CGXLoadIdentity

    movss xmm0, [rel angle]
    movss xmm1, [rel axis_x]
    movss xmm2, [rel axis_y]
    movss xmm3, [rel axis_z]
    call CGXRotate

    ; Draw
    mov ecx, r13d
    call CGXBindVertexArray

    mov rcx, CGX_TRIANGLES
    mov rdx, 3
    mov r8d, CGX_UINT
    xor r9d, r9d
    call CGXDrawElements

    call CGXSwapBuffers

    ; angle += 1
    movss xmm0, [rel angle]
    mov eax, 0x3F800000
    movd xmm1, eax
    addss xmm0, xmm1
    movss [rel angle], xmm0

    jmp .loop

.done:
    call CGXShutdown
    xor eax, eax
    jmp .finish

.error:
    xor rcx, rcx
    lea rdx, [rel msg_err]
    lea r8, [rel msg_err_title]
    mov r9d, 0
    call MessageBoxA
    mov eax, 1

.finish:
    add rsp, 48
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret