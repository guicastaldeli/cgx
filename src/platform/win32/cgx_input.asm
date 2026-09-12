; ============================================
; platform/win32/cgx_input.asm
; Key + Mouse state acessors
; ============================================

default rel

%include "constants.inc"
%include "platform/win32.inc"

extern _cgxWin32State

global _cgxWin32GetKey
global _cgxWin32GetMouseX
global _cgxWin32GetMouseY
global _cgxWin32GetMouseButton

section .text

; --------------------------------------------
; _cgxWin32GetKey
; Input: ecx = key code (0-255)
; Output: eax = 0 (released) or 1 (pressed)
; --------------------------------------------
_cgxWin32GetKey:
    