; ============================================
; api/cgx_shader_api.asm
; Public shader API wrappers
; ============================================

default rel

%include "constants.inc"

extern _cgxCoreShaderCreate
extern _cgxCoreShaderSource
extern _cgxCoreShaderCompile
extern _cgxCoreShaderDelete
extern _cgxCoreShaderGetInfoLog
extern _cgxCoreProgramCreate
extern _cgxCoreProgramAttach
extern _cgxCoreProgramLink
extern _cgxCoreProgramUse
extern _cgxCoreProgramDelete
extern _cgxCoreGetUniformLocation
extern _cgxCoreGetAttribLocation
extern _cgxCoreUniform1f
extern _cgxCoreUniform2f
extern _cgxCoreUniform3f
extern _cgxCoreUniform4f
extern _cgxCoreUniform1i
extern _cgxCoreUniform3fv
extern _cgxCoreUniform4fv
extern _cgxCoreUniformMatrix4fv

global CGXCreateShader
global CGXShaderSource
global CGXCompileShader
global CGXDeleteShader
global CGXGetShaderInfoLog
global CGXCreateProgram
global CGXAttachShader
global CGXLinkProgram
global CGXUseProgram
global CGXDeleteProgram
global CGXGetUniformLocation
global CGXGetAttribLOcation
global CGXUniform1f
global CGXUniform2f
global CGXUniform3f
global CGXUniform4f
global CGXUniform1i
global CGXUniform3fv
global CGXUniform4fv
global CGXUniformMatrix4fv

section .text

; --------------------------------------------
; CGXCreateShader
; Input: ecx = shader type
; Output: eax = shader id
; --------------------------------------------
CGXCreateShader:
    jmp _cgxCoreShaderCreate

; --------------------------------------------
; CGXShaderSource
; Input: ecx = shader id, rdx = source ptr, r8d = length (0 = strLen)
; --------------------------------------------
CGXShaderSource:
    jmp _cgxCoreShaderSource

; --------------------------------------------
; CGXCompileShader
; Input: ecx = shader id
; --------------------------------------------
CGXCompileShader:
    jmp _cgxCoreShaderCompile

; --------------------------------------------
; CGXDeleteShader
; Input: ecx = shader id
; --------------------------------------------
CGXDeleteShader:
    jmp _cgxCoreShaderDelete

; --------------------------------------------
; CGXGetShaderInfoLog
; Input: ecx = shader id
; Output: rax = log ptr
; --------------------------------------------
CGXGetShaderInfoLog:
    jmp _cgxCoreShaderGetInfoLog

; --------------------------------------------
; CGXCreateProgram
; Output: eax = program id
; --------------------------------------------
CGXCreateProgram:
    jmp _cgxCoreProgramCreate

; --------------------------------------------
; CGXAttachShader
; Input: ecx = program id, edx = shader id
; --------------------------------------------
CGXAttachShader:
    jmp _cgxCoreProgramAttach

; --------------------------------------------
; CGXLinkProgram
; Input: ecx = program id
; --------------------------------------------
CGXLinkProgram:
    jmp _cgxCoreProgramLink

; --------------------------------------------
; CGXUseProgram
; Input: ecx = progam id (0 = fixed function)
; --------------------------------------------
CGXUseProgram:
    jmp _cgxCoreProgramUse

; --------------------------------------------
; CGXDeleteProgram
; Input: ecx = program id
; --------------------------------------------
CGXDeleteProgram:
    jmp _cgxCoreProgramDelete

; --------------------------------------------
; CGXGetUniformLocation
; Input: ecx = program id, edx = name ptr
; Output: eax = location (>= 0), -1 on fail
; --------------------------------------------
CGXGetUniformLocation:
    jmp _cgxCoreGetUniformLocation

; --------------------------------------------
; CGXGetAttribLocation
; Input: ecx = program id, rdx = name ptr
; Output: eax = location (>= 0), -1 on fail
; --------------------------------------------
CGXGetAttribLocation:
    jmp _cgxCoreGetAttribLocation

; --------------------------------------------
; CGXUniform1f
; Input: ecx = program id, rdx = name ptr, xmm0 = f
; --------------------------------------------
CGXUniform1f:
    jmp _cgxCoreUniform1f

; --------------------------------------------
; CGXUniform2f
; Input: ecx = program id, rdx = name ptr, xmm0, xmm1
; --------------------------------------------
CGXUniform2f:
    jmp _cgxCoreUniform2f

; --------------------------------------------
; CGXUniform3f
; Input: ecx = program id, rdx = name ptr, xmm0..xmm2
; --------------------------------------------
CGXUniform3f:
    jmp _cgxCoreUniform3f

; --------------------------------------------
; CGXUniform4f
; Input: ecx = program id, rdx = name ptr, xmm0..xmm3
; --------------------------------------------
CGXUniform4f:
    jmp _cgxCoreUniform4f

; --------------------------------------------
; CGXUniform1i
; Input: ecx = program id, rdx = name ptr, r8d = int
; --------------------------------------------
CGXUniform1i:
    jmp _cgxCoreUniform1i

; --------------------------------------------
; CGXUniform3fv
; Input: ecx = program id, rdx = name ptr, r8 = ptr to 3 floats
; --------------------------------------------
CGXUniform3fv:
    jmp _cgxCoreUniform3fv

; --------------------------------------------
; CGXUniform4fv
; Input: ecx = progam id, rdx = name ptr, r8 = ptr to 4 floats
; --------------------------------------------
CGXUniform4fv:
    jmp _cgxCoreUniform4fv

; --------------------------------------------
; CGXUniformMatrix4fv
; Input: ecx = program id, rdx = name ptr, r8 = ptr to 16 floats
; --------------------------------------------
CGXUniformMatrix4fv:
    jmp _cgxCoreUniformMatrix4fv