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

    dbg_1 db "1. main entered", 0
    dbg_2 db "2. CGXInit returned", 0
    dbg_3 db "3. VBO created", 0
    dbg_4 db "4. EBO created", 0
    dbg_5 db "5. VAO created", 0
    dbg_6 db "6. VAO bound", 0
    dbg_7 db "7. VBO/EBO bound to VAO", 0
    dbg_8 db "8. attrib pointer set", 0
    dbg_9 db "9. attrib enabled", 0

section .text

main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 40

    ; DEBUG 1
    xor rcx, rcx
    lea rdx, [rel dbg_1]
    lea r8, [rel msg_ok_title]
    mov r9d, 0
    call MessageBoxA

    ; Init
    mov rcx, 800
    mov rdx, 600
    lea r8, [rel title]
    call CGXInit
    cmp eax, 0
    je .error

    ; DEBUG 2
    xor rcx, rcx
    lea rdx, [rel dbg_2]
    lea r8, [rel msg_ok_title]
    mov r9d, 0
    call MessageBoxA

    ; Create VBO
    lea rcx, [rel vertices]
    mov rdx, vertices_size
    mov r8d, CGX_STATIC
    call CGXCreateVertexBuffer
    test eax, eax
    jz .error
    mov ebx, eax

    ; DEBUG 3
    xor rcx, rcx
    lea rdx, [rel dbg_3]
    lea r8, [rel msg_ok_title]
    mov r9d, 0
    call MessageBoxA

    ; Create EBO
    lea rcx, [rel indices]
    mov rdx, indices_size
    mov r8d, CGX_STATIC
    call CGXCreateIndexBuffer
    test eax, eax
    jz .error
    mov r12d, eax

    ; DEBUG 4
    xor rcx, rcx
    lea rdx, [rel dbg_4]
    lea r8, [rel msg_ok_title]
    mov r9d, 0
    call MessageBoxA

    ; Create VAO
    call CGXCreateVertexArray
    test eax, eax
    jz .error
    mov r13d, eax

    ; DEBUG 5
    xor rcx, rcx
    lea rdx, [rel dbg_5]
    lea r8, [rel msg_ok_title]
    mov r9d, 0
    call MessageBoxA

    ; Bind VAO
    mov ecx, r13d
    call CGXBindVertexArray
    cmp eax, 1
    jne .error

    ; DEBUG 6
    xor rcx, rcx
    lea rdx, [rel dbg_6]
    lea r8, [rel msg_ok_title]
    mov r9d, 0
    call MessageBoxA

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

    ; DEBUG 7
    xor rcx, rcx
    lea rdx, [rel dbg_7]
    lea r8, [rel msg_ok_title]
    mov r9d, 0
    call MessageBoxA

    ; Attribute 0: position
    mov rcx, 0
    mov rdx, 3
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 24
    mov qword [rsp + 40], 0
    call CGXVertexAttribPointer

    ; DEBUG 8
    xor rcx, rcx
    lea rdx, [rel dbg_8]
    lea r8, [rel msg_ok_title]
    mov r9d, 0
    call MessageBoxA

    ; Attribute 1: color
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

    ; DEBUG 9
    xor rcx, rcx
    lea rdx, [rel dbg_9]
    lea r8, [rel msg_ok_title]
    mov r9d, 0
    call MessageBoxA

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