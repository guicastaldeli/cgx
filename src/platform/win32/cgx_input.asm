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
    movzx eax, byte [rel _cgxWin32State + CGXWin32State.keys + rcx]
    ret

; --------------------------------------------
; _cgxWin32GetMouseX
; Output: eax = mouse X in pixels (relative to window)
; --------------------------------------------
_cgxWin32GetMouseX:
    mov eax, [rel _cgxWin32State + CGXWin32State.mouseX]
    ret

; --------------------------------------------
; _cgxWin32GetMouseY
; Output: eax = mouse Y in pixels
; --------------------------------------------
_cgxWin32GetMouseY:
    mov eax, [rel _cgxWin32State + CGXWin32State.mouseY]
    ret

; --------------------------------------------
; _cgxWin32GetMouseButton
; Input: ecx = button index (0=left, 1=middle, 2=right)
; Output: eax = 0 (released) or 1 (pressed)
; --------------------------------------------
_cgxWin32MouseButton:
    cmp ecx, 3
    jae .invalid
    movzx eax, byte [rel _cgxWin32State + CGXWin32State.mouseButtons + rcx]
    ret

.invalid:
    xor eax, eax
    ret

