; ============================================
; core/draw_elements.asm
; CGXDrawElements implementation
; Reads vertices via VAO and draws each as pixel (stub)
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"

extern _cgxCoreState
extern _cgxCoreVAOFindBound
extern _cgxCoreBufferGetData
extern _cgxCoreSetColor
extern _cgxCoreDrawPixel
extern _cgxCoreSetDepth
extern _cgxCoreSetAlpha
extern _matrixMultiply
extern _matrixMultiplyVec4

global _cgxCoreDrawElements

struc RasterVertex
    .px         resd 1
    .py         resd 1
    .z          resd 1
    .r          resd 1
    .g          resd 1
    .b          resd 1
    .a          resd 1 
endstruc

section .bss
    rasterVerts     resb RasterVertex_size * 3
    mvpCache        resb 64

section .text

; --------------------------------------------
; _cgxCoreNdcToPixelX
; Input: xmm0 = ndc x
; Output: eax = pixel x
; --------------------------------------------
_cgxCoreNdcToPixelX:
    mov edx, 0x3F800000
    movd xmm1, edx
    addss xmm0, xmm1

    mov ecx, 0x3F000000
    movd xmm1, ecx
    mulss xmm0, xmm1

    mov ecx, [rel _cgxCoreState + CGXState.width]
    cvtsi2ss xmm1, ecx
    mulss xmm0, xmm1

    cvttss2si eax, xmm0
    ret

; --------------------------------------------
; _cgxCoreNdcToPixelY
; Input: xmm0 = ndc y
; Output: eax = pixel y
; --------------------------------------------
_cgxCoreNdcToPixelY:
    mov ecx, 0x3F800000
    movd xmm1, ecx
    subss xmm1, xmm0
    movaps xmm0, xmm1

    mov ecx, 0x3F000000
    movd xmm1, ecx
    mulss xmm0, xmm1

    mov ecx, [rel _cgxCoreState + CGXState.height]
    cvtsi2ss xmm1, ecx
    mulss xmm0, xmm1

    cvttss2si eax, xmm0
    ret

; --------------------------------------------
; _cgxCoreFloatToByte
; Input: xmm0 = float [0, 1]
; Output: eax = byte
; --------------------------------------------
_cgxCoreFloatToByte:
    mov eax, 0x437F0000
    movd xmm1, eax
    mulss xmm0, xmm1

    cvttss2si eax, xmm0

    cmp eax, 0
    jge .okLow
    xor eax, eax

.okLow:
    cmp eax, 255
    jle .okHigh
    mov eax, 255
.okHigh:
    ret

; --------------------------------------------
; _cgxCoreFetchVertex
; Input:
;       r13 = VBO data ptr
;       r15 = EBO data ptr
;       r14 = VAO ptr
;       ecx = EBO byte offset (offset + i*4)
;       rdi = destination RasterVertex*
; Clobbers: eax, ebx, ecx, edx, r9, r10, xmm0-3
; Preserves: r13, r14, r15, r12
; --------------------------------------------
_cgxCoreFetchVertex:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 32

    mov r12, rdi                ; dest ptr

    ; Read index from EBO
    mov ebx, [r15 + rcx]        ; ebx = vertex index

    ; Vertex ptr = vbo + index * stride
    mov eax, [r14 + VAO.attribs + Attrib.stride]
    test eax, eax
    jnz .haveStride
    mov eax, 28
.haveStride:
    imul eax, ebx
    mov rbx, r13
    add rbx, rax

    ; Read position (attr 0)
    mov ecx, [r14 + VAO.attribs + Attrib.offset]
    movss xmm0, [rbx + rcx + 0]     ; x
    movss xmm1, [rbx + rcx + 4]     ; y
    movss xmm2, [rbx + rcx + 8]     ; z

    ; w = 1.0
    mov eax, 0x3F800000
    movd xmm3, eax

    ; v_clip = MVP * (x, y, z, 1)
    lea rdi, [rel mvpCache]
    call _matrixMultiplyVec4

    ; Perspective divide: (x/w, y/w, z/w)
    divss xmm0, xmm3
    divss xmm1, xmm3
    divss xmm2, xmm3

    ; Save NDC y and z
    movss [rbp - 20], xmm1
    movss [rbp - 24], xmm2

    ; NDC to pixel X
    call _cgxCoreNdcToPixelX
    mov [r12 + RasterVertex.px], eax

    ; NDC to pixel Y
    movss xmm0, [rbp - 20]
    call _cgxCoreNdcToPixelY
    mov [r12 + RasterVertex.py], eax

    ; Convert z_ndc to [0, 1]: z = (z_ndc + 1) * 0.5
    movss xmm0, [rbp - 24]
    mov ecx, 0x3F800000
    movd xmm1, ecx
    addss xmm0, xmm1
    mov ecx, 0x3F000000
    movd xmm1, ecx
    mulss xmm0, xmm1
    movss [r12 + RasterVertex.z], xmm0

    ; Read color (attr 1, size 4: RGBA)
    ; R
    mov ecx, [r14 + VAO.attribs + Attrib_size + Attrib.offset]
    movss xmm0, [rbx + rcx + 0]
    call _cgxCoreFloatToByte
    mov [r12 + RasterVertex.r], eax

    ; G
    mov ecx, [r14 + VAO.attribs + Attrib_size + Attrib.offset]
    movss xmm0, [rbx + rcx + 4]
    call _cgxCoreFloatToByte
    mov [r12 + RasterVertex.g], eax

    ; B
    mov ecx, [r14 + VAO.attribs + Attrib_size + Attrib.offset]
    movss xmm0, [rbx + rcx + 8]
    call _cgxCoreFloatToByte
    mov [r12 + RasterVertex.b], eax

    ; A
    mov ecx, [r14 + VAO.attribs + Attrib_size + Attrib.offset]
    movss xmm0, [rbx + rcx + 12]
    call _cgxCoreFloatToByte
    mov [r12 + RasterVertex.a], eax

    add rsp, 32
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreDrawRasterVertex
; Input: rdi = RasterVertex*
; Draws one pixel with its color
; --------------------------------------------
_cgxCoreDrawRasterVertex:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 40

    mov rbx, rdi

    ; Pack color
    mov eax, [rbx + RasterVertex.r]
    shl eax, 16
    mov ecx, [rbx + RasterVertex.g]
    shl ecx, 8
    or eax, ecx
    mov ecx, [rbx + RasterVertex.b]
    or eax, ecx
    mov ecx, eax

    call _cgxCoreSetColor

    ; Set alpha
    mov eax, [rbx + RasterVertex.a]
    cvtsi2ss xmm0, eax
    mov eax, 0x3B808081         ; 1/255 as float
    movd xmm1, eax
    mulss xmm0, xmm1
    call _cgxCoreSetAlpha

    ; Set depth from vertex
    movss xmm0, [rbx + RasterVertex.z]
    call _cgxCoreSetDepth

    ; Draw pixel
    mov ecx, [rbx + RasterVertex.px]
    mov edx, [rbx + RasterVertex.py]
    call _cgxCoreDrawPixel

    add rsp, 40
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreRasterTriangle
; Input: rdi = pointer to 3 RasterVertex
; Fills the triangle via barycentric interpolation
; --------------------------------------------
_cgxCoreRasterTriangle:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 128

    mov r14, rdi

    ; --- Backface culling test ---
    cmp dword [rel _cgxCoreState + CGXState.cullFaceEnabled], 0
    je .noCull

    ; Compute signed area: area (Bx-Ax)*(Cy-Ay) - (By-Ay)*(Cx-Ax)
    mov eax, [r14 + RasterVertex.px + RasterVertex_size]            ; Bx
    sub eax, [r14 + RasterVertex.px + 0]                            ; Bx - Ax
    mov ecx, [r14 + RasterVertex.py + RasterVertex_size * 2]        ; Cy
    sub ecx, [r14 + RasterVertex.py + 0]                            ; Cy - Ay
    imul eax, ecx

    mov ebx, [r14 + RasterVertex.py + RasterVertex_size]            ; By
    sub ebx, [r14 + RasterVertex.py + 0]                            ; By - Ay
    mov edx, [r14 + RasterVertex.px + RasterVertex_size * 2]        ; Cx
    sub edx, [r14 + RasterVertex.px + 0]                            ; Cx - Ax
    imul ebx, edx                                                   ; (By-Ay)*(Cx-Ax)

    sub eax, ebx                                                    ; eax = sign area

    ; Determine isFront
    mov ecx, [rel _cgxCoreState + CGXState.frontFace]
    cmp ecx, CGX_CCW
    je .ccwFront

    ; CW is front: isFront = (area < 0)
    test eax, eax
    js .isFront
    jmp .isBack

.ccwFront:
    ; CCW is front: isFront (area > 0)
    test eax, eax
    jg .isFront
    jmp .isBack
.isFront:
    mov ecx, [rel _cgxCoreState + CGXState.cullMode]
    cmp ecx, CGX_FRONT
    je .cull
    cmp ecx, CGX_FRONT_AND_BACK
    je .cull
    jmp .noCull
.isBack:
    mov ecx, [rel _cgxCoreState + CGXState.cullMode]
    cmp ecx, CGX_BACK
    je .cull
    cmp ecx, CGX_FRONT_AND_BACK
    je .cull
    jmp .noCull

.cull:
    ; Skip this triangle
    add rsp, 128
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.noCull:
    ; Bounding box
    mov eax, [r14 + RasterVertex.px + 0]
    mov r8d, [r14 + RasterVertex.px + RasterVertex_size]
    mov r9d, [r14 + RasterVertex.px + RasterVertex_size * 2]
    mov r10d, eax
    cmp r8d, r10d
    jge .min1
    mov r10d, r8d

.min1:
    cmp r9d, r10d
    jge .minDone
    mov r10d, r9d
.minDone:
    mov [rbp - 48], r10d

    mov r10d, eax
    cmp r8d, r10d
    jle .max1
    mov r10d, r8d

.max1:
    cmp r9d, r10d
    jle .maxDone
    mov r10d, r9d
.maxDone:
    mov [rbp - 52], r10d

    mov eax, [r14 + RasterVertex.py + 0]
    mov r8d, [r14 + RasterVertex.py + RasterVertex_size]
    mov r9d, [r14 + RasterVertex.py + RasterVertex_size * 2]
    mov r10d, eax
    cmp r8d, r10d
    jge .minY1
    mov r10d, r8d

.minY1:
    cmp r9d, r10d
    jge .minYDone
    mov r10d, r9d
.minYDone:
    mov [rbp - 56], r10d

    mov r10d, eax
    cmp r8d, r10d
    jle .maxY1
    mov r10d, r8d

.maxY1:
    cmp r9d, r10d
    jle .maxYDone
    mov r10d, r9d
.maxYDone: 
    mov [rbp - 60], r10d

    ; Barycentric constants
    mov eax, [r14 + RasterVertex.px + 0]
    mov ebx, [r14 + RasterVertex.py + 0]
    mov r8d, [r14 + RasterVertex.px + RasterVertex_size]
    mov r9d, [r14 + RasterVertex.py + RasterVertex_size]
    mov r10d, [r14 + RasterVertex.px + RasterVertex_size * 2]
    mov r11d, [r14 + RasterVertex.py + RasterVertex_size * 2]

    mov [rbp - 64], eax
    mov [rbp - 68], ebx
    mov [rbp - 72], r8d
    mov [rbp - 76], r9d
    mov [rbp - 80], r10d
    mov [rbp - 84], r11d

    ; denom = (by - cy)*(ax - cx) + (cx - bx)*(ay - cy)
    mov eax, r9d
    sub eax, r11d
    cvtsi2ss xmm0, eax
    mov eax, [rbp - 64]
    mov ecx, [rbp - 80]
    sub eax, ecx
    cvtsi2ss xmm1, eax
    mulss xmm0, xmm1

    mov eax, [rbp - 80]
    mov ecx, [rbp - 72]
    sub eax, ecx
    cvtsi2ss xmm1, eax
    mov eax, [rbp - 68]
    mov ecx, [rbp - 84]
    sub eax, ecx
    cvtsi2ss xmm2, eax
    mulss xmm1, xmm2

    addss xmm0, xmm1
    movss [rbp - 88], xmm0

    pxor xmm1, xmm1
    ucomiss xmm0, xmm1
    je .done
 
    mov eax, 0x3F800000
    movd xmm1, eax
    divss xmm1, xmm0
    movss [rbp - 92], xmm1

    ; Precomputed deltas
    mov eax, [rbp - 76]
    sub eax, [rbp - 84]
    mov [rbp - 96], eax         ; by - cy

    mov eax, [rbp - 80]
    sub eax, [rbp - 72]
    mov [rbp - 100], eax        ; cx - bx

    mov eax, [rbp - 84]
    sub eax, [rbp - 68]
    mov [rbp - 104], eax        ; cy - ay

    mov eax, [rbp - 64]
    sub eax, [rbp - 80]
    mov [rbp - 108], eax        ; ax - cx

    mov r12d, [rbp - 56]

.rowLoop:
    mov eax, [rbp - 60]
    cmp r12d, eax
    jg .done

    mov r13d, [rbp - 48]
.colLoop:
    mov eax, [rbp - 52]
    cmp r13d, eax
    jg .nextRow

    ; w0
    mov eax, r13d
    sub eax, [rbp - 80]
    cvtsi2ss xmm0, eax
    mov eax, [rbp - 96]
    cvtsi2ss xmm1, eax
    mulss xmm0, xmm1

    mov eax, r12d
    sub eax, [rbp - 84]
    cvtsi2ss xmm2, eax
    mov ecx, [rbp - 100]
    cvtsi2ss xmm3, ecx
    mulss xmm2, xmm3

    addss xmm0, xmm2
    mulss xmm0, [rbp - 92]

    pxor xmm1, xmm1
    comiss xmm0, xmm1
    jb .nextCol

    ; w1
    mov eax, r13d
    sub eax, [rbp - 80]
    cvtsi2ss xmm2, eax
    mov ecx, [rbp - 104]
    cvtsi2ss xmm3, ecx
    mulss xmm2, xmm3

    mov eax, r12d
    sub eax, [rbp - 84]
    cvtsi2ss xmm4, eax
    mov ecx, [rbp - 108]
    cvtsi2ss xmm5, ecx
    mulss xmm4, xmm5

    addss xmm2, xmm4
    mulss xmm2, [rbp - 92]

    pxor xmm1, xmm1
    comiss xmm2, xmm1
    jb .nextCol

    ; w2 = 1 - w0 - w1
    movaps xmm3, xmm0
    addss xmm3, xmm2
    mov eax, 0x3F800000
    movd xmm4, eax
    subss xmm4, xmm3

    pxor xmm1, xmm1
    comiss xmm4, xmm1
    jb .nextCol

    ; Interpolate
    ; R
    mov eax, [r14 + RasterVertex.r + 0]
    cvtsi2ss xmm5, eax
    mulss xmm5, xmm0
    mov eax, [r14 + RasterVertex.r + RasterVertex_size]
    cvtsi2ss xmm6, eax
    mulss xmm6, xmm2
    addss xmm5, xmm6
    mov eax, [r14 + RasterVertex.r + RasterVertex_size * 2]
    cvtsi2ss xmm6, eax
    mulss xmm6, xmm4
    addss xmm5, xmm6
    cvttss2si r8d, xmm5

    ; G
    mov eax, [r14 + RasterVertex.g + 0]
    cvtsi2ss xmm5, eax
    mulss xmm5, xmm0
    mov eax, [r14 + RasterVertex.g + RasterVertex_size]
    cvtsi2ss xmm6, eax
    mulss xmm6, xmm2
    addss xmm5, xmm6
    mov eax, [r14 + RasterVertex.g + RasterVertex_size * 2]
    cvtsi2ss xmm6, eax
    mulss xmm6, xmm4
    addss xmm5, xmm6
    cvttss2si r9d, xmm5

    ; B
    mov eax, [r14 + RasterVertex.b + 0]
    cvtsi2ss xmm5, eax
    mulss xmm5, xmm0
    mov eax, [r14 + RasterVertex.b + RasterVertex_size]
    cvtsi2ss xmm6, eax
    mulss xmm6, xmm2
    addss xmm5, xmm6
    mov eax, [r14 + RasterVertex.b + RasterVertex_size * 2]
    cvtsi2ss xmm6, eax
    mulss xmm6, xmm4
    addss xmm5, xmm6
    cvttss2si r10d, xmm5

    ; Clamp
    cmp r8d, 0
    jge .rOk
    xor r8d, r8d

.rOk:
    cmp r8d, 255
    jle .rDone
    mov r8d, 255
.rDone:
    cmp r9d, 0
    jge .gOk
    xor r9d, r9d

.gOk:
    cmp r9d, 255
    jle .gDone
    mov r9d, 255
.gDone:
    cmp r10d, 0
    jge .bOk
    xor r10d, r10d

.bOk:
    cmp r10d, 255
    jle .bDone
    mov r10d, 255
.bDone:
    ; Pack
    mov ecx, r8d
    shl ecx, 16
    mov edx, r9d
    shl edx, 8
    or ecx, edx
    or ecx, r10d

    push r12
    push r13
    call _cgxCoreSetColor

    ; Save barycentric weights
    movss [rbp - 112], xmm0
    movss [rbp - 116], xmm2
    movss [rbp - 120], xmm4

    ; Interpolate Z
    movss xmm5, [r14 + RasterVertex.z + 0]
    mulss xmm5, xmm0
    movss xmm6, [r14 + RasterVertex.z + RasterVertex_size]
    mulss xmm6, xmm2
    addss xmm5, xmm6
    movss xmm6, [r14 + RasterVertex.z + RasterVertex_size * 2]
    mulss xmm6, xmm4
    addss xmm5, xmm6

    movaps xmm0, xmm5
    call _cgxCoreSetDepth

    ; Restore barycentric weights
    movss xmm0, [rbp - 112]
    movss xmm2, [rbp - 116]
    movss xmm4, [rbp - 120]

    ; Interpolate alpha
    movss xmm5, [r14 + RasterVertex.a + 0]
    mulss xmm5, xmm0
    movss xmm6, [r14 + RasterVertex.a + RasterVertex_size]
    mulss xmm6, xmm2
    addss xmm5, xmm6
    movss xmm6, [r14 + RasterVertex.a + RasterVertex_size * 2]
    mulss xmm6, xmm4
    addss xmm5, xmm6

    ; Convert 0-255 to 0.0-1.0
    mov eax, 0x3B808081
    movd xmm1, eax
    mulss xmm5, xmm1
    
    movaps xmm0, xmm5
    call _cgxCoreSetAlpha

    ; Draw
    mov ecx, r13d
    mov edx, r12d
    call _cgxCoreDrawPixel
    pop r13
    pop r12

.nextCol:
    inc r13d
    jmp .colLoop
.nextRow:
    inc r12d
    jmp .rowLoop

.done:
    add rsp, 128
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreDrawElements
; Input: ecx = mode, edx = count, r8d = type, r9d = offset
; --------------------------------------------
_cgxCoreDrawElements:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 80

    mov [rbp - 48], ecx
    mov [rbp - 52], edx
    mov [rbp - 56], r8d
    mov [rbp - 60], r9d

    ; Find VAO
    call _cgxCoreVAOFindBound
    test rdi, rdi
    jz .done
    mov r14, rdi

    ; --- Buffer id ---
    ; VBO id
    mov eax, [r14 + VAO.vbo]
    test eax, eax
    jz .done
    mov [rbp - 64], eax

    ; EBO id
    mov eax, [r14 + VAO.ebo]
    test eax, eax
    jz .done
    mov [rbp - 68], eax

    ; --- Buffer data ---
    ; EBO data
    mov ecx, [rbp - 68]
    call _cgxCoreBufferGetData
    test rax, rax
    jz .done
    mov r15, rax

    ; VBO data
    mov ecx, [rbp - 64]
    call _cgxCoreBufferGetData
    test rax, rax
    jz .done
    mov r13, rax

    ; --- Compute MVP = PROJECTION * MODELVIEW ---
    mov eax, [rel _cgxCoreState + CGXState.mvTop]
    shl eax, 6
    lea rbx, [rel _cgxCoreState + CGXState.mvStack]
    add rbx, rax                    ; rbx = MV ptr

    mov eax, [rel _cgxCoreState + CGXState.projTop]
    shl eax, 6
    lea rcx, [rel _cgxCoreState + CGXState.projStack]
    add rcx, rax                    ; rcx = PROJ ptr

    lea rdi, [rel mvpCache]
    mov rsi, rcx                    ; a = PROJ
    mov rdx, rbx                    ; b = MV
    call _matrixMultiply            ; MVP = PROJ * MV

    ; Dispatch
    mov eax, [rbp - 48]
    cmp eax, CGX_TRIANGLES      ; CGX_TRIANGLES
    je .triangles
    cmp eax, CGX_LINES          ; CGX_LINES
    je .lines
    cmp eax, CGX_POINTS         ; CGX_POINTS
    je .points
    jmp .done

;;;;;;;;;

;
; Triangles
;
.triangles:
    xor r12d, r12d
.trianglesLoop:
    mov eax, r12d
    add eax, 3
    cmp eax, [rbp - 52]
    jg .done

    mov eax, [rbp - 60]
    mov ecx, r12d
    shl ecx, 2
    add ecx, eax
    lea rdi, [rel rasterVerts + RasterVertex_size * 0]
    call _cgxCoreFetchVertex

    mov eax, [rbp - 60]
    mov ecx, r12d
    inc ecx
    shl ecx, 2
    add ecx, eax
    lea rdi, [rel rasterVerts + RasterVertex_size * 1]
    call _cgxCoreFetchVertex

    mov eax, [rbp - 60]
    mov ecx, r12d
    add ecx, 2
    shl ecx, 2
    add ecx, eax
    lea rdi, [rel rasterVerts + RasterVertex_size * 2]
    call _cgxCoreFetchVertex

    lea rdi, [rel rasterVerts]
    call _cgxCoreRasterTriangle

    add r12d, 3
    jmp .trianglesLoop

;
; Lines
;
.lines:
    xor r12d, r12d
.linesLoop:
    mov eax, r12d
    add eax, 2
    cmp eax, [rbp - 52]
    jg .done

    mov eax, [rbp - 60]
    mov ecx, r12d
    shl ecx, 2
    add ecx, eax
    lea rdi, [rel rasterVerts + RasterVertex_size * 0]
    call _cgxCoreFetchVertex

    mov eax, [rbp - 60]
    mov ecx, r12d
    inc ecx
    shl ecx, 2
    add ecx, eax
    lea rdi, [rel rasterVerts + RasterVertex_size * 1]
    call _cgxCoreFetchVertex

    lea rdi, [rel rasterVerts]
    call _cgxCoreDrawRasterVertex

    lea rdi, [rel rasterVerts + RasterVertex_size]
    call _cgxCoreDrawRasterVertex

    add r12d, 2
    jmp .linesLoop

;
; Points
;
.points:
    xor r12d, r12d
.pointsLoop:
    cmp r12d, [rbp - 52]
    jge .done

    mov eax, [rbp - 60]
    mov ecx, r12d
    shl ecx, 2
    add ecx, eax
    lea rdi, [rel rasterVerts]
    call _cgxCoreFetchVertex

    lea rdi, [rel rasterVerts]
    call _cgxCoreDrawRasterVertex

    inc r12d
    jmp .pointsLoop

;;;;;;;;;

.done:
    add rsp, 80
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret