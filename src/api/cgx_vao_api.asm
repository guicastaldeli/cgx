; ============================================
; api/cgx_vao_api.asm
; Public VAO API
; ============================================

default rel

%include "constants.inc"

extern _cgxCoreVAOCreate
extern _cgxCoreVAODelete
extern _cgxCoreVAOBind
extern _cgxCoreVAOAttribPointer
extern _cgxCoreVAOEnableAttrib
extern _cgxCoreVAODisableAttrib

global CGXCreateVertexArray
global CGXDeleteVertexArray
global CGXBindVertexArray
global CGXVertexAttribPoinyer
global CGXEnableVertexAttribArray
global CGXDisableVertexAttribArray

section .text

; --------------------------------------------
; CGXCreateVertexArray
; Output: eax = id
; --------------------------------------------
CGXCreateVertexArray:
    jmp _cgxCoreVAOCreate

; --------------------------------------------
; CGXDeleteVertexArray
; Input: rcx = id
; --------------------------------------------
CGXDeleteVertexArray:
    jmp _cgxCoreVAODelete

; --------------------------------------------
; CGXBindVertexArray
; Input: rcx = id
; --------------------------------------------
CGXBindVertexArray:
    jmp _cgxCoreVAOBind

; --------------------------------------------
; CGXVertexAttribPointer
; Input: rcx = index, rdx = size, r8 = type,
;        r9 = normalized, [rsp+40] = stride,
;        [rsp+48] = offset
; --------------------------------------------
CGXVertexAttribPointer:
    jmp _cgxCoreVAOAttribPointer

; --------------------------------------------
; CGXEnableVertexAttribArray
; Input: rcx = index
; --------------------------------------------
CGXEnableVertexAttribArray:
    jmp _cgxCoreVAOEnableAttrib

; --------------------------------------------
; CGXDisableVertexAttribArray
; Input: rcx = index
; --------------------------------------------
CGXDIsableVertexAttribArray:
    jmp _cgxCoreVAODisableAttrib