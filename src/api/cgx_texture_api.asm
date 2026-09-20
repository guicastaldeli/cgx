; ============================================
; api/cgx_texture_api.asm
; Public texture API
; ============================================

default rel

%include "constants.inc"

extern _cgxCoreTextureGen
extern _cgxCoreTextureDelete
extern _cgxCoreTextureBind
extern _cgxCoreTextureImage
extern _cgxCoreTextureParameter
extern _cgxCoreTextureEnv
extern _cgxCoreActiveTexture

global CGXGenTextures
global CGXDeleteTextures
global CHXBindTexture
global CGXTexImage2D
global CGXTexParameteri
global CGXTexEnvi
global CGXActiveTexture

section .text

; --------------------------------------------
; CGXGenTextures
; Input: rcx = n, rdx = *ids
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
CGXGenTextures:
    jmp _cgxCoreTextureGen

; --------------------------------------------
; CGXDeleteTextures
; Input: rcx = n, rdx = *ids
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
CGXDeleteTextures:
    jmp _cgxCoreTextureDelete

; --------------------------------------------
; CGXBindTexture
; Input: rcx = target (CGX_TEXTURE_2D), rdx = id
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
CGXBindTexture:
    jmp _cgxCoreTextureBind

; --------------------------------------------
; CGXTexImage2D
; Input:
;   rcx         = target
;   rdx         = level
;   r8          = internalFormat
;   r9          = width
;   [rsp+40]    = border
;   [rsp+48]    = format
;   [rsp+56]    = type
;   [rsp+64]    = type
;   [rsp+72]    = data
; Output: eax = 1 ok, 0 fail 
; --------------------------------------------
CGXTexImage2D:
    jmp _cgxCoreTextureImage

; --------------------------------------------
; CGXTexParameteri
; Input: rcx = target, rdx = pname, r8 = param
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
CGXTextureParameteri:
    jmp _cgxCoreTextureParameter

; --------------------------------------------
; CGXTexEnvi
; Input: rcx = target, rdx = pname, r8 = param
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
CGXTexEnvi:
    jmp _cgxCoreTextureEnv

; --------------------------------------------
; CGXActiveTexture
; Input: rcx = unit (CGX_TEXTURE0)
; Output: eax = 1 ok, 0
; --------------------------------------------
CGXActiveTexture:
    jmp _cgxActiveTexture