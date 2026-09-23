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

    ; --- Token buffer
    MAX_TOKENS equ 256
    tokens: times (MAX_TOKENS * 24) db 0

    ; --- AST buffer ---
    MAX_AST equ 64
    ast: times (MAX_AST * ASTNode_size) db 0

    ; --- Result strings for MessageBox ---
    title           db "Shader Parse Test", 0
    msg_tokens      db "Tokens: 000", 0
    msg_ast         db "AST nodes: 000", 0
    msg_error       db "Parse FAILED at offset 000", 0

section .text

main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 96

    mov rcx, 800
    mov rdx, 600
    lea r8, [rel title]
    call CGXInit
    cmp eax, 0
    je .error

    ; Tokenize
    lea rcx, [rel shaderSrc]
    lea rdx, [rel tokens]
    mov r8d, MAX_TOKENS
    call _cgxCoreLexerTokenize
    test eax, eax
    jz .lexError

    mov r12d, eax               ; token count

    ; Format token count into msg_token (3 digits)
    lea rdi, [rel msg_tokens + 8]
    mov eax, r12d
    call _write3digits

    xor rcx, rcx
    lea rdx, [rel msg_tokens]
    lea r8, [rel title]
    mov r9d, 0
    call MessageBoxA

    ; Parse
    lea rcx, [rel tokens]       ; token array
    mov edx, r12d               ; token count
    mov r8d, 1                  ; shaderType: CGX_VERTEX_SHADER
    lea r9, [rel ast]           ; AST output
    call _cgxCoreParserParse
    test eax, eax
    jz .parseError

    mov r13d, eax               ; AST node count

    ; Format AST count into msg_ast
    lea rdi, [rel msg_ast + 11]
    mov eax, r13d
    call _write3digits

    xor rcx, rcx
    lea rdx, [rel msg_ast]
    lea r8, [rel title]
    mov r9d, 0
    call MessageBoxA

    call CGXShutdown
    xor eax, eax
    jmp .finish

.lexError:
    xor rcx, rcx
    lea rdx, [rel msg_error]
    lea r8, [rel title]
    mov r9d, 0
    call MessageBoxA
    jmp .fail

.parseError:
    xor rcx, rcx
    lea rdx, [rel msg_error]
    lea r8, [rel title]
    mov r9d, 0
    call MessageBoxA
    jmp .fail
.error:
    jmp .fail
.fail:
    call CGXShutdown
    mov eax, 1

.finish:
    add rsp, 96
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _write3digits
; Input: rdi = destination, eax = value (0..999)
; Writes three ASCII digits
; --------------------------------------------
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