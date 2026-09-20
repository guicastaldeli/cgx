; ============================================
; api/cgx_draw_api.asm
; Public drawing API
; ============================================

default rel

extern _cgxCoreSetColor
extern _cgxCoreDrawPixel
extern _cgxCoreDrawLine

global CGXSetColor
global CGXDrawPixel
global CGXDrawLine

section .text

; --------------------------------------------
; CGXSetColor
; Input: rcx = 0x00RRGGBB
; --------------------------------------------
CGXSetColor:
    jmp _cgxCoreSetColor

; --------------------------------------------
; CGXDrawPixel
; Input: ecx = x, edx = y
; Uses current draw color...
; --------------------------------------------
CGXDrawPixel:
    jmp _cgxCoreDrawPixel

; --------------------------------------------
; CGXDrawLine
; Input: rcx = x1, rdx = y1, r8 = x2, r9 = y2
; Uses current draw color...
; --------------------------------------------
CGXDrawLine:
    jmp _cgxCoreDrawLine
