; ============================================
; test_vao.asm
; Verify VAO creation, binding, and attribute setup
; ============================================

default rel

%include "constants.inc"

global main

extern CGXInit
extern CGXShutdown
extern CGXCreateVertexBuffer
extern CGXCreateIndexBuffer
extern CGXBindVertexBuffer
extern CGXBindIndexBuffer
extern CGXCreateVertexArray
extern CGXBindVertexArray
extern CGXVertexAttribPointer
extern CGXEnableVertexAttribArray
extern CGXDeleteVertexArray
extern CGXDeleteBuffer
extern MessageBoxA

section .data
    title db "CGX Test - VAO", 0

    ; 3 vertices, each: xyz (3 floats) + rgb (3 floats) = 24 bytes
    vertices:
        dd 0.0, 0.5, 0.0,   1.0, 0.0, 0.0
        dd -0.5, -0.5, 0.0, 0.0, 1.0, 0.0
        dd 0.5, -0.5, 0.0,  0.0, 0.0, 1.0
    vertices_size equ 72

    indices:
        dd 0, 1, 2
    indices_size equ 12

    msg_ok_title db "VAO Test", 0
    msg_ok db "VAO test passed", 0
    msg_err_title db "VAO Test - ERR", 0
    msg_err db "VAO test FAILED", 0

section .text

main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 40

    ; Init
    mov rcx, 800
    mov rdx, 600
    lea r8, [rel title]
    call CGXInit
    cmp eax, 0
    je .error

    ; Create VBO
    lea rcx, [rel vertices]
    mov rdx, vertices_size
    mov r8d, CGX_STATIC
    call CGXCreateVertexBuffer
    test eax, eax
    jz .error
    mov ebx, eax                        ; vbo id

    ; -- Create Buffers ---
    ; Create EBO
    lea rcx, [rel indices]
    mov rdx, indices_size
    mov r8d, CGX_STATIC
    call CGXCreateIndexBuffer
    test eax, eax
    jz .error
    mov r12d, eax                       ; ebo id

    ; Create VAO
    call CGXCreateVertexArray
    test eax, eax
    jz .error
    mov r13d, eax                       ; vao id

    ; --- Bind Buffers ---
    ; Bind VAO
    mov ecx, r13d
    call CGXBindVertexArray
    cmp eax, 1
    jne .error

    ; Bind VBO
    mov ecx, ebx
    call CGXBindVertexBuffer
    cmp eax, 1
    jne .error

    ; Bind EBO
    mov ecx, r12d
    call CGXBindIndexBuffer
    cmp eax, 1
    jne .error

    ; Attribute 0: position (3 floats, offset 0, stride 24)
    mov rcx, 0
    mov rdx, 3
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 24            ; stride
    mov qword [rsp + 40], 0             ; offset
    call CGXVertexAttribPointer

    ; Attribute 1: color (3 floats, offset 12, stride 24)
    mov rcx, 1
    mov rdx, 3
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 24
    mov qword [rsp + 40], 12
    call CGXVertexAttribPointer

    ; Enable attributes
    mov rcx, 0
    call CGXEnableVertexAttribArray
    cmp eax, 1
    jne .error

    mov rcx, 1
    call CGXEnableVertexAttribArray
    cmp eax, 1
    jne .error

    ; Success
    xor rcx, rcx
    lea rdx, [rel msg_ok]
    lea r8, [rel msg_ok_title]
    mov r9d, 0
    call MessageBoxA

    ; Cleanup
    mov ecx, r13d
    call CGXDeleteVertexArray

    mov ecx, ebx
    call CGXDeleteBuffer

    mov ecx, r12d
    call CGXDeleteBuffer

    call CGXShutdown
    xor eax, eax
    jmp .done

.error:
    xor rcx, rcx
    lea rdx, [rel msg_err]
    lea r8, [rel msg_err_title]
    mov r9d, 0
    call MessageBoxA
    mov eax, 1

.done:
    add rsp, 40
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret