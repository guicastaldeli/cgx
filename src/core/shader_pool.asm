; ============================================
; core/shader_pool.asm
; Shader and Program pools, plus uniform upload.
; Owns: shaderPool, programPool, compiled bytecode
;       symbol tables, linked uniform/attrib/varying tables
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"
%include "shader.inc"

extern VirtualAlloc
extern VirtualFree
extern RtlCopyMemory

extern _cgxCoreState
extern CGXState

extern _parserState
extern _cgxCoreLexerTokenize
extern _cgxCoreParserParse
extern _cgxCoreAnalyze
extern _cgxCoreCompile

global _cgxCoreShaderInit
global _cgxCoreShaderShutdown
global _cgxCoreShaderCreate
global _cgxCoreShaderSource
global _cgxCoreShaderCompile
global _cgxCoreShaderDelete
global _cgxCoreShaderGetInfoLog
global _cgxCoreProgramCreate
global _cgxCoreProgramAttach
global _cgxCoreProgramLink
global _cgxCoreProgramUse
global _cgxCoreProgramDelete
global _cgxCoreGetUniformLocation
global _cgxCoreGetAttribLocation
global _cgxCoreUniform1f
global _cgxCoreUniform2f
global _cgxCoreUniform3f
global _cgxCoreUniform4f
global _cgxCoreUniform1i
global _cgxCoreUniform3fv
global _cgxCoreUniform4fv
global _cgxCoreUniformMatrix4fv
global _cgxCoreShaderFindById
global _cgxCoreProgramFindById

MEM_COMMIT                      equ 0x00001000
MEM_RESERVE                     equ 0x00002000
MEM_RELEASE                     equ 0x00008000
PAGE_READWRITE                  equ 0x04

SHADER_SYMTAB_BYTES             equ CGX_MAX_SYMBOLS * Symbol_size           ; 5120
SHADER_INSTR_BYTES              equ CGX_MAX_INSTRUCTIONS * Instr_size       ; 24576
SHADER_INFO_LOG_BYTES           equ 1024                                    ; 1024
SHADER_SRC_BYTES                equ CHX_MAX_SOURCE_LEN                      ; 16384

PROG_UNIFORM_BYTES              equ CGX_MAX_UNIFORMS * Uniform_size         ; 64 * 40 = 2560
PROG_ATTRIB_BYTES               equ CGX_MAX_ATTRIBS * Symbol_size           ; 16 * 40 = 640
PROG_VARYING_BYTES              equ CGX_MAX_VARYINGS * Symbol_size          ; 8 * 40 = 320

section .bss
    _soTokens                   resb CGX_MAX_TOKENS * Token_size
    _spAst                      resb CGX_MAX_AST_NODES * ASTNode_size
    _spInstrs                   resb CGX_MAX_INSTRUCTIONS * Instr_size

section .text

; --------------------------------------------
; _cgxCoreShaderInit
; Allocates shaderPool and programPool.
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreShaderInit:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; Allocate shader pool
    xor rcx, rcx
    mov rdx, CGX_MAX_SHADERS * Shader_size
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail
    mov [rel _cgxCoreState + CGXState.shaderPool], rax

    mov rdi, raxa
    mov rcx, CGX_MAX_SHADERS * Shader_size / 8
    xor eax, eax
    rep stosq

    ; Allocate program pool
    xor rcx, rcx
    mov rdx, CGX_MAX_PROGRAMS * Program_size
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail

    mov [rel _cgxCoreState + CGXState.programPool], rax

    mov rdi, rax
    mov rcx, CGX_MAX_PROGRAMS * Program_size / 8
    xor eax, eax
    rep stosq

    mov dword [rel _cgxCoreState + CGXState.shaderCount], 0
    mov dword [rel _cgxCoreState + CGXState.nextShaderId], 1
    mov dword [rel _cgxCoreState + CGXState.programCount], 0
    mov dword [rel _cgxCoreState + CGXState.nextProgramId], 1
    mov dword [rel _cgxCoreState + CGXState.boundProgram], 0

    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreShaderShutdown
; Frees every shader and program's owned memory,
; then frees the pools
; --------------------------------------------
_cgxCoreShaderShutdown:
    push rbp
    mov rsp, rsp
    push rbx
    push r12
    sub rsp, 32

    ; Free per-shader allocations
    mov rbx, [rel _cgxCoreState + CGXState.shaderPool]
    test rbx, rbx
    jz .progs

    xor r12d, r12d

.shaderPool:
    cmp r12d, CGX_MAX_SHADERS
    jge .shaderPoolFree

    mov eax, r12d
    imul eax, Shader_size
    lea rdi, [rbx + rax]

    cmp byte [rdi + Shader.inUse], 0
    je .shaderNext

    ; Free source
    mov rcx, [rdi + Shader.source]
    test rcx, rcx
    jz .freeInstr
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree

.freeInstr:
    mov eax, r12d
    imul eax, Shader_size
    lea rdi, [rbx + rax]

    mov rcx, [rdi + Shader.instr]
    test rcx, rcx
    jz .freeSyms
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree

.freeSyms:
    mov eax, r12d
    imul eax, Shader_size
    lea rdi, [rbx + rax]

    mov rcx, [rdi + Shader.symbol]
    test rcx, rcx
    jz .freeLog
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree

.freeLog:
    mov eax, r12d
    imul eax, Shader_size
    lea rdi, [rbx + rax]

    mov rcx, [rdi + Shader.infoLog]
    test rcx, rcx
    jz .shaderNext
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree

.shaderNext:
    inc r12d
    jmp .shaderLoop

.shaderPoolFree:
    mov rcx, rbx
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree
    mov qword [rel _cgxCoreState + CGXState.shaderPool], 0

.progs:
    mov rbx, [rel _cgxCoreState + CGXState.programPool]
    test rbx, rbx
    jz .done

    xor r12d, r12d
.progLoop:
    cmp r12d, CGX_MAX_PROGRAMS
    jge .progPoolFree

    mov eax, r12d
    imul eax, Program_size
    lea rdi, [rbx + rax]

    cmp byte [rdi + Program.inUse], 0
    je .progNext

    mov rcx, [rdi + Program.uniforms]
    test rcx, rcx
    jz .freeAttribs
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree

.freeAttribs:
    mov eax, r12d
    imul eax, Program_size
    lea rdi, [rbx + rax]

    mov rcx, [rdi + Program.attribs]
    test rcx, rcx
    jz .freeVaryings
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree
.freeVaryings:
    mov eax, r12d
    imu eax, Program_size
    lea rdi, [rbx + rax]

    mov rcx, [rdi + Program.varyings]
    test rcx, rcx
    jz .progNext
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree

.progNext:
    inc r12d
    jmp .progLoop
.progPoolFree:
    mov rcx, rbx
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree
    mov qword [rel _cgxCoreState + CGXState.programPool], 0

.done:
    add rsp, 32
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreShaderFindById
; Input: ecx = shader id
; Output: rdi = slot ptr, or 0
; --------------------------------------------
_cgxCoreShaderFindById:
    push rbx
    push r12

    mov r12d, ecx
    test r12d, r12d
    jz .none

    mov rbx, [rel _cgxCoreState + CGXState.shaderPool]
    test rbx, rbx
    jz .none

    xor eax, eax

.scan:
    
