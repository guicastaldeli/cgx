; ============================================
; test_depth.asm
; Two overlapping triangles, depth-tested
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
extern MessageBoxA

section .data
    title db "CGX Test - Depth", 0

    cR dd 0.05
    cG dd 0.05
    cB dd 0.1
    cA dd 1.0

    ; 6 vertices: two triangles at different Z
    ; Triangle 1 (z = -0.5, closer): red/green/blue
    ; Triangle 2 (z = 0.5, farther): cyan/magenta/yellow
    vertices:
        ; Triangle 1 (closer)
        dd -0.8,  0.8, -0.5,   1.0, 0.0, 0.0
        dd -0.8, -0.8, -0.5,   0.0, 1.0, 0.0
        dd  0.8, -0.8, -0.5,   0.0, 0.0, 1.0

        ; Triangle 2 (farther, offset so it overlaps)
        dd  0.0,  0.8,  0.5,   0.0, 1.0, 1.0
        dd  0.0, -0.8,  0.5,   1.0, 0.0, 1.0
        dd  1.6, -0.8,  0.5,   1.0, 1.0, 0.0
    vertices_size equ 144

    indices:
        dd 0, 1, 2, 3, 4, 5
    indices_size equ 24

    msg_err_title db "Depth Test", 0
    msg_err db "Depth test FAILED", 0

section .text

main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 48

    ; Init
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

    ; Enable depth test
    mov rcx, CGX_DEPTH_TEST
    call CGXEnable

    mov rcx, CGX_LESS
    call CGXDepthFunc

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

    ; Bind buffers
    ; VAO
    mov ecx, r13d
    call CGXBindVertexArray

    ; VBO
    mov ecx, ebx
    call CGXBindVertexBuffer

    ; EBO
    mov ecx, r12d
    call CGXBindIndexBuffer

    ; Attrib 0: position (3 floats, offset 0)
    mov rcx, 0
    mov rdx, 3
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 24
    mov qword [rsp + 40], 0
    call CGXVertexAttribPointer

    ; Attrib 1: color (3 floats, offset 12)
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
    ; Clear color + depth
    mov ecx, CGX_COLOR_BIT | CGX_DEPTH_BIT
    call CGXClear

    ; Bind and draw
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