; ============================================
; core/draw.asm
; Portable drawing primitives
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"

extern _cgxCoreState
extern _cgxCoreGetFramebuffer
extern _cgxCoreGetWidth
extern _cgxCoreGetHeight
extern _cgxCoreDepthTest

global _cgxCoreRgbToBgra
global _cgxCoreSetColor
global _cgxCoreDrawPixel
global _cgxCoreDrawLine

section .text

; --------------------------------------------
; _cgxCoreRgbToBgra
; Input: ecx = 0x00RRGGBB
; Output: eax = 0xAARRBBGG in BGRA memory order (little-endian B G R A)
; --------------------------------------------
_cgxCoreRgbToBgra:
    mov eax, ecx
    mov r9d, eax
    and r9d, 0x000000FF     ; B
    shl r9d, 16

    mov r10d, eax
    and r10d, 0x0000FF00    ; G

    mov r11d, eax
    and r11d, 0x00FF0000    ; R
    shr r11d, 16

    or r9d, r10d
    or r9d, r11d
    or r9d, 0xFF000000      ; A = 255

    mov eax, r9d
    ret

; --------------------------------------------
; _cgxCoreSetColor
; Input: ecx: 0x00RRGGBB
; Stores current draw color in state
; --------------------------------------------
_cgxCoreSetColor:
    mov [rel _cgxCoreState + CGXState.drawColor], ecx
    ret

; --------------------------------------------
; _cgxCoreDrawPixel
; Input: ecx = x, edx = y
; Uses current draw color... skips if out of bounds...
; --------------------------------------------
_cgxCoreDrawPixel:
    push rbp
    mov rbp, rsp
    sub rsp, 64
    
    ; Bounds check
    cmp ecx, 0
    jl .out
    cmp edx, 0
    jl .out

    mov eax, [rel _cgxCoreState + CGXState.width]
    cmp ecx, eax
    jge .out

    mov eax, [rel _cgxCoreState + CGXState.height]
    cmp edx, eax
    jge .out

    ; Depth test (uses ecx, edx, xmm0)
    movss xmm0, [rel _cgxCoreState + CGXState.drawDepth]
    push rcx
    push rdx
    call _cgxCoreDepthTest
    test eax, eax
    pop rdx
    pop rcx
    jz .out

    ; Recompute pixel offset = (y * width + x) * 4
    mov eax, edx
    mov r8d, [rel _cgxCoreState + CGXState.width]
    imul eax, r8d
    add eax, ecx
    shl eax, 2

    ; Load framebuffer
    mov r8, [rel _cgxCoreState + CGXState.framebuffer]
    add r8, rax

    ; Convert current color 0x00RRGGBB -> BGRA
    mov ecx, [rel _cgxCoreState + CGXState.drawColor]
    call _cgxCoreRgbToBgra
    ; eax = src as 0xAARRGGBB (BGRA in memory order)

    movss xmm0, [rel _cgxCoreState + CGXState.drawAlpha]
    mov edi, 0x437F0000
    movd xmm1, edi
    mulss xmm0, xmm1
    cvttss2si edi, xmm0
    cmp edi, 0
    jge .a1
    xor edi, edi

.a1:
    cmp edi, 255
    jle .a2
    mov edi, 255
.a2:
    shl edi, 24
    and eax, 0x00FFFFFF
    or eax, edi

    cmp dword [rel _cgxCoreState + CGXState.blendEnabled], 0
    je .writeDirect

    ; --- Blending path ---
    ; eax = packed src (AARRGGBB)
    ; r8  = framebuffer pixel pointer
    ; [r8] = packed dst

    mov r9d, [r8]               ; dst color

    ; Save src/dst for the alpha reconstruction at the end
    mov [rbp - 24], eax         ; src (AARRGGBB)
    mov [rbp - 28], r9d         ; dst

    ; --- Red channel ---
    mov edx, eax
    shr edx, 16
    and edx, 0xFF               ; src.r
    mov ecx, r9d
    shr ecx, 16
    and ecx, 0xFF               ; dst.r
    push r9                     ; packed dst
    push rax                    ; packed src
    call _blendChannel
    add  rsp, 16
    shl  eax, 16
    mov  [rbp - 32], eax        ; save blended red

    ; --- Green channel ---
    mov eax, [rbp - 24]         ; reload packed src
    mov r9d, [rbp - 28]         ; reload packed dst
    mov edx, eax
    shr edx, 8
    and edx, 0xFF               ; src.g
    mov ecx, r9d
    shr ecx, 8
    and ecx, 0xFF               ; dst.g
    push r9
    push rax
    call _blendChannel
    add  rsp, 16
    shl  eax, 8
    or   eax, [rbp - 32]
    mov  [rbp - 32], eax

    ; --- Blue channel ---
    mov eax, [rbp - 24]         ; reload packed src
    mov r9d, [rbp - 28]         ; reload packed dst
    mov edx, eax
    and edx, 0xFF               ; src.b
    mov ecx, r9d
    and ecx, 0xFF               ; dst.b
    push r9
    push rax
    call _blendChannel
    add  rsp, 16
    or   eax, [rbp - 32]
    mov  r11d, eax

    ; --- Alpha (keep src alpha) ---
    mov eax, [rbp - 24]
    and eax, 0xFF000000
    or  r11d, eax

    mov [r8], r11d
    jmp .out

.writeDirect:
    mov [r8], eax

.out:
    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; _blendChannel
; Input: edx = src channel value (0-255)
;       ecx = dst channel value (0-255)
;       r8d = packed src color (AARRGGBB)
;       r9d = packed dst color (AARRGGBB)
; Output: eax = blended value (0-255)
; Reads blendSrc, blendDst from state
; Clobbers: eax, ebx, edi, xmm0-2
; --------------------------------------------
_blendChannel:
    push rbp
    mov rbp, rsp
    sub rsp, 48

    mov [rbp - 8], edx          ; src channel value
    mov [rbp - 12], ecx         ; dst channel value
    mov [rbp - 24], r8d         ; packed src
    mov [rbp - 28], r9d         ; packed dst

    ; Compute srcFactor
    mov eax, [rel _cgxCoreState + CGXState.blendSrc]
    call _computeFactor
    mov [rbp - 16], eax         ; save srcFactor to stack

    ; Compute dstFactor
    mov eax, [rel _cgxCoreState + CGXState.blendDst]
    call _computeFactor
    mov r10d, eax               ; dstFactor * 256

    ; Blend: (src * srcFactor + dst * dstFactor) >> 8
    mov eax, [rbp - 8]          ; src channel
    imul eax, [rbp - 16]        ; src * srcFactor
    mov ebx, [rbp - 12]         ; dst channel
    imul ebx, r10d              ; dst * dstFactor
    add eax, ebx
    shr eax, 8                  ; back to 0-255 range

    ; Clamp to 255
    cmp eax, 255
    jbe .ok
    mov eax, 255

.ok:
    add rsp, 48
    pop rbp
    ret

; --------------------------------------------
; _computeFactor
; Input: eax = factor enum
; Uses [rbp - 24] = src, [rbp - 28] = dst
; Output: eax = factor value * 256 (0-256)
; --------------------------------------------
_computeFactor:
    cmp eax, CGX_ZERO                       ; ZERO
    je .zero
    cmp eax, CGX_ONE                        ; ONE
    je .one
    cmp eax, CGX_SRC_ALPHA                  ; SRC_ALPHA
    je .srcAlpha
    cmp eax, CGX_ONE_MINUS_SRC_ALPHA        ; ONE_MINUS_SRC_ALPHA
    je .oneMinusSrcAlpha
    cmp eax, CGX_DST_ALPHA                  ; DST_ALPHA
    je .dstAlpha
    cmp eax, CGX_ONE_MINUS_DST_ALPHA        ; ONE_MINUS_DST_ALPHA 
    je .oneMinusDstAlpha
    cmp eax, CGX_SRC_COLOR                  ; SRC_COLOR
    je .srcColor
    cmp eax, CGX_ONE_MINUS_SRC_COLOR        ; ONE_MINUS_SRC_COLOR
    je .oneMinusSrcColor
    cmp eax, CGX_DST_COLOR                  ; DST_COLOR
    je .dstColor
    cmp eax, CGX_ONE_MINUS_DST_COLOR        ; ONE_MINUS_DST_COLOR
    je .oneMinusDstColor
    jmp .zero        

.zero:
    xor eax, eax
    ret
.one:
    mov eax, 256
    ret
.srcAlpha:
    mov eax, [rbp - 24]
    shr eax, 24
    and eax, 0xFF
    mov ecx, eax
    shr ecx, 7
    add eax, ecx
    ret
.oneMinusSrcAlpha:
    mov eax, [rbp - 24]
    shr eax, 24
    and eax, 0xFF
    mov ecx, eax
    shr ecx, 7
    add eax, ecx
    neg eax
    add eax, 256
    ret
.dstAlpha:
    mov eax, [rbp - 28]
    shr eax, 24
    and eax, 0xFF
    mov ecx, eax
    shr ecx, 7
    add eax, ecx
    ret
.oneMinusDstAlpha:
    mov eax, [rbp - 28]
    shr eax, 24
    and eax, 0xFF
    mov ecx, eax
    shr ecx, 7
    add eax, ecx
    neg eax
    add eax, 256
    ret
.srcColor:
    mov eax, [rbp - 24]
    shr eax, 16
    and eax, 0xFF
    mov ecx, eax
    shr ecx, 7
    add eax, ecx
    ret
.oneMinusSrcColor:
    mov eax, [rbp - 24]
    shr eax, 16
    and eax, 0xFF
    mov ecx, eax
    shr ecx, 7
    add eax, ecx
    neg eax
    add eax, 256
    ret
.dstColor:
    mov eax, [rbp - 28]
    shr eax, 16
    and eax, 0xFF
    mov ecx, eax
    shr ecx, 7
    add eax, ecx
    ret
.oneMinusDstColor:
    mov eax, [rbp - 28]
    shr eax, 16
    and eax, 0xFF
    mov ecx, eax
    shr ecx, 7
    add eax, ecx
    neg eax
    add eax, 256
    ret

; --------------------------------------------
; _cgxCoreDrawLine
; Input: ecx = x1, edx = y1, r8d = x2, r9d = y2
; Uses current draw color
; --------------------------------------------
_cgxCoreDrawLine:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 64

    ; -- Save endpoints ---
    mov r12d, ecx                   ; x1
    mov r13d, edx                   ; y1
    mov r14d, r8d                   ; x2
    mov r15d, r9d                   ; y2

    ; dx = x2 - x1
    mov eax, r14d
    sub eax, r12d
    mov [rbp - 48], eax

    ; sx
    mov dword [rbp - 56], 1         ; sx = 1
    cmp eax, 0
    jge .dx_pos
    neg dword [rbp - 48]            ; dx = |dx|
    mov dword [rbp - 56], -1        ; sx = -1
.dx_pos:
    ; dy = y2 - y1
    mov eax, r15d
    sub eax, r13d
    mov [rbp - 52], eax             ; dy (local)

    ; sy
    mov dword [rbp - 60], 1         ; sy = 1
    cmp eax, 0
    jge .dy_pos
    neg dword [rbp - 52]
    mov dword [rbp - 60], -1 
.dy_pos:
    mov eax, [rbp - 48]
    sub eax, [rbp - 52]
    mov [rbp - 64], eax             ; err

.loop:
    ; Draw pixel
    mov ecx, r12d
    mov edx, r13d
    call _cgxCoreDrawPixel

    ; Termination: x1 == x2 && y1 == y2
    cmp r12d, r14d
    jne .not_done
    cmp r13d, r15d
    jne .not_done
    jmp .done

.not_done:
    mov eax, [rbp - 64]
    add eax, eax                ; e2 = 2*err

    ; if(e2 >= -dy)
    mov edi, [rbp - 52]
    neg edi
    cmp eax, edi
    jl .skip_x
    mov ecx, [rbp - 52]
    sub [rbp - 64], ecx         ; err -= dy
    mov ecx, [rbp - 56]
    add r12d, ecx               ; x1 += sx

.skip_x:
    ; if(e2 <= dx)
    cmp eax, [rbp - 48]
    jg .skip_y
    mov ecx, [rbp - 48]
    add [rbp - 64], ecx         ; err += dx
    mov ecx, [rbp - 60]
    add r13d, ecx               ; y1 += sy
.skip_y:
    jmp .loop

.done:
    add rsp, 64
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret