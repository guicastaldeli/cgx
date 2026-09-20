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
global CGXCullFace
global CGXFrontFace 

section .text

; --------------------------------------------
; CGXEnable
; Input: rcx = cap (CGX_DEPTH_TEST, CGX_CULL_FACE, ...)
CGXEnable:
    cmp ecx, CGX_DEPTH_TEST
    je .depth
    cmp ecx, CGX_CULL_FACE
    je .cull
    xor eax, eax
    ret

.depth:
    mov byte [rel _cgxCoreState + CGXState.depthTestEnabled], 1
    mov eax, 1
    ret

.cull:
    mov dword [rel _cgxCoreState + CGXState.cullFaceEnabled], 1
    mov eax, 1
    ret

; --------------------------------------------
; CGXDisable
; Input: rcx = cap
; --------------------------------------------
CGXDisable:
    cmp ecx, CGX_DEPTH_TEST
    je .depth
    cmp ecx, CGX_CULL_FACE
    je .cull
    xor eax, eax
    ret

.depth:
    mov dword [rel _cgxCoreState + CGXState.depthTestEnabled], 0
    mov eax, 1
    ret

.cull:
    mov dword [rel _cgxCoreState + CGXState.cullFaceEnabled], 0
    mov eax, 1
    ret

; --------------------------------------------
; CGXDepthFunc
; Input: rcx = func (CGX_LESS, etc...)
; --------------------------------------------
CGXDepthFunc:
    mov [rel _cgxCoreState + CGXState.depthFunc], ecx
    mov eax, 1
    ret

; --------------------------------------------
; CGXCullFace
; Input: rcx = mode (CGX_FRONT / CGX_BACK / CGX_FRONT_AND_BACK)
; --------------------------------------------
CGXCullFace:
    mov [rel _cgxCoreState + CGXState.cullMode], ecx
    mov eax, 1
    ret

; --------------------------------------------
; CGXFrontFace
; Input: rcx = winding (CGX_CW or CGX_CCW)
; --------------------------------------------
CGXFrontFace:
    mov [rel _cgxCoreState + CGXState.frontFace], ecx
    mov eax, 1
    ret