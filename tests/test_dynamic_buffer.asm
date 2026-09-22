; ============================================
; test_dynamic_buffer.asm
; Demonstrate CGXBufferSubData by writing new
; vertex data into a VBO every frame.
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
extern CGXBufferSubData
extern MessageBoxA

section .data
    title db "CGX Test - Dynamic Buffer", 0

    cR dd 0.5
    cG dd 0.05
    cB dd 0.1
    cA dd 1.0

    ; 4 vertices, 9 floats each, 36 bytes per vertex
    ; pos(3) + rgba(4) + uv(2)
    vertices:
        dd -0.6, -0.6, 0.0,  1.0, 0.0, 0.0, 1.0,   0.0, 0.0
        dd  0.6, -0.6, 0.0,  0.0, 1.0, 0.0, 1.0,   1.0, 0.0
        dd  0.6,  0.6, 0.0,  0.0, 0.0, 1.0, 1.0,   1.0, 1.0
        dd -0.6,  0.6, 0.0,  1.0, 1.0, 0.0, 1.0,   0.0, 1.0
    vertices_size equ 4 * 36

    indices:
        dd 0, 1, 2,   2, 3, 0
    indices_size equ 6 * 4

    msg_err_title db "Dynamic Buffer Test", 0
    msg_err db "Test FAILED", 0

section .bss
    frame       resd 1

section .text

main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 96

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

    ; Create a dynamic VBO with NULL data
    xor rcx, rcx            ; NULL data
    mov rdx, vertices_size
    mov r8d, CGX_DYNAMIC
    call CGXCreateVertexBuffer
    test eax, eax
    jz .error
    mov ebx, eax

    ; EBO (static)
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

    ; Bind
    mov ecx, r13d
    call CGXBindVertexArray
    mov ecx, ebx
    call CGXBindVertexBuffer
    mov ecx, r12d
    call CGXBindIndexBuffer

    ; Attribs: pos (3), color (4), uv (2)
    mov rcx, 0
    mov rdx, 3
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 36
    mov qword [rsp + 40], 0
    call CGXVertexAttribPointer

    mov rcx, 1
    mov rdx, 4
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 36
    mov qword [rsp + 40], 12
    call CGXVertexAttribPointer

    mov rcx, 2
    mov rdx, 2
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 36
    mov qword [rsp + 40], 28
    call CGXVertexAttribPointer

    mov rcx, 0
    call CGXEnableVertexAttribArray
    mov rcx, 1
    call CGXEnableVertexAttribArray
    mov rcx, 2
    call CGXEnableVertexAttribArray

    ; Frame counter
    mov dword [rel frame], 0

.loop:
    call CGXPollEvents
    call CGXShouldClose
    cmp eax, 1
    je .done

    jne .render
    jmp .done

.render:
    mov ecx, CGX_COLOR_BIT | CGX_DEPTH_BIT
    call CGXClear

    ; Every frame: write new vertex data
    mov eax, [rel frame]
    and eax, 0xFF
    cvtsi2ss xmm0, eax
    mov eax, 0x437F0000                 ; 255.0f
    movd xmm1, eax
    divss xmm0, xmm1                    ; t = 0.0 .. 1.0

    ; red = t
    movss [rel vertices + 12], xmm0

    ; green = 1 - t
    mov eax, 0x3F800000
    movd xmm1, eax
    subss xmm1, xmm0
    movss [rel vertices + 16], xmm1

    ; blue = t * 0.5 + 0.5
    mov eax, 0x3F000000                 ; 0.5
    movd xmm1, eax
    mulss xmm0, xmm1
    addss xmm0, xmm1
    movss [rel vertices + 20], xmm0

    ; Upload via SubData
    mov rcx, CGX_BUFFER_VERTEX
    xor rdx, rdx                        ; offset 0
    mov r8d, vertices_size
    lea r9, [rel vertices]
    call CGXBufferSubData

    ; Draw
    mov ecx, r13d
    call CGXBindVertexArray

    mov rcx, CGX_TRIANGLES
    mov rdx, 6
    mov r8d, CGX_UINT
    xor r9d, r9d
    call CGXDrawElements

    call CGXSwapBuffers

    inc dword [rel frame]
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
    add rsp, 96
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
