; ============================================
; test_texture.asm
; Texture quad - procedural checkerboard
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
extern CGXGenTextures
extern CGXBindTexture
extern CGXTexImage2D
extern CGXTexParameteri
extern CGXTexEnvi
extern CGXActiveTexture
extern MessageBoxA

section .data
    title db "CGX Test - Texture", 0

    cR dd 0.05
    cG dd 0.05
    cB dd 0.1
    cA dd 1.0

    ; Vertex format:
    ;   pos.xyz (12) + rgba (16) + uv (8) = 36 bytes
    vertices:
        dd -0.8, -0.8, 0.0,  1.0, 1.0, 1.0, 1.0,   0.0, 0.0
        dd  0.8, -0.8, 0.0,  1.0, 1.0, 1.0, 1.0,   1.0, 0.0
        dd  0.8,  0.8, 0.0,  1.0, 1.0, 1.0, 1.0,   1.0, 1.0
        dd -0.8,  0.8, 0.0,  1.0, 1.0, 1.0, 1.0,   0.0, 1.0
    vertices_size equ 4 * 36

    indices:
        dd 0, 1, 2,   2, 3, 0
    indices_size equ 6 * 4

    TEX_WIDTH       equ 64
    TEX_HEIGHT      equ 64
    TEX_SIZE        equ TEX_WIDTH * TEX_HEIGHT * 4

    texId           dd 0

    msg_err_title db "Texture Test", 0
    msg_err db "Texture test FAILED", 0

section .bss
    textureData     resb TEX_SIZE

section .text

; --------------------------------------------
; buildCheckerboard
; 8x8 checkerboard. Two colors.
; Dword layout in memory: 0xAARRGGBB (matches framebuffer)
; --------------------------------------------
buildCheckerboard:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

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

    ; Black: 0xAARRGGBB = 0x00000000
    mov edx, 0x00000000
    jmp .store
.colorB:
    ; White: 0xFFFFFFFF
    mov edx, 0xFFFFFFFF
.store:
    mov [rdi], edx
    add rdi, 4

    inc r13d
    jmp .xLoop
.nextRow:
    inc r12d
    jmp .yLoop
.done:
    pop r13
    pop r12
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

    mov rcx, CGX_DEPTH_TEST
    call CGXEnable

    mov rcx, CGX_TEXTURE0
    call CGXActiveTexture

    ; Generate a texture id
    mov rcx, 1
    lea rdx, [rel texId]
    call CGXGenTextures

    ; Bind
    mov rcx, CGX_TEXTURE_2D
    mov edx, [rel texId]
    call CGXBindTexture

    ; Build pixel data
    call buildCheckerboard

    ; Upload
    mov rcx, CGX_TEXTURE_2D
    xor edx, edx                                        ; level
    mov r8d, CGX_RGBA                                   ; internalFormat
    mov r9d, TEX_WIDTH                                  ; width
    mov qword [rsp + 32], TEX_HEIGHT
    mov qword [rsp + 40], 0
    mov qword [rsp + 48], CGX_RGBA                      ; format
    mov qword [rsp + 56], CGX_UNSIGNED_BYTE             ; border
    lea rax, [rel textureData]
    mov qword [rsp + 64], rax
    call CGXTexImage2D

    ; Filters
    mov rcx, CGX_TEXTURE_2D
    mov rdx, CGX_TEXTURE_MIN_FILTER
    mov r8d, CGX_NEAREST
    call CGXTexParameteri

    mov rcx, CGX_TEXTURE_2D
    mov rdx, CGX_TEXTURE_MAG_FILTER
    mov r8d, CGX_NEAREST
    call CGXTexParameteri

    ; Env mode
    mov rcx, CGX_TEXTURE_ENV
    mov rdx, CGX_TEXTURE_ENV_MODE
    mov r8d, CGX_MODULATE
    call CGXTexEnvi

    ; Enable 2D rendering
    mov rcx, CGX_TEXTURE_2D
    call CGXEnable

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

    ; VBO
    mov ecx, ebx
    call CGXBindVertexBuffer

    ; EBO
    mov ecx, r12d
    call CGXBindIndexBuffer

    ; Attrib 0: position, 3 floats, offste 0, stride 36
    mov rcx, 0
    mov rdx, 3
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 36
    mov qword [rsp + 40], 0
    call CGXVertexAttribPointer

    ; Attrib 1: color, 4 floats, offset 12, stride 36
    mov rcx, 1
    mov rdx, 4
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 36
    mov qword [rsp + 40], 12
    call CGXVertexAttribPointer

    ; Attrib 2: texcoord, 2 floats offset 28, stride 36
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