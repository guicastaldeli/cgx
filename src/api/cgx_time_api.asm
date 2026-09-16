; ============================================
; api/cgx_time_api.asm
; Public timing API wrappers
; ============================================

default rel

extern _cgxWin32GetTime
extern _cgxWin32GetTimeDelta

global CGXGetTime
global CGXGetTimeDelta

section .text

; --------------------------------------------
; CGXGetTime
; Output: xmm0 = seconds (double) since init
; --------------------------------------------
CGXGetTime:
    jmp _cgxWin32GetTime

; --------------------------------------------
; CGXGetTimeDelta
; Output: xmm0 = seconds (double) since last call
; --------------------------------------------
CGXGetTimeDelta:
    jmp _cgxWin32GetTimeDelta