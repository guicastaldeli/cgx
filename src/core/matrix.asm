; ============================================
; core/matrix.asm
; Matrix stack management
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"

extern _cgxCoreState
extern CGXState

global _cgxCoreMatrixInit
global _cgxCoreMatrixMode
global _cgxCoreLoadIdentity
global _cgxCorePushMatrix
global _cgxCorePopMatrix

STACK_DEPTH         equ 32
MATRIX_SIZE         equ 64

section .text

; --------------------------------------------
; _cgxCoreMatrixInit
; Initialized both matrix stacks to identity
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreMatrixInit:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 32

    ; Default mode: MODELVIEW
    mov dword [rel _cgxCoreState + CGXState.matrixMode], CGX_MODELVIEW

    ; Both stacks start at top = 0