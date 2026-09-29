; ============================================
; test_shader_pipeline.asm
; End-to-end shader pipeline test.
;
; Vertex shader: positions a triangle in NDC.
; Fragment shader: colors.
;
; If this renders a solid triangle, the whole
; programmable pipeline works: lexer, parser,
; analyzer, compiler, VM, vertex path, varying
; interpolation, fragment path, framebuffer.
; ============================================

default rel

global main

%include "constants.inc"
%include "structs.inc"
%include "shader.inc"

extern CGXInit
extern CGXShutdown
extern CGXPollEvents
extern CGXShouldClose
extern CGXSetClearColor
extern CGXClear
extern CGXSwapBuffers
extern CGXGetKey
extern MessageBoxA
extern CGXCreateShader
extern CGXShaderSource
extern CGXCompileShader
extern CGXCreateProgram
extern CGXAttachShader
extern CGXLinkProgram
extern CGXUseProgram
extern CGXBindAttribLocation
extern CGXCreateVertexBuffer
extern CGXCreateIndexBuffer
extern CGXBindVertexBuffer
extern CGXBindIndexBuffer
extern CGXCreateVertexArray
extern CGXBindVertexArray
extern CGXVertexAttribPointer
extern CGXEnableVertexAttribArray
extern CGXDrawElements

section .data
    title db "CGX Test - Shader Pipeline", 0

    cR dd 0.05
    cG dd 0.05
    cB dd 0.1
    cA dd 1.0

    ; ---- Vertex shader ----
    vsSrc:
        db "attribute vec3 aPos;", 10
        db "void main() {", 10
        db "    gl_Position = vec4(aPos, 1.0);", 10
        db "}", 10
        db 0
    vsSrcLen equ $ - vsSrc - 1

    ; ---- Fragment shader ----
    fsSrc:
        db "void main() {", 10
        db "    gl_FragColor = vec4(0.5, 0.5, 0.5, 1.0);", 10
        db "}", 10
        db 0
    fsSrcLen equ $ - fsSrc - 1

    aPosName    db "aPos", 0

    ; 3 vertices, each (x, y, z), stride 12.
    ; Triangle centered on the origin.
    vertices:
        dd  0.0,  0.7, 0.0
        dd -0.7, -0.5, 0.0
        dd  0.7, -0.5, 0.0
    vertices_size equ 3 * 12

    indices:
        dd 0, 1, 2
    indices_size equ 3 * 4

    msg_d0      db "Test - init OK", 0
    msg_d1      db "Test - shaders compiled", 0
    msg_d2      db "Test - program linked", 0
    msg_fail    db "Test FAILED", 0

section .bss
    vsId        resd 1
    fsId        resd 1
    progId      resd 1

section .text

_box:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    xor rcx, rcx
    lea r8, [rel title]
    xor r9d, r9d
    call MessageBoxA

    add rsp, 32
    pop rbp
    ret

main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 72

    mov rcx, 800
    mov rdx, 600
    lea r8, [rel title]
    call CGXInit
    test eax, eax
    jz .fail

    lea rdx, [rel msg_d0]
    call _box

    movss xmm0, [rel cR]
    movss xmm1, [rel cG]
    movss xmm2, [rel cB]
    movss xmm3, [rel cA]
    call CGXSetClearColor

    ; Vertex shader
    mov ecx, CGX_VERTEX_SHADER
    call CGXCreateShader
    test eax, eax
    jz .fail
    mov [rel vsId], eax

    mov ecx, [rel vsId]
    lea rdx, [rel vsSrc]
    mov r8d, vsSrcLen
    call CGXShaderSource

    mov ecx, [rel vsId]
    call CGXCompileShader
    test eax, eax
    jz .fail

    ; Frag shader
    mov ecx, CGX_FRAGMENT_SHADER
    call CGXCreateShader
    test eax, eax
    jz .fail
    mov [rel fsId], eax

    mov ecx, [rel fsId]
    lea rdx, [rel fsSrc]
    mov r8d, fsSrcLen
    call CGXShaderSource

    mov ecx, [rel fsId]
    call CGXCompileShader
    test eax, eax
    jz .fail

    lea rdx, [rel msg_d1]
    call _box

    call CGXCreateProgram
    test eax, eax
    jz .fail
    mov [rel progId], eax

    mov ecx, [rel progId]
    mov edx, [rel vsId]
    call CGXAttachShader

    mov ecx, [rel progId]
    mov edx, [rel fsId]
    call CGXAttachShader

    ; Bind aPos -> VAO slot 0
    mov ecx, [rel progId]
    xor edx, edx
    lea r8, [rel aPosName]
    call CGXBindAttribLocation

    mov ecx, [rel progId]
    call CGXLinkProgram
    test eax, eax
    jz .fail

    lea rdx, [rel msg_d2]
    call _box

    ; Buffers
    lea rcx, [rel vertices]
    mov rdx, vertices_size
    mov r8d, CGX_STATIC
    call CGXCreateVertexBuffer
    test eax, eax
    jz .fail
    mov ebx, eax

    lea rcx, [rel indices]
    mov rdx, indices_size
    mov r8d, CGX_STATIC
    call CGXCreateIndexBuffer
    test eax, eax
    jz .fail
    mov r12d, eax

    call CGXCreateVertexArray
    test eax, eax
    jz .fail
    mov r13d, eax

    mov ecx, r13d
    call CGXBindVertexArray

    mov ecx, ebx
    call CGXBindVertexBuffer

    mov ecx, r12d
    call CGXBindIndexBuffer

    ; Attrib slot 0: aPos, 3 floats, offset 0, stride 12
    mov rcx, 0
    mov rdx, 3
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 12
    mov qword [rsp + 40], 0
    call CGXVertexAttribPointer

    mov rcx, 0
    call CGXEnableVertexAttribArray

    mov ecx, [rel progId]
    call CGXUseProgram

.loop:
    call CGXPollEvents
    call CGXShouldClose
    cmp eax, 1
    je .done

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

.fail:
    lea rdx, [rel msg_fail]
    call _box
    call CGXShutdown
    mov eax, 1

.finish:
    add rsp, 72
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret