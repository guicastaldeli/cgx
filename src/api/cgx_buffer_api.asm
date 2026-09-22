; ============================================
; api/cgx_buffer_api.asm
; Public buffer API
; ============================================

default rel

%include "constants.inc"

extern _cgxCoreBufferCreate
extern _cgxCoreBufferBind
extern _cgxCoreBufferDelete

global CGXCreateVertexBuffer
global CGXCreateIndexBuffer
global CGXBindVertexBuffer
global CGXBindIndexBuffer
global CGXDeleteBuffer
global CGXBufferSubData

section .text

; --------------------------------------------
; CGXCreateVertexBuffer
; Input: rcx = data ptr, rdx = size bytes, r8 = usage
; Output: eax = id (>0), 0 on fail
; --------------------------------------------
CGXCreateVertexBuffer:
    mov r9d, CGX_BUFFER_VERTEX
    jmp _cgxCoreBufferCreate

; --------------------------------------------
; CGXCreateIndexBuffer
; Input: rcx = data ptr, rdx = size bytes, r8 = usage
; Output: eax = id (>0), 0 on fail
; --------------------------------------------
CGXCreateIndexBuffer:
    mov r9d, CGX_BUFFER_INDEX
    jmp _cgxCoreBufferCreate

; --------------------------------------------
; CGXBindVertexBuffer
; Input: rcx = id
; --------------------------------------------
CGXBindVertexBuffer:
    mov edx, CGX_BUFFER_VERTEX
    jmp _cgxCoreBufferBind

; --------------------------------------------
; CGXBindIndexBuffer
; Input: rcx = id
; --------------------------------------------
CGXBindIndexBuffer:
    mov edx, CGX_BUFFER_INDEX
    jmp _cgxCoreBufferBind

; --------------------------------------------
; CGXDeleteBuffer
; Input: rcx = id
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
CGXDeleteBuffer:
    jmp _cgxCoreBufferDelete

; --------------------------------------------
; CGXBufferSubData
; Input: rcx = target (CGX_BUFFER_VERTEX / CGX_BUFFER_INDEX),
;       rdx = offset (bytes),
;       r8d = size (bytes),
;       r9 = data ptr
; Output: eax = 1 ok, 0 fail
; Writes into currently bound of the given target type.
; --------------------------------------------
CGXBufferSubData:
    jmp _cgxCoreBufferSubData