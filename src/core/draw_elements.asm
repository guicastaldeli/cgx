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

global _cgxCoreDrawElements

section .text

; --------------------------------------------
; _cgxCoreNdcToPixelX
; Input: xmm0 = ndc x
; Output: eax = pixel x
; --------------------------------------------
_cgxCoreNdcToPixelX:
    mov edx, 0x3F800000         ; 1.0
    movd xmm1, edx
    addss xmm0, xmm1            ; ndc_x + 1.0

    mov ecx, 0x3F000000         ; 0.5
    movd xmm1, ecx
    mulss xmm0, xmm1

    mov ecx, [rel _cgxCoreState + CGXState.width]
    cvtsi2ss xmm1, ecx
    mulss xmm0, xmm1

    cvttss2si eax, xmm0
    ret

; --------------------------------------------
; _cgxCoreNdcToPixelY
; Input: xmm 0 = ndc_y
; Output: eax = pixel y
; --------------------------------------------
_cgxCoreNdcToPixelY:
    mov ecx, 0x3F800000
    movd xmm1, ecx
    subss xmm1, xmm0            ; 1.0 - ndc_y
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
; Input: xmm0 = float [0.0, 1.0]
; Output: eax = byte [0, 255]
; --------------------------------------------
_cgxCoreFloatToByte:
    mov eax, 0x437F0000             ; 255.0f
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
; _cgxCoreDrawElements
; Input: ecx = mode, edx = count, r8d = type, r9dm = offset
; stub: reads position (attr 0) + color (attr 1)
; from VBO/EBO via VAO, draws each vertex as a pixel
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

    ; Save args
    mov [rbp - 48], ecx         ; mode
    mov [rbp - 52], edx         ; count
    mov [rbp - 56], r8d         ; type
    mov [rbp - 60], r9d         ; offset

    ; Find bound VAO
    call _cgxCoreVAOFindBound
    test rdi, rdi
    jz .done
    mov r14, rdi                ; r14 = VAO ptr

    ; --- Get buffers id ---
    ; Get VBO id
    mov eax, [r14 + VAO.vbo]
    test eax, eax
    jz .done
    mov [rbp - 64], eax

    ; Get EBO id
    mov eax, [r14 + VAO.ebo]
    test eax, eax
    jz .done
    mov [rbp - 68], eax

    ; --- Get buffers data ptr
    ; Get EBO data ptr
    mov ecx, [rbp - 68]
    call _cgxCoreBufferGetData
    test rax, rax
    jz .done
    mov r15, rax                ; r15 = EBO data

    ; Get VBO data ptr
    mov ecx, [rbp - 64]
    call _cgxCoreBufferGetData
    test rax, rax
    jz .done
    mov r13, rax                ; r13 = VBO data

    ; Interate indices
    xor r12d, r12d

.indexLoop:
    cmp r12d, [rbp - 52]
    jge .done

    ; Read index from EBO
    mov eax, [rbp - 60]         ; offset
    mov ecx, r12d
    shl ecx, 2
    add eax, ecx
    mov ecx, [r15 + rax]        ; ecx = index value

    ; Compute vertex pointer
    mov eax, [r14 + VAO.attribs + Attrib.stride]
    test eax, eax
    jnz .haveStride
    mov eax, 24

.haveStride:
    imul eax, ecx
    mov rbx, r13
    add rbx, rax                    ; rbx = vertex ptr

    ; --- Read position (attr 0) ---
    mov ecx, [r14 + VAO.attribs + Attrib.offset]
    movss xmm0, [rbx + rcx + 0]     ; x
    movss xmm1, [rbx + rcx + 4]     ; y

    movss [rbp - 80], xmm1

    ; NDC to pixel X
    call _cgxCoreNdcToPixelX
    mov [rbp - 72], eax             ; save px

    ; NDC to pixel Y
    movss xmm0, [rbp - 80]
    call _cgxCoreNdcToPixelY
    mov [rbp - 76], eax             ; save py

    ; --- Read color (attr 1) ---
    mov ecx, [r14 + VAO.attribs + Attrib_size + Attrib.offset]
    movss xmm0, [rbx + rcx + 0]
    call _cgxCoreFloatToByte
    mov r8d, eax

    mov ecx, [r14 + VAO.attribs + Attrib_size + Attrib.offset]
    movss xmm0, [rbx + rcx + 4]
    call _cgxCoreFloatToByte
    mov r9d, eax

    mov ecx, [r14 + VAO.attribs + Attrib_size + Attrib.offset]
    movss xmm0, [rbx + rcx + 8]
    call _cgxCoreFloatToByte
    mov r10d, eax

    ; Pack to 0x00RRGGBB
    mov ecx, r8d
    shl ecx, 16
    mov edx, r9d
    shl edx, 8
    or ecx, edx
    or ecx, r10d

    call _cgxCoreSetColor

    ; Draw pixel
    mov ecx, [rbp - 72]
    mov edx, [rbp - 76]
    call _cgxCoreDrawPixel

    inc r12d
    jmp .indexLoop

.done:
    add rsp, 80
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

