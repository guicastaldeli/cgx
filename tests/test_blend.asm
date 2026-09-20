; ============================================
; test_blend.asm
; Two overlapping triangles with alpha blending
; ============================================

default rel

global main

%include "constants.inc"

extern CGXInit
extern CGXShutdown
extern CGXPollEvents
extern CGXShouldClose
extern CGXSetClearColor
extern CGXClear
extern CGXSwapBuffers
extern CGXGetKey
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
extern CGXDepthFunc
extern CGXBlendFunc
extern MessageBoxA

section .data
    title db "CGX Test - Blend", 0

    cR dd 0.1
    cG dd 0.1
    cB dd 0.1
    cA dd 1.0

    ; 6 vertices: two triangles, RGBA (28 bytes each)
    ; Red triangle at z=0 (opaque)
    ; Blue triangle at z=-0.5 (50% alpha, in front)
    vertices:
        ; Red triangle (back)
        dd -0.6,  0.6,  0.0,   1.0, 0.0, 0.0, 1.0
        dd -0.6, -0.6,  0.0,   1.0, 0.0, 0.0, 1.0
        dd  0.6, -0.6,  0.0,   1.0, 0.0, 0.0, 1.0
        ; Blue triangle (front)
        dd  0.0,  0.6, -0.5,   0.0, 0.0, 1.0, 0.2
        dd  0.0, -0.6, -0.5,   0.0, 0.0, 1.0, 0.2
        dd  1.2, -0.6, -0.5,   0.0, 0.0, 1.0, 0.2
    vertices_size equ 6 * 28

    indices:
        dd 0, 1, 2, 3, 4, 5
    indices_size equ 6 * 4

    ; Ortho projection
    ortho_l dd -1.0
    ortho_r dd  1.0
    ortho_b dd -1.0
    ortho_t dd  1.0
    ortho_n dd -1.0
    ortho_f dd  1.0

    msg_err_title db "Blend Test", 0
    msg_err db "Blend test FAILED", 0

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

    ; Clear color
    movss xmm0, [rel cR]
    movss xmm1, [rel cG]
    movss xmm2, [rel cB]
    movss xmm3, [rel cA]
    call CGXSetClearColor

    ; Depth test on, but LESS means smaller Z wins
    mov rcx, CGX_DEPTH_TEST
    call CGXEnable

    ; Enable blending with src-alpha / one-minus-src-alpha
    mov rcx, CGX_BLEND
    call CGXEnable

    mov rcx, CGX_SRC_ALPHA
    mov rdx, CGX_ONE_MINUS_SRC_ALPHA
    call CGXBlendFunc

    ; --- Create buffers ---
    ; VBO
    lea rcx, [rel vertices]
    mov rdx, vertices_size
    mov r8d, CGX_STATIC
    call CGXCreateVertexBuffer
    test eax, eax
    jz .error
    mov ebx, eax

    ; EBO
    lea rcx, [rel indices]
    mov rdx, indices_size
    mov r8d, CGX_STATIC
    call CGXCreateIndexBuffer
    test eax, eax
    jz .error
    mov r12d, eax

    ; VAO
    call CGXCreateVertexArray
    test eax, eax
    jz .error
    mov r13d, eax

    ; --- Bind buffers ---
    ; VAO
    mov ecx, r13d
    call CGXBindVertexArray

    ; EBO
    mov ecx, ebx
    call CGXBindVertexBuffer

    ; VBO
    mov ecx, r12d
    call CGXBindIndexBuffer

    ; Attrib 0: position (3 floats, offset 0, stride 28)
    mov rcx, 0
    mov rdx, 3
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 28
    mov qword [rsp + 40], 0
    call CGXVertexAttribPointer

    ; Attrib 1: color (4 floats, offset 12, stride 28)
    mov rcx, 1
    mov rdx, 4
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 28
    mov qword [rsp + 40], 12
    call CGXVertexAttribPointer

    mov rcx, 0
    call CGXEnableVertexAttribArray
    mov rcx, 1
    call CGXEnableVertexAttribArray

.loop:
    call CGXPollEvents
    call CGXShouldClose
    cmp eax, 1
    je .done

    ; ESC to exit
    mov rcx, CGX_KEY_ESC
    call CGXGetKey
    cmp eax, 1
    jne .render
    jmp .done

.render:
    mov ecx, CGX_COLOR_BIT | CGX_DEPTH_BIT
    call CGXClear

    mov ecx, r13d
    call CGXBindVertexArray

    mov rcx, CGX_TRIANGLES
    mov rdx, 6
    mov r8d, CGX_UINT
    xor r9d, r9d
    call CGXDrawElements

    call CGXSwapBuffers
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