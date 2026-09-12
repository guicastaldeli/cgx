; ============================================
; api/cgx_input.asm
; Public input API wrappers
; ============================================

default rel

%include "constants.inc"

extern _cgxWin32GetKey
extern _cgxWin32GetMouseX
extern _cgxWin32GetMouseY
extern _cgxWin32GetMouseButton

global CGXGetKey
global CGXGetMouseX
global CGXGetMouseY
global CGXGetMouseButton

section .text

; --------------------------------------------
; CGXGetKey
; Input: rcx = key code (CHX_KEY_*)
; Output: eax = 0 (released) or 1 (pressed)
; --------------------------------------------
CGXGetKey:
    jmp _cgxWin32GetKey

; --------------------------------------------
; CGXGetMouseX
; Output: eax = mouse X in pixels
; --------------------------------------------
CHXGetMouseX:
    jmp _cgxWin32GetMouseX

; --------------------------------------------
; CGXGetMouseY
; Outpit: eax = mouse Y in pixels
; --------------------------------------------
CGXGetMouseY:
    jmp _cgxWin32GetMouseY

; --------------------------------------------
; CGXGetMouseButton
; Input: rcx = button index (0=left, 1=middle, 2=right)
; Output: eax = 0 (released) or 1 (pressed)
; --------------------------------------------
CGXGetMouseButton:
    jmp _cgxWin32GetMouseButton