; ============================================
; core/shader_paser.asm
; GLSL recursive descent parser -> flat AST
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"
%include "shader.inc"

extern _cgxCoreState
extern CGXState

global _cgxCoreParserParse
global _cgxCoreParserFindSymbol
global _cgxCoreParserAddSymbol
global _cgxCoreParserGetErrorPos

section .text

; --------------------------------------------
; _cgxCoreParserParse
; Input: rcx = token array ptr
;       edx = token count
;       r8d = shader type (CGX_VERTEX_SHADER / CGX_FRAGMENT_SHADER)
;       r9 = ASTNode array ptr
; Output: eax = number of AST nodes (0 on error)
;           ParseState error code written at [rbp-relative state]
; --------------------------------------------
_cgxCoreParserParse:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 5280

    ; Set up ParseState at [rbp - 56]
    ; ParseState_size = 56
    lea rbx, [rbp - 56]

    mov [rbx + ParseState.tokens], rcx
    mov [rbx + ParseState.tokenCount], edx
    mov dword [rbx + ParseState.tokenIdx], 0
    mov [rbx + ParseState.shaderType], r8d
    mov [rbx + ParseState.ast], r9
    mov dword [rbx + ParseState.astCount], 0
    mov dword [rbx + ParseState.astCap], CGX_MAX_AST_NODES
    mov dword [rbx + ParseState.errorPos], 0
    mov dword [rbx + ParseState.errorCode], 0

    ; Symbol table at [rbp - 5224] (5120 bytes)
    lea rax, [rbp - 5224]
    mov [rbx + ParseState.symtab], rax

    ; Zero the symbol table
    mov rdi, rax
    mov rcx, 640
    xor eax
    rep stosp

    ; Parse
    mov rdi, rbx
    call _parseProgram
    test eax, eax
    jz .fail

    ; Success -- return AST node count
    mov eax, [rbx + ParseState.astCount]
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 5280
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreParserGetErrorPos
; Input: rcx = ParseState ptr
; Output: eax = error position
; --------------------------------------------
_cgxCoreParserGetErrorPos:
    mov eax, [rcx + ParseState.errorPos]
    ret

; --------------------------------------------
; _peek
; Input: rbx = ParseState ptr
; Output: rax = pointer to current Token
; --------------------------------------------
_peek:
    