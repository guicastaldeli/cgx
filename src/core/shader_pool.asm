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
extern MessageBoxA
extern RtlCopyMemory

extern _cgxCoreState
extern CGXState

extern _parserState
extern _cgxCoreLexerTokenize
extern _cgxCoreParserParse
extern _cgxCoreAnalyze
extern _cgxCoreCompile
extern _cgxCoreVAOFindBound

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
global _cgxCoreBindAttribLocation
global _cgxCoreProgramCacheAttribSlots

MEM_COMMIT                      equ 0x00001000
MEM_RESERVE                     equ 0x00002000
MEM_RELEASE                     equ 0x00008000
PAGE_READWRITE                  equ 0x04

SHADER_SYMTAB_BYTES             equ CGX_MAX_SYMBOLS * Symbol_size           ; 5120
SHADER_INSTR_BYTES              equ CGX_MAX_INSTRUCTIONS * Instr_size       ; 24576
SHADER_INFO_LOG_BYTES           equ 1024                                    ; 1024
SHADER_SRC_BYTES                equ CGX_MAX_SOURCE_LEN                      ; 16384

PROG_UNIFORM_BYTES              equ CGX_MAX_UNIFORMS * Uniform_size         ; 64 * 40 = 2560
PROG_ATTRIB_BYTES               equ CGX_MAX_ATTRIBS * Symbol_size           ; 16 * 40 = 640
PROG_VARYING_BYTES              equ CGX_MAX_VARYINGS * Symbol_size          ; 8 * 40 = 320

section .data
    diag_tok                    db "lexer done", 0
    diag_par                    db "parser done", 0
    diag_ana                    db "analyze done", 0
    diag_cmp                    db "compile done", 0
    diag_after_copy             db "after instr copy", 0
    diag_after_symtab           db "after symtab", 0
    diag_before_log             db "before log write", 0
    diag_after_log              db "after log write", 0
    diag_link_a                 db "link: program found", 0
    diag_link_b                 db "link: both shader ids present", 0
    diag_link_c                 db "link: both shader ptrs found", 0
    diag_link_d                 db "link: vert compiled", 0
    diag_link_e                 db "link: frag compiled", 0
    diag_force                  db "force pass", 0
    diag_allocated              db "allocated tables", 0
    diag_before_loop            db "before vs loop", 0
    diag_vs_iter                db "vs iter", 0
    diag_vs_uniform             db "vs uniform", 0
    diag_vs_attrib              db "vs attrib", 0
    diag_vs_varying             db "vs varying", 0
    diag_bad_symtab             db "bad symtab", 0
    diag_good_symtab            db "good symtab", 0
    diag_attrib_enter           db "addAttrib: ENTER", 0
    diag_attrib_beforecopy      db "addAttrib: BEFORECOPY", 0
    diag_attrib_done            db "addAttrib: DONE", 0
    diag_fs_uniform             db "fs uniform", 0
    diag_fs_varying             db "fs varying", 0

section .bss
    _spTokens                   resb CGX_MAX_TOKENS * Token_size
    _spAst                      resb CGX_MAX_AST_NODES * ASTNode_size
    _spInstrs                   resb CGX_MAX_INSTRUCTIONS * Instr_size

section .text

_diag:
    sub rsp, 40
    xor ecx, ecx
    mov r8, rdx
    xor r9d, r9d
    call MessageBoxA
    add rsp, 40
    ret

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

    mov rdi, rax
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

.shaderLoop:
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

    mov rcx, [rdi + Shader.symbols]
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
    imul eax, Program_size
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
    cmp eax, CGX_MAX_SHADERS
    jge .none

    mov edx, eax
    imul edx, Shader_size    
    lea rdi, [rbx + rdx]

    cmp byte [rdi + Shader.inUse], 0
    je .next

    cmp dword [rdi + Shader.id], r12d
    je .found

.next:
    inc eax
    jmp .scan

.found:
    pop r12
    pop rbx
    ret

.none:
    xor rdi, rdi
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _cgxCoreProgramFindById
; Input: ecx = program id
; Output: rdi = slot ptr, or 0
; --------------------------------------------
_cgxCoreProgramFindById:
    push rbx
    push r12

    mov r12d, ecx
    test r12d, r12d
    jz .none

    mov rbx, [rel _cgxCoreState + CGXState.programPool]
    test rbx, rbx
    jz .none

    xor eax, eax

.scan:
    cmp eax, CGX_MAX_PROGRAMS
    jge .none

    mov edx, eax
    imul edx, Program_size
    lea rdi, [rbx + rdx]

    cmp byte [rdi + Program.inUse], 0
    je .next

    cmp dword [rdi + Program.id], r12d
    je .found

.next:
    inc eax
    jmp .scan

.found:
    pop r12
    pop rbx
    ret

.none:
    xor edi, edi
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _findFreeShaderSlot
; Output: rdi = free slot ptr, or 0
; --------------------------------------------
_findFreeShaderSlot:
    push rbx
    push r12

    mov rbx, [rel _cgxCoreState + CGXState.shaderPool]
    test rbx, rbx
    jz .none

    xor r12d, r12d

.scan:
    cmp r12d, CGX_MAX_SHADERS
    jge .none

    mov eax, r12d
    imul eax, Shader_size
    lea rdi, [rbx + rax]

    cmp byte [rdi + Shader.inUse], 0
    je .found

    inc r12d
    jmp .scan

.found:
    pop r12
    pop rbx
    ret

.none:
    xor edi, edi
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _findFreeProgramSlot
; Output: rdi = free slot ptr, or 0
; --------------------------------------------
_findFreeProgramSlot:
    push rbx
    push r12

    mov rbx, [rel _cgxCoreState + CGXState.programPool]
    test rbx, rbx
    jz .none

    xor r12d, r12d

.scan:
    cmp r12d, CGX_MAX_PROGRAMS
    jge .none

    mov eax, r12d
    imul eax, Program_size
    lea rdi, [rbx + rax]

    cmp byte [rdi + Program.inUse], 0
    je .found

    inc r12d
    jmp .scan

.found:
    pop r12
    pop rbx
    ret

.none:
    xor edi, edi
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _cgxCoreShaderCreate
; Input: ecx = shader type (CGX_VERTEX_SHADER / CGX_FRAGMENT_SHADER)
; Output: eax = shader id (>0), 0 on fail
; --------------------------------------------
_cgxCoreShaderCreate:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 32

    mov r12d, ecx

    ; Validate type
    cmp r12d, CGX_VERTEX_SHADER
    je .ok
    cmp r12d, CGX_FRAGMENT_SHADER
    je .ok
    jmp .fail

.ok:
    call _findFreeShaderSlot
    test rdi, rdi
    jz .fail
    mov rbx, rdi

    ; Clear slot
    push rdi
    mov rcx, Shader_size
    xor eax, eax
    rep stosb
    pop rdi

    ; Fill in fields
    mov eax, [rel _cgxCoreState + CGXState.nextShaderId]
    mov [rbx + Shader.id], eax
    mov [rbx + Shader.type], r12d
    mov byte [rbx + Shader.inUse], 1
    mov byte [rbx + Shader.compileStatus], 0
    mov qword [rbx + Shader.source], 0
    mov dword [rbx + Shader.sourceLen], 0
    mov dword [rbx + Shader.instrCount], 0
    mov qword [rbx + Shader.instr], 0
    mov qword [rbx + Shader.infoLog], 0
    mov dword [rbx + Shader.symbolCount], 0
    mov qword [rbx + Shader.symbols], 0

    inc dword [rel _cgxCoreState + CGXState.nextShaderId]
    inc dword [rel _cgxCoreState + CGXState.shaderCount]

    mov eax, [rbx + Shader.id]
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 32
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreShaderSource
; Input: ecx = shader id, rdx = source ptr, r8d = length
;       (length = 0 -> strlen)
; Output: eax = 1 ok, 0 fail
; Allocates a source buffer on first call, copies in the text.
; --------------------------------------------
_cgxCoreShaderSource:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 48

    mov r12d, ecx
    mov r13, rdx
    mov r14d, r8d

    test r13, r13
    jz .fail

    ; Find slot
    mov ecx, r12d
    call _cgxCoreShaderFindById
    test rdi, rdi
    jz .fail
    mov rbx, rdi

    ; If length is 0, compute strlen
    test r14d, r14d
    jnz .haveLen
    xor r14d, r14d

.lenLoop:
    cmp byte [r13 + r14], 0
    je .haveLen
    inc r14d
    cmp r14d, CGX_MAX_SOURCE_LEN
    jl .lenLoop
    jmp .fail

.haveLen:
    ; Allocate source buffer if not present
    mov rcx, [rbx + Shader.source]
    test rcx, rcx
    jnz .copy

    xor rcx, rcx
    mov edx, SHADER_SRC_BYTES
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail
    mov [rbx + Shader.source], rax

.copy:
    ; Copy source + null terminator
    mov rcx, [rbx + Shader.source]
    mov rdx, r13
    mov r8d, r14d
    call RtlCopyMemory

    ; Null-terminate (guard against overflow...)
    mov rcx, [rbx + Shader.source]
    cmp r14, CGX_MAX_SOURCE_LEN - 1
    jge .truncated
    mov byte [rcx + r14], 0
    jmp .storeLen

.truncated:
    mov byte [rcx + CGX_MAX_SOURCE_LEN - 1], 0
    mov r14d, CGX_MAX_SOURCE_LEN - 1

.storeLen:
    mov [rbx + Shader.sourceLen], r14d

    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 48
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreShaderCompile
; Input: ecx = shader id
; Output: eax = 1 ok, 0 fail
; Runs lexer -> parser -> analyzer -> compiler.
; Copies the symbol table and bytecode into the shader.
; --------------------------------------------
_cgxCoreShaderCompile:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 56

    mov r12d, ecx
    mov [rbp - 72], r12d        ; save shader id

    ; Find shader
    mov ecx, r12d
    call _cgxCoreShaderFindById
    test rdi, rdi
    jz .fail
    mov rbx, rdi

    ; Must have source
    mov r13, [rbx + Shader.source]
    test r13, r13
    jz .fail

    ; Ensure infoLog exists
    mov rcx, [rbx + Shader.infoLog]
    test rcx, rcx
    jnz .haveLog

    xor rcx, rcx
    mov edx, SHADER_INFO_LOG_BYTES
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail
    mov [rbx + Shader.infoLog], rax

    ; Clear
    mov rdi, rax
    mov rcx, SHADER_INFO_LOG_BYTES / 8
    xor eax, eax
    rep stosq

.haveLog:
    ; Free any previous compile artifacts
    mov rcx, [rbx + Shader.instr]
    test rcx, rcx
    jz .noOldInstr
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree
    mov qword [rbx + Shader.instr], 0

.noOldInstr:
    mov rcx, [rbx + Shader.symbols]
    test rcx, rcx
    jz .noOldSyms
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree
    mov qword [rbx + Shader.symbols], 0
.noOldSyms:
    ; Reset compile status
    mov byte [rbx + Shader.compileStatus], 0

    ; Tokenize
    mov rcx, r13                    ; source
    lea rdx, [rel _spTokens]
    mov r8d, CGX_MAX_TOKENS
    call _cgxCoreLexerTokenize
    test eax, eax
    jz .fail
    mov r14d, eax                   ; token count
    lea rdx, [rel diag_tok]
    call _diag

    ; Parse
    lea rcx, [rel _spTokens]
    mov edx, r14d
    mov r8d, [rbx + Shader.type]
    lea r9, [rel _spAst]
    call _cgxCoreParserParse
    test eax, eax
    jz .fail
    mov r15d, eax                   ; AST count
    lea rdx, [rel diag_par]
    call _diag

    ; Analyze
    lea rcx, [rel _spAst]
    mov edx, r15d
    lea r8, [rel _spTokens]
    call _cgxCoreAnalyze
    test eax, eax
    jz .fail
    lea rdx, [rel diag_ana]
    call _diag

    ; Compile
    lea rcx, [rel _spAst]
    mov edx, r15d
    lea r8, [rel _spTokens]
    lea r9, [rel _spInstrs]
    mov qword [rsp + 32], CGX_MAX_INSTRUCTIONS
    call _cgxCoreCompile
    test eax, eax
    jz .fail
    cmp eax, CGX_MAX_INSTRUCTIONS
    ja .fail
    mov r14d, eax                   ; instruction count
    lea rdx, [rel diag_cmp]
    call _diag

    ; Reload
    mov ecx, [rbp - 72]
    call _cgxCoreShaderFindById
    test rdi, rdi
    jz .fail
    mov rbx, rdi

    ; Allocate instruction buffer and copy
    xor rcx, rcx
    mov edx, SHADER_INSTR_BYTES
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail
    mov [rbx + Shader.instr], rax

    mov rcx, rax
    lea rdx, [rel _spInstrs]
    mov r8d, r14d
    imul r8, Instr_size
    call RtlCopyMemory

    lea rdx, [rel diag_after_copy]
    call _diag

    mov [rbx + Shader.instrCount], r14d

    ; Reload
    mov ecx, [rbp - 72]
    call _cgxCoreShaderFindById
    test rdi, rdi
    jz .fail
    mov rbx, rdi

    ; Allocate symbol table and copy
    xor rcx, rcx
    mov edx, SHADER_SYMTAB_BYTES
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail
    mov [rbx + Shader.symbols], rax

    mov rcx, rax
    mov rdx, [rel _parserState + ParseState.symtab]
    test rdx, rdx
    jz .noSyms

    mov rcx, rax
    mov r8d, SHADER_SYMTAB_BYTES
    call RtlCopyMemory
    jmp .symtabDone

.noSyms:
    mov rdi, rax
    mov rcx, SHADER_SYMTAB_BYTES / 8
    xor eax, eax
    rep stosq

.symtabDone:
    ; Reload
    mov ecx, [rbp - 72]
    call _cgxCoreShaderFindById
    test rdi, rdi
    jz .fail
    mov rbx, rdi

    mov dword [rbx + Shader.symbolCount], CGX_MAX_SYMBOLS

    ; Success
    mov byte [rbx + Shader.compileStatus], 1

    ; Write log
    mov rdi, [rbx + Shader.infoLog]
    test rdi, rdi
    jz .skipLogWrite
    mov byte [rdi], 0

.skipLogWrite:
    lea rdx, [rel diag_after_log]
    call _diag

    mov eax, 1
    jmp .done

.fail:
    ; Write a failure log (first char 'E')
    mov rdi, [rbx + Shader.infoLog]
    test rdi, rdi
    jz .noLog
    mov byte [rdi], 'E'
    mov byte [rdi + 1], 0

.noLog:
    mov byte [rbx + Shader.compileStatus], 0
    xor eax, eax

.done:
    add rsp, 56
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreShaderDelete
; Input: ecx = shader id
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreShaderDelete:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 32

    mov r12d, ecx

    mov ecx, r12d
    call _cgxCoreShaderFindById
    test rdi, rdi
    jz .fail
    mov rbx, rdi

    ; Free owned buffers
    mov rcx, [rbx + Shader.source]
    test rcx, rcx
    jz .f1
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree

.f1:
    mov rcx, [rbx + Shader.instr]
    test rcx, rcx
    jz .f2
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree
.f2:
    mov rcx, [rbx + Shader.symbols]
    test rcx, rcx
    jz .f3
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree
.f3:
    mov rcx, [rbx + Shader.infoLog]
    test rcx, rcx
    jz .markFree
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree

.markFree:
    mov byte [rbx + Shader.inUse], 0
    dec dword [rel _cgxCoreState + CGXState.shaderCount]

    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 32
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreShaderGetInfoLog
; Input: ecx = shader id
; Output: rax = info log ptr, or 0
; --------------------------------------------
_cgxCoreShaderGetInfoLog:
    push rbx
    mov ecx, ecx
    call _cgxCoreShaderFindById
    test rdi, rdi
    jz .none
    mov rax, [rdi + Shader.infoLog]
    pop rbx
    ret

.none:
    xor eax, eax
    pop rbx
    ret

; --------------------------------------------
; _cgxCoreProgramCreate
; Output: eax = progam id (>0), 0 on fail
; --------------------------------------------
_cgxCoreProgramCreate:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 32

    call _findFreeProgramSlot
    test rdi, rdi
    jz .fail
    mov rbx, rdi

    ; Clear slot
    push rdi
    mov rcx, Program_size
    xor eax, eax
    rep stosb
    pop rdi

    mov eax, [rel _cgxCoreState + CGXState.nextProgramId]
    mov [rbx + Program.id], eax
    mov byte [rbx + Program.inUse], 1
    mov byte [rbx + Program.linkStatus], 0
    mov dword [rbx + Program.vertShader], 0
    mov dword [rbx + Program.fragShader], 0
    mov dword [rbx + Program.uniformCount], 0
    mov qword [rbx + Program.uniforms], 0
    mov dword [rbx + Program.attribCount], 0
    mov qword [rbx + Program.attribs], 0
    mov dword [rbx + Program.varyingCount], 0
    mov qword [rbx + Program.varyings], 0

    inc dword [rel _cgxCoreState + CGXState.nextProgramId]
    inc dword [rel _cgxCoreState + CGXState.programCount]

    mov eax, [rbx + Program.id]
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 32
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxoreProgramAttach
; Input: ecx = program id, edx = shader id
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreProgramAttach:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 32

    mov r12d, ecx
    mov r13d, edx

    mov ecx, r12d
    call _cgxCoreProgramFindById
    test rdi, rdi
    jz .fail
    mov rbx, rdi

    ; Look up shader type
    mov ecx, r13d
    call _cgxCoreShaderFindById
    test rdi, rdi
    jz .fail

    mov eax, [rdi + Shader.type]

    cmp eax, CGX_VERTEX_SHADER          ; VERTEX
    je .attachVert
    cmp eax, CGX_FRAGMENT_SHADER        ; FRAG
    je .attachFrag
    jmp .fail

.attachVert:
    mov [rbx + Program.vertShader], r13d
    jmp .ok
.attachFrag:
    mov [rbx + Program.fragShader], r13d

.ok:
    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 32
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreProgramLink
; Input: ecx = progam id
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreProgramLink:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 88

    mov r12d, ecx

    mov ecx, r12d
    call _cgxCoreProgramFindById
    test rdi, rdi
    jz .fail
    mov rbx, rdi

    mov byte [rbx + Program.linkStatus], 0

    lea rdx, [rel diag_link_a]
    call _diag

    ; Both shaders must be present
    mov r13d, [rbx + Program.vertShader]
    test r13d, r13d
    jz .fail
    mov r14d, [rbx + Program.fragShader]
    test r14d, r14d
    jz .fail

    lea rdx, [rel diag_link_b]
    call _diag

    ; Look them up
    mov ecx, r13d
    call _cgxCoreShaderFindById
    test rdi, rdi
    jz .fail
    mov r13, rdi                    ; vertex shader ptr

    mov ecx, r14d
    call _cgxCoreShaderFindById
    test rdi, rdi
    jz .fail
    mov [rbp - 64], rdi             ; fragment shader ptr

    lea rdx, [rel diag_link_c]
    call _diag

    ; Allocate uniform table
    mov rcx, [rbx + Program.uniforms]
    test rcx, rcx
    jz .allocUniforms
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree
    mov qword [rbx + Program.uniforms], 0

    ; Both must be compiled
    cmp byte [r13 + Shader.compileStatus], 0
    je .fail
    lea rdx, [rel diag_link_d]
    call _diag
    mov rax, [rbp - 64]
    cmp byte [rax + Shader.compileStatus], 0
    je .fail

    lea rdx, [rel diag_link_e]
    call _diag

    mov rcx, [rbx + Program.uniforms]
    test rcx, rcx
    jz .allocUniforms
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree
    mov qword [rbx + Program.uniforms], 0

.allocUniforms:
    xor rcx, rcx
    mov edx, PROG_UNIFORM_BYTES
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail
    mov [rbx + Program.uniforms], rax

    ; Allocate attrib table
    xor rcx, rcx
    mov edx, PROG_ATTRIB_BYTES
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail
    mov [rbx + Program.attribs], rax

    ; Allocate varing table
    xor rcx, rcx
    mov edx, PROG_VARYING_BYTES
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail
    mov [rbx + Program.varyings], rax

    lea rdx, [rel diag_allocated]
    call _diag

    ; Walk vertex shader symbols
    ; uniforms -> uniform table
    ; attribs -> attrib table
    ; varyings -> varying table
    mov r14, [r13 + Shader.symbols]         ; vertex symbol table
    xor ecx, ecx                            ; index

    mov rax, r14
    cmp rax, 0x10000
    jb .badSymtab

    lea rdx, [rel diag_good_symtab]
    call _diag
    xor ecx, ecx
    jmp .vsLoop

.badSymtab:
    lea rdx, [rel diag_bad_symtab]
    call _diag
    jmp .vsDone

.vsLoop:
    cmp ecx, CGX_MAX_SYMBOLS
    jge .vsDone

    ; symbol ptr
    mov eax, ecx
    imul eax, Symbol_size
    lea rsi, [r14 + rax]
    mov [rbp - 56], rsi                     ; save symbol ptr
    mov [rbp - 68], ecx                     ; save index

    movzx eax, byte [rsi + Symbol.type]
    test al, al
    jz .vsNext

    movzx eax, byte [rsi + Symbol.qualifier]

    cmp eax, CGX_QUAL_UNIFORM           ; UNIFORM
    je .vsUniform
    cmp eax, CGX_QUAL_ATTRIBUTE        ; ATTRIBUTE
    je .vsAttrib
    cmp eax, CGX_QUAL_VARYING           ; VARYING
    je .vsVarying
    jmp .vsNext

.vsUniform:
    mov rsi, [rbp - 56]
    mov ecx, r12d

    push rcx
    push rsi
    lea rdx, [rel diag_vs_uniform]
    call _diag
    pop rsi
    pop rcx

    call _addUniformFromSymbol
    jmp .vsNext
.vsAttrib:
    mov rsi, [rbp - 56]
    mov ecx, r12d
    
    push rcx
    push rsi
    lea rdx, [rel diag_vs_attrib]
    call _diag
    pop rsi
    pop rcx

    call _addAttribFromSymbol
    jmp .vsNext
.vsVarying:
    mov rsi, [rbp - 56]
    mov ecx, r12d

    push rcx
    push rsi
    lea rdx, [rel diag_vs_varying]
    call _diag
    pop rsi
    pop rcx

    call _addVaryingFromSymbol
    jmp .vsNext

.vsNext:
    mov ecx, [rbp - 68]
    inc ecx
    jmp .vsLoop
.vsDone:
    ; Walk fragment shader symbols
    mov rax, [rbp - 64]
    test rax, rax
    jz .fsDone
    mov r15, [rax + Shader.symbols]
    test r15, r15
    jz .fsDone
    xor ecx, ecx

.fsLoop:
    cmp ecx, CGX_MAX_SYMBOLS
    jge .fsDone

    mov eax, ecx
    imul eax, Symbol_size
    lea rsi, [r15 + rax]
    mov [rbp - 56], rsi
    mov [rbp - 68], ecx

    movzx eax, byte [rsi + Symbol.type]
    test al, al
    jz .fsNext

    movzx eax, byte [rsi + Symbol.qualifier]

    cmp eax, CGX_QUAL_UNIFORM       ; UNIFORM
    je .fsUniform
    cmp eax, CGX_QUAL_VARYING       ; VARYING
    je .fsVarying
    jmp .fsNext

.fsUniform:
    mov rsi, [rbp - 56]
    mov ecx, r12d

    push rcx
    push rsi
    lea rdx, [rel diag_fs_uniform]
    call _diag
    pop rsi
    pop rcx

    call _mergeUniformFromSymbol
    jmp .fsNext
.fsVarying:
    mov rsi, [rbp - 56]
    mov ecx, r12d

    push rcx
    push rsi
    lea rdx, [rel diag_fs_varying]
    call _diag
    pop rsi
    pop rcx

    call _mergeVaryingFromSymbol
    jmp .fsNext

.fsNext:
    mov ecx, [rbp - 68]
    inc ecx
    jmp .fsLoop
.fsDone:
    ; Assign external locations
    ; Uniforms get location = 0, 1, 2 ...
    ; Atttribs get location = 0, 1, 2 ...
    mov rdi, [rbx + Program.uniforms]
    mov ecx, [rbx + Program.uniformCount]
    xor eax, eax

.locUniform:
    cmp eax, ecx
    jge .locAttribsStart

    mov edx, eax
    imul edx, Uniform_size
    mov [rdi + rdx + Symbol.location], eax

    inc eax
    jmp .locUniform
.locAttribsStart:
    mov rdi, [rbx + Program.attribs]
    mov ecx, [rbx + Program.attribCount]
    xor eax, eax
.locAttrib:
    cmp eax, ecx
    jge .linkOk

    mov edx, eax
    imul edx, Symbol_size
    mov [rdi + rdx + Symbol.location], eax

    inc eax
    jmp .locAttrib

.linkOk:
    mov byte [rbx + Program.linkStatus], 1
    mov eax, 1
    jmp .done

.fail:
    mov byte [rbx + Program.linkStatus], 0
    xor eax, eax

.done:
    add rsp, 88
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _addUniformFromSymbol
; Input: rsi = Symbol ptr, ecx = program id
; Looks up the program, appends a Uniform entry
; with vertReg = symbol.reg, fragReg = 0xFF.
; --------------------------------------------
_addUniformFromSymbol:
    push rbx
    push r12
    push r13
    push r14

    mov r13, rsi
    mov r14d, ecx

    mov ecx, r14d
    call _cgxCoreProgramFindById
    test rdi, rdi
    jz .done
    mov rbx, rdi

    mov r12d, [rbx + Program.uniformCount]
    cmp r12d, CGX_MAX_UNIFORMS
    jge .done

    mov rdi, [rbx + Program.uniforms]
    mov eax, r12d
    imul eax, Uniform_size
    add rdi, rax
    mov r12, rdi

    ; Copy name (32 bytes)
    lea rsi, [r13 + Symbol.name]
    mov ecx, 32

.copyName:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec ecx
    jnz .copyName

    ; rdi now points at .type
    mov al, [r13 + Symbol.type]
    mov [r12 + Uniform.type], al
    mov al, [r13 + Symbol.reg]
    mov [r12 + Uniform.vertReg], al
    mov byte [r12 + Uniform.fragReg], 0xFF
    mov dword [r12 + Uniform.location], -1

    inc dword [rbx + Program.uniformCount]

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _addAttribFromSymbol
; Same shape as _addUniformFromSymbol but writes into
; the attrib table.
; --------------------------------------------
_addAttribFromSymbol:
    push rbx
    push r12
    push r13
    push r14

    mov r13, rsi
    mov r14d, ecx

    mov ecx, r14d
    call _cgxCoreProgramFindById
    test rdi, rdi
    jz .done
    mov rbx, rdi

    mov r12d, [rbx + Program.attribCount]
    cmp r12d, CGX_MAX_ATTRIBS
    jge .done

    mov rdi, [rbx + Program.attribs]
    mov eax, r12d
    imul eax, Symbol_size
    add rdi, rax
    mov r12, rdi

    lea rsi, [r13 + Symbol.name]
    mov ecx, 32

.copyName:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec ecx
    jnz .copyName

    mov al, [r13 + Symbol.type]
    mov [r12 + Symbol.type], al
    mov al, [r13 + Symbol.qualifier]
    mov [r12 + Symbol.qualifier], al
    mov al, [r13 + Symbol.reg]
    mov [r12 + Symbol.reg], al
    mov dword [r12 + Symbol.location], -1

    inc dword [rbx + Program.attribCount]

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _addVaryingFromSymbol
; --------------------------------------------
_addVaryingFromSymbol:
    push rbx
    push r12
    push r13
    push r14
    
    mov r13, rsi
    mov r14d, ecx

    mov ecx, r14d
    call _cgxCoreProgramFindById
    test rdi, rdi
    jz .done
    mov rbx, rdi

    mov r12d, [rbx + Program.varyingCount]
    cmp r12d, CGX_MAX_VARYINGS
    jge .done

    mov rdi, [rbx + Program.varyings]
    mov eax, r12d
    imul eax, Symbol_size
    add rdi, rax
    mov r12, rdi

    lea rsi, [r13 + Symbol.name]
    mov ecx, 32

.copyName:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec ecx
    jnz .copyName

    mov al, [r13 + Symbol.type]
    mov [r12 + Symbol.type], al
    mov al, [r13 + Symbol.qualifier]
    mov [r12 + Symbol.qualifier], al
    mov al, [r13 + Symbol.reg]
    mov [r12 + Symbol.reg], al
    mov dword [r12 + Symbol.location], -1

    inc dword [rbx + Program.varyingCount]

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _mergeUniformFromSymbol
; Fragment shader uniform: if a matching name already
; exists in the uniform table, fill in fragReg.
; Otherwise, append a new entry with fragReg = symbol.reg
; and vertReg = 0xFF
; --------------------------------------------
_mergeUniformFromSymbol:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r13, rsi
    mov r14d, ecx

    mov ecx, r14d
    call _cgxCoreProgramFindById
    test rdi, rdi
    jz .done
    mov rbx, rdi

    ; Search the uniform table for a name match
    mov r15, [rbx + Program.uniforms]
    mov r12d, [rbx + Program.uniformCount]
    xor r10d, r10d

.search:
    cmp r10d, r12d
    jge .notFound

    mov eax, r10d
    imul eax, Uniform_size
    lea rdi, [r15 + rax]
    lea rsi, [r13 + Symbol.name]
    call _strcmp32
    jz .match

    inc r10d
    jmp .search

.match:
    mov eax, r10d
    imul eax, Uniform_size
    lea rdi, [r15 + rax]
    mov al, [r13 + Symbol.reg]
    mov [rdi + Uniform.fragReg], al
    jmp .done

.notFound:
    ; Append as a fragment-only uniform
    mov r12d, [rbx + Program.uniformCount]
    cmp r12d, CGX_MAX_UNIFORMS
    jge .done

    mov rdi, [rbx + Program.uniforms]
    mov eax, r12d
    imul eax, Uniform_size
    add rdi, rax
    mov r12, rdi

    lea rsi, [r13 + Symbol.name]
    mov ecx, 32

.copyName:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec ecx
    jnz .copyName

    mov al, [r13 + Symbol.type]
    mov [r12 + Uniform.type], al
    mov byte [r12 + Uniform.vertReg], 0xFF
    mov al, [r13 + Symbol.reg]
    mov [r12 + Uniform.fragReg], al
    mov dword [r12 + Uniform.location], -1

    inc dword [rbx + Program.uniformCount]

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _mergeVaryingFromSymbol
; Same shape as _mergeUniformFromSymbol but for varyings.
; --------------------------------------------
_mergeVaryingFromSymbol:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r13, rsi
    mov r14d, ecx

    mov ecx, r14d
    call _cgxCoreProgramFindById
    test rdi, rdi
    jz .done
    mov rbx, rdi

    mov r15, [rbx + Program.varyings]
    mov r12d, [rbx + Program.varyingCount]
    xor r10d, r10d

.search:
    cmp r10d, r12d
    jge .notFound

    mov eax, r10d
    imul eax, Symbol_size
    lea rdi, [r15 + rax]
    lea rsi, [r13 + Symbol.name]
    call _strcmp32
    jz .match

    inc r10d
    jmp .search

.match:
    mov eax, r10d
    imul eax, Symbol_size
    lea rdi, [r15 + rax]
    mov al, [r13 + Symbol.reg]
    mov [rdi + Symbol.reg], al
    jmp .done

.notFound:
    ; Append as a fragment-only varying
    mov r12d, [rbx + Program.varyingCount]
    cmp r12d, CGX_MAX_VARYINGS
    jge .done

    mov rdi, [rbx + Program.varyings]
    mov eax, r12d
    imul eax, Symbol_size
    add rdi, rax
    mov r12, rdi

    lea rsi, [r13 + Symbol.name]
    mov ecx, 32

.copyName:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec ecx
    jnz .copyName

    mov al, [r13 + Symbol.type]
    mov [r12 + Symbol.type], al
    mov al, [r13 + Symbol.qualifier]
    mov [r12 + Symbol.qualifier], al
    mov al, [r13 + Symbol.reg]
    mov [r12 + Symbol.reg], al
    mov qword [r12 + Symbol.location], -1

    inc dword [rbx + Program.varyingCount]

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _cgxCoreProgramUse
; Input: ecx = program id (0 = fixed function)
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreProgramUse:
    test ecx, ecx
    jz .useFixed

    push rcx
    call _cgxCoreProgramFindById
    test rdi, rdi
    jz .failPop
    pop rcx

    mov [rel _cgxCoreState + CGXState.boundProgram],ecx
    mov eax, 1
    ret

.useFixed:
    mov dword [rel _cgxCoreState + CGXState.boundProgram], 0
    mov eax, 1
    ret

.failPop:
    pop rcx
    xor eax, eax
    ret

; --------------------------------------------
; _cgxCoreProgramDelete
; Input: ecx = program id
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreProgramDelete:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 32

    call _cgxCoreProgramFindById
    test rdi, rdi
    jz .fail
    mov rbx, rdi

    mov rcx, [rbx + Program.uniforms]
    test rcx, rcx
    jz .f1
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree

.f1:
    mov rcx, [rbx + Program.attribs]
    test rcx, rcx
    jz .f2
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree
.f2:
    mov rcx, [rbx + Program.varyings]
    test rcx, rcx
    jz .markFree
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree

.markFree:
    mov byte [rbx + Program.inUse], 0
    dec dword [rel _cgxCoreState + CGXState.programCount]

    ; If this program was bound, drop back to fixed-function
    mov eax, [rbx + Program.id]
    cmp eax, [rel _cgxCoreState + CGXState.boundProgram]
    jne .ok
    mov dword [rel _cgxCoreState + CGXState.boundProgram], 0

.ok:
    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 32
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreGetUniformLocation
; Input: ecx = program id, rdx = name ptr
; Output: eax = location (>= 0), -1 on fail
; --------------------------------------------
_cgxCoreGetUniformLocation:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, ecx
    mov r13, rdx

    test r13, r13
    jz .fail

    mov ecx, r12d
    call _cgxCoreProgramFindById
    test rdi, rdi
    jz .fail
    mov rbx, rdi

    mov r14, [rbx + Program.uniforms]
    mov r12d, [rbx + Program.uniformCount]
    xor r10d, r10d

.search:
    cmp r10d, r12d
    jge .fail

    mov eax, r10d
    imul eax, Uniform_size
    lea rdi, [r14 + rax]        ; entry
    mov rsi, r13                ; query name
    call _strcmp32
    jz .found

    inc r10d
    jmp .search

.found:
    mov eax, r10d
    imul eax, Uniform_size
    lea rdi, [r14 + rax]
    mov eax, [rdi + Uniform.location]
    jmp .done

.fail:
    mov eax, -1

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _cgxCoreGetAttribLocation
; Input: ecx = program id, edx = name ptr
; Output: eax = location (>= 0), -1 on fail
; --------------------------------------------
_cgxCoreGetAttribLocation:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, ecx
    mov r13, rdx

    test r13, r13
    jz .fail

    mov ecx, r12d
    call _cgxCoreProgramFindById
    test rdi, rdi
    jz .fail
    mov rbx, rdi

    mov r14, [rbx + Program.attribs]
    mov r12d, [rbx + Program.attribCount]
    xor r10d, r10d

.search:
    cmp r10d, r12d
    jge .fail

    mov eax, r10d
    imul eax, Symbol_size
    lea rdi, [r14 + rax]        ; entry
    mov rsi, r13                ; query name
    call _strcmp32
    jz .found

    inc r10d
    jmp .search

.found:
    mov eax, r10d
    imul eax, Symbol_size
    lea rdi, [r14 + rax]
    mov eax, [rdi + Symbol.location]
    jmp .done

.fail:
    mov eax, -1

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _storeUniformRegs
; Input: ecx = program id, rdx = name ptr, xmm0..xmm3 = values
; Looks up the linked uniform, writes values into both VMs
; register files at vertReg and fragReg.
; --------------------------------------------
_storeUniformRegs:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 80

    ; Save xmm values to stack
    movaps [rbp - 32], xmm0
    movaps [rbp - 48], xmm1
    movaps [rbp - 64], xmm2
    movaps [rbp - 80], xmm3

    mov r12d, ecx
    mov r13, rdx

    test r13, r13
    jz .done

    mov ecx, r12d
    call _cgxCoreProgramFindById
    test rdi, rdi
    jz .done
    mov rbx, rdi

    mov r14, [rbx + Program.uniforms]
    mov r12d, [rbx + Program.uniformCount]
    xor r10d, r10d

.search:
    cmp r10d, r12d
    jge .done

    mov eax, r10d
    imul eax, Uniform_size
    lea rdi, [r14 + rax]
    mov rsi, r13
    call _strcmp32
    jz .found

    inc r10d
    jmp .search

.found:
    mov eax, r10d
    imul eax, Uniform_size
    lea rdi, [r14 + rax]

    ; vertReg
    movzx ecx, byte [rdi + Uniform.vertReg]
    cmp ecx, 0xFF
    jge .frag
    ; vertVM.regs + vertReg * 16
    mov eax, ecx
    shl eax, 4
    lea rsi, [rel _cgxCoreState + CGXState.vertVM + VMState.regs]
    add rsi, rax
    unpcklps xmm0, xmm1
    unpcklps xmm2, xmm3
    movlhps xmm0, xmm2
    movups [rsi], xmm0

.frag:
    movzx ecx, byte [rdi + Uniform.fragReg]
    cmp ecx, 0xFF
    je .done
    mov eax, ecx
    shl eax, 4
    lea rsi, [rel _cgxCoreState + CGXState.fragVM + VMState.regs]
    add rsi, rax
    movaps xmm0, [rbp - 32]
    movaps xmm1, [rbp - 48]
    movaps xmm2, [rbp - 64]
    movaps xmm3, [rbp - 80]
    unpcklps xmm0, xmm1
    unpcklps xmm2, xmm3
    movlhps xmm0, xmm2
    movups [rsi], xmm0

.done:
    add rsp, 80
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreUniform1f
; Input: ecx = program id, rdx = name ptr, xmm0 = f
; --------------------------------------------
_cgxCoreUniform1f:
    ; Broadcast f into all 4 components;
    ; the symbols reg layout will get 16 bytes written.
    shufps xmm0, xmm0, 0x00
    movaps xmm1, xmm0
    movaps xmm2, xmm0
    movaps xmm3, xmm0
    jmp _storeUniformRegs

; --------------------------------------------
; _cgxCoreUniform2f
; Input: ecx = program id, rdx = name ptr, xmm0 = x, xmm1 = y
; --------------------------------------------
_cgxCoreUniform2f:
    movaps xmm2, xmm0
    movaps xmm3, xmm1
    jmp _storeUniformRegs

; --------------------------------------------
; _cgxCoreUniform3f
; Input: ecx = program id, rdx = name ptr, xmm0..xmm2 = x,y,z
; --------------------------------------------
_cgxCoreUniform3f:
    xorps xmm3, xmm3
    jmp _storeUniformRegs

; --------------------------------------------
; _cgxCoreUniform4f
; Input: ecx = program id, rdx = name ptr, xmm0..xmm3
; --------------------------------------------
_cgxCoreUniform4f:
    jmp _storeUniformRegs

; --------------------------------------------
; _cgxCoreUniform1i
; Input: ecx = program id, rdx = name ptr, r8d = int
; Convert int -> float, then delegate to Uniform1f
; --------------------------------------------
_cgxCoreUniform1i:
    cvtsi2ss xmm0, r8d
    jmp _cgxCoreUniform1f

; --------------------------------------------
; _cgxCoreUniform3fv
; Input: ecx = program id, rdx = name ptr, r8 = ptr to 3 floats
; --------------------------------------------
_cgxCoreUniform3fv:
    test r8, r8
    jz .skip
    movss xmm0, [r8 + 0]
    movss xmm1, [r8 + 4]
    movss xmm2, [r8 + 8]
    xorps xmm3, xmm3
    jmp _storeUniformRegs

.skip:
    ret

; --------------------------------------------
; _cgxCoreUniform4fv
; Input: ecx = program id, rdx = name ptr, r8 = ptr to 4 floats
; --------------------------------------------
_cgxCoreUniform4fv:
    test r8, r8
    jz .skip
    movss xmm0, [r8 + 0]
    movss xmm1, [r8 + 4]
    movss xmm2, [r8 + 8]
    movss xmm3, [r8 + 12]
    jmp _storeUniformRegs

.skip:
    ret

; --------------------------------------------
; _cgxCoreUniformMatrix4fv
; Input: ecx = program id, rdx = name ptr, r8 = ptr to 16 floats
; Writes 16 floats into the 4 consecutive registers starting
; at the uniforms assigned register. In the register file
; each register holds one vec4. Following GLSL column-major convention,
; the four columns of the matrix land in four consecutive registers.
; --------------------------------------------
_cgxCoreUniformMatrix4fv:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 56

    ; Save inputs up front
    mov r12d, ecx               ; program id
    mov r13, rdx                ; name ptr
    mov [rbp - 48], r8          ; source ptr (16 floats)

    ; Bail on null name or null source
    test r13, r13
    jz .done
    cmp qword [rbp - 48], 0
    je .done

    ; Find the program
    mov ecx, r12d
    call _cgxCoreProgramFindById
    test rdi, rdi
    jz .done
    mov rbx, rdi                ; program ptr

    ; Search the uniform table for the name
    mov r14, [rbx + Program.uniforms]
    mov r15d, [rbx + Program.uniformCount]
    xor r10d, r10d                ; index

.search:
    cmp r10d, r15d
    jge .done

    mov eax, r10d
    imul eax, Uniform_size
    lea rdi, [r14 + rax]
    mov rsi, r13
    call _strcmp32
    jz .found

    inc r10d
    jmp .search

.found:
    mov eax, r10d
    imul eax, Uniform_size
    lea rdi, [r14 + rax]
    mov [rbp - 56], rdi

    ; Write to the vertex VM if vertReg != 0xFF
    movzx ecx, byte [rdi + Uniform.vertReg]
    cmp ecx, 0xFF
    je .fragSide

    ; dest = &_cgxCoreState.vertVM.regs + vertReg * 16
    mov eax, ecx
    shl eax, 4
    lea rsi, [rel _cgxCoreState + CGXState.vertVM + VMState.regs]
    add rsi, rax

    mov rdi, rsi
    mov rsi, [rbp - 48]             ; reload source ptr
    call _copy16Floats

.fragSide:
    ; Write to the fragment VM if frag != 0xFF
    mov rdi, [rbp - 56]             ; reload entry ptr
    movzx ecx, byte [rdi + Uniform.fragReg]
    cmp ecx, 0xFF
    je .done

    mov eax, ecx
    shl eax, 4
    lea rsi, [rel _cgxCoreState + CGXState.fragVM + VMState.regs]
    add rsi, rax

    mov rdi, rsi
    mov rsi, [rbp - 48]             ; reload source ptr
    call _copy16Floats

.done:
    add rsp, 56
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _copy16Floats
; Copies 16 consecutive floats (64 bytes) from src to dst.
; Input: rdi = dst, rsi = src
; Uses SSE aligned loads where possible; falls back to
; unaligned movups to avoid 16-byte alignment requirements.
; --------------------------------------------
_copy16Floats:
    movups xmm0, [rsi + 0]
    movups xmm1, [rsi + 16]
    movups xmm2, [rsi + 32]
    movups xmm3, [rsi + 48]
    movups [rdi + 0], xmm0
    movups [rdi + 16], xmm1
    movups [rdi + 32], xmm2
    movups [rdi + 48], xmm3
    ret

; --------------------------------------------
; _strcmp32
; Input: rdi = a, rsi = b
; Output: ZF=1 if equal up to 32 bytes or null terminator,
; ZF=0 otherwise
; Clobbers: rax, rcx
; --------------------------------------------
_strcmp32:
    mov ecx,32

.loop:
    mov al, [rdi]
    cmp al, [rsi]
    jne .no
    test al, al
    jz .yes
    inc rdi
    inc rsi
    dec ecx
    jnz .loop

.yes:
    xor eax, eax
    ret
.no:
    or eax, 1
    ret

; --------------------------------------------
; _cgxCoreBindAttribLocation
; Input: ecx = program id, edx = slot, r8 = name ptr
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreBindAttribLocation:
    push rbp
    mov rbp, rsp 
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40

    mov r12d, ecx           ; program id
    mov r13d, edx           ; slot
    mov r14, r8             ; name ptr

    test r14, r14
    jz .fail
    cmp r13d, 16
    jae .fail

    ; Find the program
    mov ecx, r12d
    call _cgxCoreProgramFindById
    test rdi, rdi
    jz .fail
    mov rbx, rdi

    ; Walk the attrib table looking for a name match
    mov r15, [rbx + Program.attribs]
    mov r12d, [rbx + Program.attribCount]
    xor ecx, ecx

.search:
    cmp ecx, r12d
    jge .fail

    mov eax, ecx
    imul eax, Symbol_size
    lea rdi, [r15 + rax]
    mov rsi, r14

    push rcx
    call _strcmp32
    pop rcx
    jz .found

    inc ecx
    jmp .search

.found:
    mov eax, ecx
    imul eax, Symbol_size
    lea rdi, [r15 + rax]
    mov [rdi + Symbol.location], r13d

    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreProgramCacheAttribSlots
; For each linked attribute in the program, look up its
; VAO slots (Symbol.location) in the currently bound VAO
; and veridy the slot is enabled. Caches the slot back
; to Symbol.location for fast access during draw.
;
; Input: ecx = program id
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreProgramCacheAttribSlots:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40

    mov r12d, ecx

    ; Find the program
    mov ecx, r12d
    call _cgxCoreProgramFindById
    test rdi, rdi
    jz .fail
    mov rbx, rdi

    ; Must be linked
    cmp byte [rbx + Program.linkStatus], 0
    je .fail

    ; Get the bound VAO
    call _cgxCoreVAOFindBound
    test rdi, rdi
    jz .fail
    mov r13, rdi                ; VAO ptr

    ; Walk the program's attrib table
    mov r14, [rbx + Program.attribs]
    mov r15d, [rbx + Program.attribCount]
    xor ecx, ecx

.attribLoop:
    cmp ecx, r15d
    jge .success

    ; entry ptr
    mov eax, ecx
    imul eax, Symbol_size
    lea rdi, [r14 + rax]
    mov [rbp - 48], rdi         ; save entry
    mov [rbp - 52], ecx         ; save index

    ; Slot = Symbol.location
    mov eax, [rdi + Symbol.location]
    cmp eax, -1
    je .fail
    cmp eax, 16
    jae .fail

    ; Check the VAO slot is enabled
    imul eax, Attrib_size
    mov rdi, r13
    add rdi, VAO.attribs
    add rdi, rax
    cmp byte [rdi + Attrib.enabled], 0
    je .fail

    mov ecx, [rbp - 52]
    inc ecx
    jmp .attribLoop

.success:
    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret