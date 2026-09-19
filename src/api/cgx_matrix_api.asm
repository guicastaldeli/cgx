; ============================================
; api/cgx_matrix_api.asm
; Public matrix API
; ============================================

default rel

extern _cgxCoreMatrixMode
extern _cgxCoreLoadIdentity
extern _cgxCorePushMatrix
extern _cgxCorePopMatrix

global CGXMatrixMode
global CGXLoadIdentity
global CGXPushMatrix
global CGXPopMatrix

section .text

; --------------------------------------------
; CGXMatrixMode
; Input: rcx = CGX_MODELVIEW or CGX_PROJECTION
; --------------------------------------------
CGXMatrixMode:
    jmp _cgxCoreMatrixMode

; --------------------------------------------
; CGXLoadIdentity
; --------------------------------------------
CGXLoadIdentity:
    jmp _cgxCoreLoadIdentity

; --------------------------------------------
; CGXPushMatrix
; --------------------------------------------
CGXPushMatrix:
    jmp _cgxCorePushMatrix

; --------------------------------------------
; CGXPopMatrix
; --------------------------------------------
CGXPopMatrix:
    jmp _cgxCorePopMatrix