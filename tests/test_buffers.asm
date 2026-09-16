; ============================================
; test_buffers.asm
; Create/bind/delete VBO and EBO
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
extern CGXDeleteBuffer
extern MessageBoxA

section .data
    title db "CGX Test - Buffers", 0

    ; 2D triangle: 3 vertices each (x, y, z, r, g, b) = 24 bytes
    vertices:
        dd 0.0, 0.5, 0.0,   1.0, 0.0, 0.0
        dd -0.5, -0.5, 0.0, 0.0, 1.0, 0.0
        dd 0.5, -0.5, 0.0,  0.0, 0.0, 1.0
    vertices_size equ 72        ; 3 * 24

    ; 3 indices
    indices:
        dd 0, 1, 2
    indices_size equ 12

    msg_ok_title db "Buffers", 0
    msg_ok db "Buffer test passed", 0
    msg_err_title db "Buffers *err", 0
    msg_err db "Buffer test FAILED", 0

    ; --- Debug messages ---
    dbg_1 db "1. main entered", 0
    dbg_2 db "2. CGXInit returned OK", 0
    dbg_3 db "3. VBO created", 0
    dbg_4 db "4. EBO created", 0
    dbg_5 db "5. buffers bound", 0
    dbg_6 db "6. about to shutdown", 0

section .text

main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 40

    xor rcx, rcx
    lea rdx, [dbg_1]
    lea r8, [rel msg_ok_title]
    mov r9d, 0
    call MessageBoxA

    ; --- Init window + graphics ---
    mov rcx, 800
    mov rdx, 600
    lea r8, [rel title]
    call CGXInit
    cmp eax, 0
    je .error

    xor rcx, rcx
    lea rdx, [rel dbg_2]
    lea r8, [rel msg_ok_title]
    mov r9d, 0
    call MessageBoxA

    ; --- Create Buffers ---
    ; Create VBO
    lea rcx, [rel vertices]
    mov rdx, vertices_size
    mov r8d, CGX_STATIC
    call CGXCreateVertexBuffer
    test eax, eax
    jz .error
    mov ebx, eax

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

    xor rcx, rcx
    lea rdx, [rel dbg_4]
    lea r8, [rel msg_ok_title]
    mov r9d, 0
    call MessageBoxA

    ; --- Bind Buffers ---
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

    xor rcx, rcx
    lea rdx, [rel dbg_5]
    lea r8, [rel msg_ok_title]
    mov r9d, 0
    call MessageBoxA

    ; --- Delete ---
    mov ecx, ebx
    call CGXDeleteBuffer

    mov ecx, r12d
    call CGXDeleteBuffer

    xor rcx, rcx
    lea rdx, [rel dbg_6]
    lea r8, [rel msg_ok_title]
    mov r9d, 0
    call MessageBoxA

    ; --- Success message ---
    xor rcx, rcx
    lea rdx, [rel msg_ok]
    lea r8, [rel msg_ok_title]
    mov r9d, 0
    call MessageBoxA

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
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret