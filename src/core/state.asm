; ============================================
; core/state.asm - Portable CGX state
; ============================================

default rel

%include "structs.inc"

global _cgxCoreState            ; the CGXState struct instance...
global _cgxCoreSetDimensions
global _cgxCoreSetClearColor
global _cgxCoreGetFramebuffer
global _cgxCoreGetWidth
global _cgxCoreGetHeight
global _cgxCoreSetAlpha
global _cgxCoreSetColorRGBA

; --- State instance ---
section .bss
    _cgxCoreState   resb CGXState_size

section .text

; --------------------------------------------
; _cgxCoreSetDimensions
; Input: ecx = width, edx = height
; --------------------------------------------
_cgxCoreSetDimensions:
    mov [rel _cgxCoreState + CGXState.width], ecx
    mov [rel _cgxCoreState + CGXState.height], edx
    ret

; --------------------------------------------
; _cgxCoreSetClearColor
; Input: xmm0...xmm3 = r, g, b, a (floats)
; --------------------------------------------
_cgxCoreSetClearColor:
    movss [rel _cgxCoreState + CGXState.clearR], xmm0
    movss [rel _cgxCoreState + CGXState.clearG], xmm1
    movss [rel _cgxCoreState + CGXState.clearB], xmm2
    movss [rel _cgxCoreState + CGXState.clearA], xmm3
    ret

; --------------------------------------------
; _cgxCoreGetFramebuffer
; Output: rax = framebuffer pointer
; --------------------------------------------
_cgxCoreGetFramebuffer:
    mov rax, [rel _cgxCoreState + CGXState.framebuffer]
    ret

; --------------------------------------------
; _cgxCoreGetWidth
; Output: eax = width
; --------------------------------------------
_cgxCoreGetWidth:
    mov eax, [rel _cgxCoreState + CGXState.width]
    ret

; --------------------------------------------
; _cgxCoreGetWidth
; Output: eax = height
; --------------------------------------------
_cgxCoreGetHeight:
    mov eax, [rel _cgxCoreState + CGXState.height]
    ret

; --------------------------------------------
; _cgxCoreSetAlpha
; Input: xmm0 = alpha [0, 1]
; --------------------------------------------
_cgxCoreSetAlpha:
    movss [rel _cgxCoreState + CGXState.drawAlpha], xmm0
    ret

; --------------------------------------------
; _cgxCoreSetColorRBGA
; Input: ecx = 0x00RRGGBB, xmm0 = alpha
; --------------------------------------------
_cgxCoreSetColorRGBA:
    mov [rel _cgxCoreState + CGXState.drawColor], ecx
    movss [rel _cgxCoreState + CGXState.drawAlpha], xmm0
    ret