; ============================================
; api/cgx_state_api.asm
; Public static enable/disable API
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"

extern _cgxCoreState
extern CGXState

global CGXEnable
global CGXDisable
global CGXDepthFunc

section .text

; --------------------------------------------
; CGXEnable
; Input: rcx = cap (CGX_DEPTH_TEST, CGX_CULL_FACE, ...)
CGXEnable:
    cmp ecx, CGX_DEPTH_TEST
    jne .tryCull
    mov byte [rel _cgxCoreState + CGXState.depthTestEnabled], 1
    mov eax, 1
    ret

.tryCull:
    ; for CGX_CULL_FACE
    xor eax, eax
    ret

; --------------------------------------------
; CGXDisable
; Input: rcx = cap
; --------------------------------------------
CGXDisable:
    cmp ecx, CGX_DEPTH_TEST
    jne .tryCull
    mov byte [rel _cgxCoreState + CGXState.depthTestEnabled], 0
    mov eax, 1
    ret

.tryCull:
    ; for CGX_CULL_FACE
    xor eax, eax
    ret

; --------------------------------------------
; CGXDepthFunc
; Input: rcx = func (CGX_LESS, etc...)
; --------------------------------------------
CGXDepthFunc:
    mov [rel _cgxCoreState + CGXState.depthFunc], ecx
    mov eax, 1
    ret