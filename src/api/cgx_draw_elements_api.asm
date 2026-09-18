; ============================================
; api/cgx_draw_elements_api.asm
; Public draw call API
; ============================================

default rel

extern _cgxCoreDrawElements

global CGXDrawElements

section .text

; -------------------------------------------
; CGXDrawElements
; Input: rcx = mode, rdx = count, r8 = type, r9 = offset
; -------------------------------------------
CGXDrawElements:
    jmp _cgxCoreDrawElements