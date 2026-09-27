; ============================================
; test_shader_vertex.asm
; Minimal test for the shader vertex path.
; Verify the vertex VM ran
; ============================================

default rel

global main

%include "constants.inc"
%include "structs.inc"
%include "shader.inc"

extern _cgxCoreState
extern CGXState

extern CGXInit
extern CGXShutdown
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
    title           db "Shader Vertex Test", 0

    vsSrc:
        db "attribute vec3 aPos;", 10
        db "void main() {", 10
        db "    gl_Position = vec4(aPos, 1.0);", 10
        db "}", 10
        db 0
    vsSrcLen equ $ - vsSrc - 1

    fsSrc:
        db "void main() {", 10
        db "    gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);", 10
        db "}", 10
        db 0
    fsSrcLen equ $ - fsSrc - 1

    aPosName        db "aPos", 0

    ; Triangle in NDC. 3 vertices, each (x, y, z), stride 12.
    vertices:
        dd -0.5,  0.5, 0.0
        dd -0.5, -0.5, 0.0
        dd  0.5, -0.5, 0.0
    vertices_size equ 3 * 12

    indices:
        dd 0, 1, 2
    indices_size equ 3 * 4

    ; Messages
    msg_d0          db "D0: main entered", 0
    msg_d1          db "D1: CGXInit OK", 0
    msg_d2          db "D2: VS compile failed", 0
    msg_d3          db "D3: FS compile failed", 0
    msg_d4          db "D4: link failed", 0
    msg_d5          db "D5: draw returned", 0

    ; gl_Position dump
    ;  positions: x, y, z, w, each scaled by 1000 and sign-marked
    msg_px          db "Px = +0000", 0
    msg_py          db "Py = +0000", 0
    msg_pz          db "Pz = +0000", 0
    msg_pw          db "Pw = +0000", 0

section .bss
    vsId            resd 1
    fsId            resd 1
    progId          resd 1

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

_formatSigned:
    push rbx
    push r12

    mov r12d, eax
    mov bl, '+'
    test eax, eax
    jns .positive
    mov bl, '-'
    neg eax
.positive:
    mov [rdi], bl
    inc rdi

    ; value 0..9999
    mov ebx, 1000
    xor edx, edx
    div ebx
    add al, '0'
    mov [rdi], al
    inc rdi

    mov eax, edx
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
    add al, '0'
    mov [rdi], al
    inc rdi

    mov eax, edx
    add al, '0'
    mov [rdi], al

    pop r12
    pop rbx
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

    lea rdx, [rel msg_d0]
    call _box

    mov rcx, 800
    mov rdx, 600
    lea r8, [rel title]
    call CGXInit
    test eax, eax
    jnz .initOk

    call CGXShutdown
    mov eax, 1
    jmp .finish

.initOk:
    lea rdx, [rel msg_d1]
    call _box

    ; vertex shader
    mov ecx, CGX_VERTEX_SHADER
    call CGXCreateShader
    test eax, eax
    jz .vsFail
    mov [rel vsId], eax

    mov ecx, [rel vsId]
    lea rdx, [rel vsSrc]
    mov r8d, vsSrcLen
    call CGXShaderSource

    mov ecx, [rel vsId]
    call CGXCompileShader
    test eax, eax
    jz .vsFail

    ; fragment shader
    mov ecx, CGX_FRAGMENT_SHADER
    call CGXCreateShader
    test eax, eax
    jz .fsFail
    mov [rel fsId], eax

    mov ecx, [rel fsId]
    lea rdx, [rel fsSrc]
    mov r8d, fsSrcLen
    call CGXShaderSource

    mov ecx, [rel fsId]
    call CGXCompileShader
    test eax, eax
    jz .fsFail

    ; Program
    call CGXCreateProgram
    test eax, eax
    jz .progFail
    mov [rel progId], eax

    mov ecx, [rel progId]
    mov edx, [rel vsId]
    call CGXAttachShader

    mov ecx, [rel progId]
    mov edx, [rel fsId]
    call CGXAttachShader

    mov ecx, [rel progId]
    call CGXLinkProgram
    test eax, eax
    jz .linkFail

    ; Bind aPos to VAO slot 0
    mov ecx, [rel progId]
    xor edx, edx
    lea r8, [rel aPosName]
    call CGXBindAttribLocation

    ; Create buffers
    ; VBO
    lea rcx, [rel vertices]
    mov rdx, vertices_size
    mov r8d, CGX_STATIC
    call CGXCreateVertexBuffer
    test eax, eax
    jz .progFail
    mov ebx, eax

    ; EBO
    lea rcx, [rel indices]
    mov rdx, indices_size
    mov r8d, CGX_STATIC
    call CGXCreateIndexBuffer
    test eax, eax
    jz .progFail
    mov r12d, eax

    ; VAO
    call CGXCreateVertexArray
    test eax, eax
    jz .progFail
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

    ; Attrib slot 0: 3 floats, offset 0, stride 12
    mov rcx, 0
    mov rdx, 3
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 12
    mov qword [rsp + 40], 0
    call CGXVertexAttribPointer

    mov rcx, 0
    call CGXEnableVertexAttribArray

    ; Use program
    mov ecx, [rel progId]
    call CGXUseProgram

    ; Draw
    mov rcx, CGX_TRIANGLES
    mov rdx, 3
    mov r8d, CGX_UINT
    xor r9d, r9d
    call CGXDrawElements

    lea rdx, [rel msg_d5]
    call _box

    ; Read vertVM.regs[0]
    ; The shader wrote gl_Position = vec4(aPos, 1.0)
    ; aPos came from attribute slot 0, first vertex = (-0.5, 0.5, 0.5)
    ; So reg 0 should hold (-0.5, 0.5, 0.0, 1.0)
    lea rbx, [rel _cgxCoreState + CGXState.vertVM + VMState.regs]

    ; x
    movss xmm0, [rbx + 0]
    mov eax, 0x447A0000                 ; 1000.0f
    movd xmm1, eax
    mulss xmm0, xmm1
    cvttss2si eax, xmm0
    lea rdi, [rel msg_px + 5]
    call _formatSigned
    lea rdx, [rel msg_px]
    call _box

    ; y
    lea rbx, [rel _cgxCoreState + CGXState.vertVM + VMState.regs]
    movss xmm0, [rbx + 4]
    mov eax, 0x447A0000
    movd xmm1, eax
    mulss xmm0, xmm1
    cvttss2si eax, xmm0
    lea rdi, [rel msg_py + 5]
    call _formatSigned
    lea rdx, [rel msg_py]
    call _box

    ; z
    lea rbx, [rel _cgxCoreState + CGXState.vertVM + VMState.regs]
    movss xmm0, [rbx + 8]
    mov eax, 0x447A0000
    movd xmm1, eax
    mulss xmm0, xmm1
    cvttss2si eax, xmm0
    lea rdi, [rel msg_pz + 5]
    call _formatSigned
    lea rdx, [rel msg_pz]
    call _box

    ; w
    lea rbx, [rel _cgxCoreState + CGXState.vertVM + VMState.regs]
    movss xmm0, [rbx + 12]
    mov eax, 0x447A0000
    movd xmm1, eax
    mulss xmm0, xmm1
    cvttss2si eax, xmm0
    lea rdi, [rel msg_pw + 5]
    call _formatSigned
    lea rdx, [rel msg_pw]
    call _box

    call CGXShutdown
    xor eax, eax
    jmp .finish

.vsFail:
    lea rdx, [rel msg_d2]
    call _box
    jmp .fail
.fsFail:
    lea rdx, [rel msg_d3]
    call _box
    jmp .fail
.linkFail:
    lea rdx, [rel msg_d4]
    call _box
    jmp .fail
.progFail:
    lea rdx, [rel msg_d4]
    call _box
    jmp .fail

.fail:
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