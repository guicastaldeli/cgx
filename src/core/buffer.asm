; ============================================
; core/buffer.asm
; Vertex/Index buffer pool
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"

extern VirtualAlloc
extern CGXState

extern _cgxCoreState
extern CGXState

global _cgxCoreBufferInit
global _cgxCoreBufferCreate
global _cgxCoreBufferDelete
global _cgxCoreBufferBind
global _chxCoreBufferGetData
global _cgxCoreBufferGetSize

MEM_COMMIT              equ 0x00001000
MEM_RESERVE             equ 0x00002000
MEM_RELEASE             equ 0x00008000
PAGE_READWRITE          equ 0x04
INITIAL_CAPACITY        equ 16

section .text

; --------------------------------------------
; _cgxCoreBufferInit
; Initialized the buffer pool
; Output: eax = 1, 0 fail
; --------------------------------------------
_cgxCoreBufferInit:
    