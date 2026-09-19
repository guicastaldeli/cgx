; ============================================
; api/cgx_matrix_api.asm
; Public matrix API
; ============================================

default rel

extern _cgxCoreMatrixMode
extern _cgxCoreLoadIdentity
extern _cgxCorePushMatrix
extern _cgxCorePopMatrix
extern _cgxCoreLoadMatrix
extern _cgxCoreMultMatrix
extern _cgxCoreTranslate
extern _cgxCoreRotate
extern _cgxCoreScale
extern _cgxCorePerspective
extern _cgxCoreOrtho

global CGXMatrixMode
global CGXLoadIdentity
global CGXPushMatrix
global CGXPopMatrix
global CGXLoadMatrix
global CGXMultMatrix
global CGXTranslate
global CGXRotate
global CGXScale
global CGXPerspective
global CGXOrtho

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

; --------------------------------------------
; CGXLoadMatrix
; --------------------------------------------
CGXLoadMatrix:
    jmp _cgxCoreLoadMatrix

; --------------------------------------------
; CGXMultMatrix
; --------------------------------------------
CGXMultMatrix:
    jmp _cgxCoreMultMatrix

; --------------------------------------------
; CGXTranslate
; --------------------------------------------
CGXTranslate:
    jmp _cgxCoreTranslate

; --------------------------------------------
; CGXRotate
; --------------------------------------------
CGXRotate:
    jmp _cgxCoreRotate

; --------------------------------------------
; CGXScale
; --------------------------------------------
CGXScale:
    jmp _cgxCoreScale

; --------------------------------------------
; CGXPerspective
; --------------------------------------------
CGXPerspective:
    jmp _cgxCorePerspective

; --------------------------------------------
; CGXOrtho - 6 args, last 2 on stack
; Input: xmm0=l, xmm1=r, xmm2=b, xmm3=t,
;            [rsp+40]=n, [rsp+48]=f
; --------------------------------------------
CGXOrtho:
    jmp _cgxCoreOrtho