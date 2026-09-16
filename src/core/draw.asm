; ============================================
; core/cgx_draw.asm
; Portable drawing primitives
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"

extern _cgxCoreState
extern _cgxCoreGetFramebuffer
extern _cgxCoreGetWidth
extern _cgxCoreGetHeight

global _cgxCoreRgbToRgra
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

    ; Comput offset = (y * width + x) * 4
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

    mov [r8], eax
    ret

.out:
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
    push rsp, 32

    ; -- Save endpoints ---
    mov r12d, ecx           ; x1
    mov r13d, edx           ; y1
    mov r14d, r8d           ; x2
    mov r15d, r9d           ; y2

    ; --- Compute deltas ---
    mov eax, r14d
    sub eax, r12d           ; dx = x2 - x1
    mov r8d, eax

    mov eax, r15d
    sub eax, r13d           ; dy = y2 - y1
    mov r9d, eax

    ; --- Step direction for X ---
    mov ebx, 1
    cmp r8d, 0
    jge .dx_pos
    neg r8d                 ; dx = |dx|
    mov ebx, -1

.dx_pos:
    ; --- Step direction for Y ---
    mov r10d, 1
    cmp r9d, 0
    jge .dy_pos             ; dy = |dy|
    neg r9d
    mov r10d, -1
.dy_pos:
    ; --- err = dx - dy ---
    mov eax, r8d
    sub eax, r9d
    mov r11d, eax           ; err

.loop:
    ; Draw current pixel
    mov ecx, r12d
    mov edx, r13d
    call _cgxCoreDrawPixel

    cmp r12d, r14d
    jne .not_done
    cmp r13d, r15d
    jne .not_done
    jmp .done

.not_done:
    ; e2 = 2 * err
    mov eax, r11d
    add eax, eax            ; e2

    /*
        if(e2 >= -dy) {
            err -= dy;
            x1 += sx;
        }
        */
    mov edi, r9d
    neg edi                 ; -dy
    cmp eax, edi
    jl .skip_x
    sub r11d, r9d
    add r12d, ebx

.skip_x:
    /*
        if(e2 <= dx) {
            err += dx;
            y1 += sy;
        }
        */
    cmp eax, r8d
    jg .skip_y
    add r11d, r8d
    add r13d, r10d
.skip_y:
    jmp .loop

.done:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

    

