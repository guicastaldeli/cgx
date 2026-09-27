; ============================================
; test_shader_pool.asm
; test for the pubic shader API.
;
; Does NOT render. Executes:
;   - CGXCreateShader / CGXShaderSource / CGXCompileShader
;   - CGXCreateProgram / CGXAttachShader / CGXLinkProgram
;   - CGXGetUniformLocation / CGXGetAttribLocation
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
extern CGXGetAttribLocation
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
    aPosName        db "aPos", 0

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
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 56

    lea rdx, [rel msg_d0]
    call _box

    mov rcx, 800
    mov rdx, 600
    lea r8, [rel title]
    call CGXInit
    test eax, eax
    jnz .initOk

    lea rdx, [rel msg_fail_init]
    call _box
    jmp .fail

.initOk:
    lea rdx, [rel msg_d1]
    call _box

    ; Vertex shader
    mov ecx, CGX_VERTEX_SHADER
    call CGXCreateShader
    test eax, eax
    jz .vsFail
    mov [rel vsId], eax

    lea rdi, [rel msg_d2 + 29]
    call _write3digits
    lea rdx, [rel msg_d2]
    call _box

    ; Srouce
    mov ecx, [rel vsId]
    lea rdx, [rel vsSrc]
    mov r8d, vsSrcLen
    call CGXShaderSource

    ; Compile
    mov ecx, [rel vsId]
    call CGXCompileShader
    mov r12d, eax

    lea rdi, [rel msg_d3 + 30]
    mov eax, r12d
    call _write3digits
    lea rdx, [rel msg_d3]
    call _box

    test r12d, r12d
    jz .vscFail
    jmp .vertexOk

.vsFail:
    lea rdx, [rel msg_fail_vs]
    call _box
    jmp .fail
.vscFail:
    lea rdx, [rel msg_fail_vsc]
    call _box
    jmp .fail
.vertexOk:
    ; Frag shader
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
    jz .fscFail
    jmp .fragOk

.fsFail:
    lea rdx, [rel msg_fail_fs]
    call _box
    jmp .fail
.fscFail:
    lea rdx, [rel msg_fail_fsc]
    call _box
    jmp .fail
.fragOk:
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
    mov r13d, eax

    lea rdi, [rel msg_d4 + 28]
    mov eax, r13d
    call _write3digits
    lea rdx, [rel msg_d4]
    call _box

    test r13d, r13d
    jz .linkFail
    jmp .linkOk

.progFail:
    lea rdx, [rel msg_fail_prog]
    call _box
    jmp .fail
.linkFail:
    lea rdx, [rel msg_fail_link]
    call _box
    jmp .fail
.linkOk:
    ; GetUniformLocation("uScale")
    mov ecx, [rel progId]
    lea rdx, [rel uScaleName]
    call CGXGetUniformLocation
    mov [rel uScaleLoc], eax

    lea rdi, [rel msg_d5 + 32]
    call _write3digits
    lea rdx, [rel msg_d5]
    call _box

    cmp eax, 0
    jge .ulocOk
    lea rdx, [rel msg_fail_uloc]
    call _box
    jmp .fail

.ulocOk:
    ; GetAttribLocation("aPos")
    mov ecx, [rel progId]
    lea rdx, [rel aPosName]
    call CGXGetAttribLocation
    mov [rel aPosLoc], eax

    lea rdi, [rel msg_d6 + 31]
    call _write3digits
    lea rdx, [rel msg_d6]
    call _box

    cmp eax, 0
    jge .alocOk
    lea rdx, [rel msg_fail_aloc]
    call _box
    jmp .fail
.alocOk:
    ; Write a uniform and read it back from vertex VM
    ; CGXUniform4f(prog, "uScale", 0.5, 0.5, 0.5, 0.5)
    ;
    ; After writing, the register the analyzer assigned to uScale
    ; in the vertex shader should contain (0.5, 0.5, 0.5, 0.5)
    ; read .x, multiply by 100, turncate to int, and display.
    ; Expected: 50.

    mov ecx, [rel progId]
    lea rdx, [rel uScaleName]
    mov eax, 0x3F000000         ; value: 0.5f
    movd xmm0, eax
    movaps xmm1, xmm0
    movaps xmm2, xmm0
    movaps xmm3, xmm0
    call CGXUniform4f

    ; Find uScale's register in the linked uniform table by
    ; locating its entry through CGXGetUniformLocation's index.

    mov rax, [rel _cgxCoreState + CGXState.programPool]
    mov rcx, [rax + Program.uniforms]
    movzx eax, byte [rcx + Uniform.vertReg]

    shl eax, 4
    lea rbx, [rel _cgxCoreState + CGXState.vertVM + VMState.regs]
    movss xmm0, [rbx + rax]

    mov eax, 0x42C80000         ; 100.0f
    movd xmm1, eax
    mulss xmm0, xmm1
    cvttss2si eax, xmm0         ; expect 50

    lea rdi, [rel msg_d7 + 29]
    call _write3digits
    lea rdx, [rel msg_d7]
    call _box

    ; Done
    call CGXShutdown
    xor eax, eax
    jmp .finish

.fail:
    call CGXShutdown
    mov eax, 1

.finish:
    add rsp, 56
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
