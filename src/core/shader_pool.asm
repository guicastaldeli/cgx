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