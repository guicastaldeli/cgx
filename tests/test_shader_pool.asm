; ============================================
; test_shader_pool.asm
; test for the pubic shader API.
;
; Does NOT render. Executes:
;   - CGXCreateShader / CGXShaderSource / CGXCompileShader
;   - CGXCreateProgram / CGXAttachShader / CGXLinkProgram
;   - CGXGetUniformLocation / CGXGetAttribLOcation
;   - CGXUniform4f writes into the vertex VM register file
;
; Each stage prints a MessageBox. If all stages show OK,
; the pool is working end-to-end
; ============================================

default rel

global main

%include "constants.inc"
%include "structs.inc"
%include "shader.inc"

extern CGXInit
extern CGXShutdown
extern MessageBoxA

extern CGXCreateShader
extern CGXShaderSource
extern CGXCompileShader
extern CGXGetShaderInfoLog
extern CGXCreateProgram
extern CGXAttachShader
extern CGXLinkProgram
extern CGXUseProgram
extern CGXGetUniformLocation
extern CGXGetAttribLOcation
extern CGXUniform4f

extern _cgxCoreState
extern CGXState

section .data
    title           db "Shader Pool Test", 0

    ; Vertex shader source
    vsSrc:
        db "uniform vec4 uScale;", 10
        db "attribute vec3 aPos;", 10
        db "void main() {", 10
        db "    gl_Position = vec4(aPos, 1.0);", 10
        db "}", 10
        db 0
    vsSrcLen equ $ - vsSrc - 1

    ; Frag shader source
    fsSrc:
        db "varying vec4 vColor;", 10
        db "void main() {", 10
        db "    gl_FragColor = vColor;", 10
        db "}", 10
        db 0
    fsSrcLen equ $ - fsSrc - 1

    uScaleName      db "uScale", 0
    aPosname        db "aPos", 0

    ; Messages
    msg_d0          db "D0: main entered", 0
    msg_d1          db "D1: CGXInit OK", 0
    msg_d2          db "D2: CGXCreateShader returned 000", 0
    msg_d3          db "D3: CGXCompileShader returned 000", 0
    msg_d4          db "D4: CGXLinkProgram returned 000", 0
    msg_d5          db "D5: GetUniformLocation returned 000", 0
    msg_d6          db "D6: GetAttribLocation returned 000", 0
    msg_d7          db "D7: uniform reg value x100 = 000", 0

    msg_fail_init   db "FAIL: CGXInit returned 0", 0
    msg_fail_vs     db "FAIL: VS create returned 0", 0
    msg_fail_vsc    db "FAIL: VS compile returned 0", 0
    msg_fail_fs     db "FAIL: FS create returned 0", 0
    msg_fail_fsc    db "FAIL: FS compile returned 0", 0
    msg_fail_prog   db "FAIL: program create returned 0", 0
    msg_fail_link   db "FAIL: link returned 0", 0
    msg_fail_uloc   db "FAIL: uScale location < 0", 0
    msg_fail_aloc   db "FAIL: aPos location < 0", 0

section .bss
    vsId            resd 1
    fsId            resd 1
    progId          resd 1
    uScaleLoc       resd 1
    aPosLoc         resd 1

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

_write3digits:
    push rbx
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

    pop rbx
    ret

main:
    