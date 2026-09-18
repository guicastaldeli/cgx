; ============================================
; test_draw_elements.asm
; Draw triangle via CGXDrawElements
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
extern MessageBoxA

section .data
    title db "CGX Test - DrawElements", 0

    cR dd 0.05
    cG dd 0.05
    cB dd 0.1
    cA dd 1.0

    ; 3 vertices in NDC: (x, y, z) + (r, g, b) = 24 bytes each
    vertices:
        dd  0.0,  0.5, 0.0,   1.0, 0.0, 0.0
        dd -0.5, -0.5, 0.0,   0.0, 1.0, 0.0
        dd  0.5, -0.5, 0.0,   0.0, 0.0, 1.0
    vertices_size equ 72

    indices:
        dd 0, 1, 2
    indices_size equ 12

    msg_err_title db "DrawElements", 0
    msg_err db "DrawElements test FAILED", 0

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

    ; --- Create buffers ---
    ; Create VBO
    lea rcx, [rel vertices]
    mov rdx, vertices_size
    mov r8d, CGX_STATIC
    call CGXCreateVertexBuffer
    test eax, eax
    jz .error
    mov ebx, eax

    ; Create EBO
    lea rcx, [rel indices]
    mov rdx, indices_size
    mov r8d, CGS_STATIC
    call CGXCreateIndexBuffer
    test eax, eax
    jz .error
    mov r12d, eax

    ; Create VAO
    call CGXCreateVertexArray
    test eax, eax
    jz .error
    mov r13d, eax

    ; --- Bind buffers ---
    ; Bind VAO
    mov ecx, r13d
    call CGXBindVertexArray

    ; Bind VBO
    mov ecx, ebx
    call CGXBindVertexBuffer

    ; Bind EBO
    mov ecx, r12d
    call CGXBindIndexBuffer

    ; Attrib 0: position, 3 floats at offset 0, stride 24
    mov rcx, 0
    mov rdx, 3
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 24
    mov qword [rsp + 40], 0
    call CGXVertexAttribPointer

    ; Attrib 1: color, 3 floats at offset 12, stride 24
    mov rcx, 1
    mov rdx, 3
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 24
    mov qword [rsp + 40], 12
    call CGXVertexAttribPointer

    ; Enable both
    mov rcx, 0
    call CGXEnableVertexAttribArray
    mov rcx, 1
    call CGXEnableVertexAttribArray

.loop:
    call CGXPoolEvents
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
    mov ecx, 0x00004000
    call CGXClear

    ; Bind VAO and draw
    mov ecx, r13d
    call CGXBindVertexArray

    mov rcx, CGX_TRIANGLES
    mov rdx, 3
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
        