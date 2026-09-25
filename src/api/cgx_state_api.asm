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
global CGXBlendFunc

section .text

; --------------------------------------------
; CGXEnable
; Input: rcx = cap (CGX_DEPTH_TEST, CGX_CULL_FACE, ...)
CGXEnable:
    cmp ecx, CGX_DEPTH_TEST     ; DEPTH_TEST
    je .depth
    cmp ecx, CGX_CULL_FACE      ; CULL_FACE
    je .cull
    cmp ecx, CGX_BLEND          ; BLEND
    je .blend
    cmp ecx, CGX_TEXTURE_2D     ; TEXTURE_2D
    je .texture2D

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

.blend:
    mov dword [rel _cgxCoreState + CGXState.blendEnabled], 1
    mov eax, 1
    ret

.texture2D:
    mov dword [rel _cgxCoreState + CGXState.texture2DEnabled], 1
    mov eax, 1
    ret

; --------------------------------------------
; CGXDisable
; Input: rcx = cap
; --------------------------------------------
CGXDisable:
    cmp ecx, CGX_DEPTH_TEST     ; DEPTH_TEST
    je .depth
    cmp ecx, CGX_CULL_FACE      ; CULL_FACE
    je .cull
    cmp ecx, CGX_BLEND          ; BLEND
    je .blend
    cmp ecx, CGX_TEXTURE_2D     ; TEXTURE_2D
    je .texture2D

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

.blend:
    mov dword [rel _cgxCoreState + CGXState.blendEnabled], 0
    mov eax, 1
    ret

.texture2D:
    mov dword [rel _cgxCoreState + CGXState.texture2DEnabled], 0
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

; --------------------------------------------
; CGXBlendFunc
; Input: rcx = srcFactor, rdx = dstFactor
; --------------------------------------------
CGXBlendFunc:
    mov [rel _cgxCoreState + CGXState.blendSrc], ecx
    mov [rel _cgxCoreState + CGXState.blendDst], edx
    mov eax, 1
    ret