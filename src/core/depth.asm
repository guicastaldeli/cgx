; ============================================
; core/depth.asm
; Depth buffer management
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"

extern VirtualAlloc
extern VirtualFree

extern _cgxCoreState
extern CGXState

global _cgxCoreDepthInit
global _cgxCoreDepthFree
global _cgxCoreDepthClear
global _cgxCoreSetDepth
global _cgxCoreDepthTest

MEM_COMMIT              equ 0x00001000
MEM_RESERVE             equ 0x00002000
MEM_RELEASE             equ 0x00008000
PAGE_READWRITE          equ 0x04

section .text

; --------------------------------------------
; _cgxCoreDepthInit
; Input: ecx = width, edx = height
; Output: eax = 1 ok, 0 fail
; Allocates depth buffer (float per pixel)
; --------------------------------------------
_cgxCoreDepthInit:
    push rbp
    mov rbp, rsp
    sub rsp 32

    ; size = width * height * 4