; ============================================
; test_cube.asm
; Rotating 3D cube with perspective
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
extern CGXGetTimeDelta
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
extern CGXMatrixMode
extern CGXLoadIdentity
extern CGXTranslate
extern CGXRotate
extern CGXPerspective
extern MessageBoxA

section .data
    title db "CGX Test - Cube", 0

    cR dd 0.08
    cG dd 0.03
    cB dd 0.5
    cA dd 1.0

    ; Vertices: pos.x, pos.y, pos.z, col.r col.g, col.b (24 bytes each)
    vertices:
        ; 8 corners of a unit cube (-0.5 to +0.5)
        dd -0.5, -0.5, -0.5,   1.0, 0.0, 0.0    ; 0: red
        dd  0.5, -0.5, -0.5,   0.0, 1.0, 0.0    ; 1: green
        dd  0.5,  0.5, -0.5,   0.0, 0.0, 1.0    ; 2: blue
        dd -0.5,  0.5, -0.5,   1.0, 1.0, 0.0    ; 3: yellow
        dd -0.5, -0.5,  0.5,   1.0, 0.0, 1.0    ; 4: magenta
        dd  0.5, -0.5,  0.5,   0.0, 1.0, 1.0    ; 5: cyan
        dd  0.5,  0.5,  0.5,   1.0, 1.0, 1.0    ; 6: white
        dd -0.5,  0.5,  0.5,   0.5, 0.5, 0.5    ; 7: gray
    vertices_size equ 8 * 24

    ; --- Indices: 12 triangles (36 indices) ---
    indices:
        ; back face (z = -0.5):  0, 1, 2, 3
        dd 0, 1, 2,   2, 3, 0
        ; front face (z = +0.5): 4, 5, 6, 7
        dd 4, 5, 6,   6, 7, 4
        ; left face (x = -0.5):  0, 3, 7, 4
        dd 0, 3, 7,   7, 4, 0
        ; right face (x = +0.5): 1, 5, 6, 2
        dd 1, 5, 6,   6, 2, 1
        ; top face (y = +0.5):   3, 2, 6, 7
        dd 3, 2, 6,   6, 7, 3
        ; bottom face (y = -0.5): 0, 4, 5, 1
        dd 0, 4, 5,   5, 1, 0
    indices_size equ 36 * 4

    ; Perspective params
    fov             dd 60.0
    aspect          dd 1.3333333        ; 800 / 600
    zNear           dd 0.1
    zFar            dd 100.0

    ; Rotation axis (X, then Y)
    axis_x          dd 1.0
    axis_y          dd 0.0
    axis_z          dd 0.0

    axis2_x         dd 0.0
    axis2_y         dd 1.0
    axis2_z         dd 0.0

    msg_err_title db "Cube Test", 0
    msg_err db "Cube test FAILED", 0

section .bss
    angle       resd 1

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

    ; Attrib 0: position (3 floats at offset 0)
    mov rcx, 0
    mov edx, 3
    mov r8d, CGX_FLOAT
    xor r9d, r9d
    mov qword [rsp + 32], 24
    mov qword [rsp + 40], 0
    call CGXVertexAttribPointer

    ; Attrib 1: color (3 floats at offset 12)
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

    ; -- Setup projection ---
    mov rcx, CGX_PROJECTION
    call CGXMatrixMode
    call CGXLoadIdentity

    movss xmm0, [rel fov]
    movss xmm1, [rel aspect]
    movss xmm2, [rel zNear]
    movss xmm3, [rel zFar]
    call CGXPerspective

    ; Init angle
    mov dword [rel angle], 0

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

    ; --- Setup modelview per frame ---
    mov rcx, CGX_MODELVIEW
    call CGXMatrixMode
    call CGXLoadIdentity

    ; Translate: camera back (model forward)
    mov eax, 0x00000000
    movd xmm0, eax
    movd xmm1, eax
    mov eax, 0xC0400000         ; -3.0
    movd xmm2, eax
    call CGXTranslate

    ; Rotate around X
    ;movss xmm0, [rel angle]
    ;movss xmm1, [rel axis_x]
    ;movss xmm2, [rel axis_y]
    ;movss xmm3, [rel axis_z]
    ;call CGXRotate

    ; Rotate around Y
    movss xmm0, [rel angle]
    movss xmm1, [rel axis2_x]
    movss xmm2, [rel axis2_y]
    movss xmm3, [rel axis2_z]
    call CGXRotate

    ; Draw
    mov ecx, r13d
    call CGXBindVertexArray

    mov rcx, CGX_TRIANGLES
    mov rdx, 36
    mov r8d, CGX_UINT
    xor r9d, r9d
    call CGXDrawElements

    call CGXSwapBuffers

    ; angle += 1
    movss xmm0, [rel angle]
    mov eax, 0x3E99999A         ; Speed: 1.0
    movd xmm1, eax
    addss xmm0, xmm1
    movss [rel angle], xmm0

    ; Wrap at 360
    movss xmm1, [rel angle]
    mov eax, 0x43B40000         ; 360.0
    movd xmm2, eax
    comiss xmm1, xmm2
    jb .loop
    mov dword [rel angle], 0
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

    
