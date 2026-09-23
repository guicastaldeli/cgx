; ============================================
; test_shader_parse.asm
; Sanity test: tokenize + parse a shader string
; No rendering. Just check the front-end produces
; non-zero token and AST counts.
; ============================================

default rel

global main

%include "constants.inc"
%include "structs.inc"
%include "shader.inc"

extern CGXInit
extern CGXShutdown
extern MessageBoxA

extern _cgxCoreLexerTokenize
extern _cgxCoreParserParse
extern _cgxCoreParserGetErrorPos

section .data
    ; --- Shader source to parse ---
    shaderSrc:
        db "attribute vec3 aPos;", 10
        db "attribute vec4 aColor;", 10
        db "varying vec4 vColor;", 10
        db "uniform mat4 uMVP;", 10
        db "void main() {", 10
        db "    gl_Position = uMVP * vec4(aPos, 1.0);", 10
        db "    vColor = aColor;", 10
        db "}", 10
        db 0
    shaderSrcLen equ $ - shaderSrc - 1

    title           db "Shader Parse Test", 0

    msg_d0          db "D0: main entered", 0
    msg_d1          db "D1: CGXInit OK", 0
    msg_d2          db "D2: about to tokenize", 0
    msg_d3          db "D3: tokenize returned", 0
    msg_d4          db "D4: about to parse", 0
    msg_d5          db "D5: parse returned", 0

    msg_fail_init   db "FAIL: CGXInit returned 0", 0
    msg_fail_lex    db "FAIL: tokenizer returned 0", 0
    msg_fail_parse  db "FAIL: parser returned 0", 0

    msg_tok_count   db "Token count: 000", 0
    msg_ast_count   db "AST node count: 000", 0

    MAX_TOKENS          equ 128
    MAX_AST             equ 64

section .bss
    tokens              resb MAX_TOKENS * Token_size
    ast                 resb MAX_AST * ASTNode_size
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
    mov rbx, 100
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
    sub rsp, 40

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

    lea rdx, [rel msg_d2]
    call _box

    ; Tokenize
    lea rcx, [rel shaderSrc]
    lea rdx, [rel tokens]
    mov r8d, MAX_TOKENS
    call _cgxCoreLexerTokenize
    test eax, eax
    jnz .lexOk

    lea rdx, [msg_fail_lex]
    call _box
    jmp .fail

.lexOk:
    mov r12d, eax

    lea rdx, [rel msg_d3]
    call _box

    ; Show token count
    lea rdi, [rel msg_tok_count + 13]
    mov eax, r12d
    call _write3digits
    lea rdx, [rel msg_tok_count]
    call _box

    lea rdx, [rel msg_d4]
    call _box

    ; PArse
    lea rcx, [rel tokens]
    mov edx, r12d
    mov r8d, CGX_VERTEX_SHADER
    lea r9, [rel ast]
    call _cgxCoreParserParse
    test eax, eax
    jnz .parseOk

    lea rdx, [rel msg_fail_parse]
    call _box
    jmp .fail

.parseOk:
    mov r13d, eax

    lea rdx, [rel msg_d5]
    call _box

    ; Show AST count
    lea rdi, [rel msg_ast_count + 15]
    mov eax, r13d
    call _write3digits
    lea rdx, [rel msg_ast_count]
    call _box

    call CGXShutdown
    xor eax, eax
    jmp .finish

.fail:
    call CGXShutdown
    mov eax, 1

.finish:
    add rsp, 40
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret