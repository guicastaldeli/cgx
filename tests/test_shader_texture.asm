; ============================================
; test_shader_texture.asm
; Textured quad rendered through a real shader pair.
;
; Vertex shader passes position through (vec4(aPos, 1.0))
; and forwards UV as a varying.
; Fragment shader samples the bound checkerboard texture
; and writes it to gl_FragColor.
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
extern CGXGenTextures
extern CGXBindTexture
extern CGXTexImage2D
extern CGXTexParameteri
extern CGXActiveTexture

section .data
    title db "CGX Test - Shader Texture", 0

    cR dd 0.05
    cG dd 0.05
    cB dd 0.1
    cA dd 1.0

    ; ---- Vertex shader ----
    vsSrc:
        db "attribute vec3 aPos;", 10
        db "attribute vec2 aUV;", 10
        db "varying vec2 vUV;", 10
        db "void main() {", 10
        db "    vUV = aUV;", 10
        db "    gl_Position = vec4(aPos, 1.0);", 10
        db "}", 10
        db 0
    vsSrcLen equ $ - vsSrc - 1

    ; ---- Fragment shader ----
    fsSrc:
        db "uniform sampler2D uTex;", 10
        db "void main() {", 10
        db "    gl_FragColor = texture2D(uTex, vec2(0.5, 0.5));", 10
        db "}", 10
        db 0
    fsSrcLen equ $ - fsSrc - 1

    aPosName    db "aPos", 0
    aUVName     db "aUV", 0

    ; Interleaved: (x, y, z, u, v), 5 floats = 20 bytes per vertex
    vertices:
        dd -0.8, -0.8, 0.0,   0.0, 0.0
        dd  0.8, -0.8, 0.0,   1.0, 0.0
        dd  0.8,  0.8, 0.0,   1.0, 1.0
        dd -0.8,  0.8, 0.0,   0.0, 1.0
    vertices_size equ 4 * 20

    indices:
        dd 0, 1, 2,   2, 3, 0
    indices_size equ 6 * 4

    TEX_WIDTH   equ 64
    TEX_HEIGHT  equ 64
    TEX_SIZE    equ TEX_WIDTH * TEX_HEIGHT * 4

    texId       dd 0

    msg_d0      db "Test - init OK", 0
    msg_d1      db "Test - shaders compiled", 0
    msg_d2      db "Test - program linked", 0
    msg_fail    db "Test FAILED", 0

section .bss
    vsId        resd 1
    fsId        resd 1
    progId      resd 1
    textureData resb TEX_SIZE

section .text

; --------------------------------------------
; _box
; Input: rdx = message ptr
; --------------------------------------------
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

; --------------------------------------------
; _buildCheckerboard
; Fills textureData with an 8x8 checkerboard.
; Memory layout: 0xAARRGGBR little-endian (BGRA byte order).
; --------------------------------------------
_buildCheckerboard:
    push rbp
    mov rbp, rsp
    push rbx

    lea rdi, [rel textureData]
    xor r12d, r12d                  ; y
.yLoop:
    cmp r12d, TEX_HEIGHT
    jge .done

    xor r13d, r13d                  ; x
.xLoop:
    cmp r13d, TEX_WIDTH
    jge .nextRow

    mov eax, r13d
    shr eax, 3
    mov ecx, r12d
    shr ecx, 3
    add eax, ecx
    test eax, 1
    jz .colorB

    mov edx, 0x00000000             ; black
    jmp .store
.colorB:
    mov edx, 0xFFFFFFFF             ; white
.store:
    mov [rdi], edx
    add rdi, 4

    inc r13d
    jmp .xLoop
.nextRow:
    inc r12d
    jmp .yLoop
.done:
    pop rbx
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

    ; Texture
    mov rcx, CGX_TEXTURE0
    call CGXActiveTexture

    mov rcx, 1
    lea rdx, [rel texId]
    call CGXGenTextures

    mov rcx, CGX_TEXTURE_2D
    mov edx, [rel texId]
    call CGXBindTexture

    call _buildCheckerboard

    ; Upload
    mov rcx, CGX_TEXTURE_2D
    xor edx, edx
    mov r8d, CGX_RGBA
    mov r9d, TEX_WIDTH
    mov qword [rsp + 32], TEX_HEIGHT
    mov qword [rsp + 40], 0
    mov qword [rsp + 48], CGX_RGBA
    mov qword [rsp + 56], CGX_UNSIGNED_BYTE
    lea rax, [rel textureData]
    mov qword [rsp + 64], rax
    call CGXTexImage2D

    mov rcx, CGX_TEXTURE_2D
    mov rdx, CGX_TEXTURE_MIN_FILTER
    mov r8d, CGX_NEAREST
    call CGXTexParameteri

    mov rcx, CGX_TEXTURE_2D
    mov rdx, CGX_TEXTURE_MAG_FILTER
    mov r8d, CGX_NEAREST
    call CGXTexParameteri

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

    ; Program
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

    ; Bind aPos -> slot 0, aUV -> slot 1
    mov ecx, [rel progId]
    xor edx, edx
    lea r8, [rel aPosName]
    call CGXBindAttribLocation

    mov ecx, [rel progId]
    mov edx, 1
    lea r8, [rel aUVName]
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

    ; Attrib 0: aPos, 3 floats, offset 0, stride 20
    mov rcx, 0
    mov rdx, 3
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 20
    mov qword [rsp + 40], 0
    call CGXVertexAttribPointer

    ; Attrib 1: aUV, 2 floats, offset 12, stride 20
    mov rcx, 1
    mov rdx, 2
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 20
    mov qword [rsp + 40], 12
    call CGXVertexAttribPointer

    mov rcx, 0
    call CGXEnableVertexAttribArray
    mov rcx, 1
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