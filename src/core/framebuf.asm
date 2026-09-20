; ============================================
; core/framebuf.asm - Framebuffer management
; Portable: only calls VirtualAlloc, no window code
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"

extern VirtualAlloc
extern VirtualFree
extern MessageBoxA

extern _cgxCoreState
extern _cgxCoreGetWidth
extern _cgxCoreGetHeight
extern _cgxCoreRgbToBgra
extern _cgxCoreDepthInit
extern _cgxCoreDepthFree
extern _cgxCoreDepthClear

global _cgxCoreInitFramebuffer
global _cgxCoreFreeFramebuffer
global _cgxCoreClear

MEM_COMMIT          equ 0x00001000
MEM_RESERVE         equ 0x00002000
MEM_RELEASE         equ 0x00008000
PAGE_READWRITE      equ 0x04

section .data
    fb_debug_title db "Framebuffer Debug", 0
    fb_debug_msg db "Size 0x00000000", 0
    
section .text

; --------------------------------------------
; _cgxCoreInitFrameBuffer
; Input: ecx = width, edx = height
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreInitFramebuffer:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 32

    mov r12d, ecx
    mov ebx, edx

    ; Store Dimensions in state
    mov [rel _cgxCoreState + CGXState.width], ecx
    mov [rel _cgxCoreState + CGXState.height], edx

    ; Compute Size = w * h * 4
    mov eax, r12d
    imul eax, ebx
    shl eax, 2
    mov [rel _cgxCoreState + CGXState.fbSize], rax
    push rax

    ; VirtualAlloc(NULL, size, MEM_COMMIT|MEM_RESERVE, PAGE_READWRITE)
    xor rcx, rcx
    pop rdx
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail

    mov [rel _cgxCoreState + CGXState.framebuffer], rax

    ; Allocate depth buffer
    mov ecx, r12d
    mov edx, ebx
    call _cgxCoreDepthInit
    test eax, eax
    jz .fail

    ; Default clear color: dark blue-gray (0.2, 0.2, 0.4, 1.0)
    mov eax, 0x3E4CCCCD         ; 0.2f
    mov [rel _cgxCoreState + CGXState.clearR], eax
    mov [rel _cgxCoreState + CGXState.clearG], eax
    mov eax, 0x3ECCCCCD         ; 0.4f
    mov [rel _cgxCoreState + CGXState.clearB], eax
    mov eax, 0x3F800000         ; 1.0f
    mov [rel _cgxCoreState + CGXState.clearA], eax

    mov eax, 1
    jmp .done

.fail:
    push rax
    push rdi
    push rcx
    push rdx

    mov eax, r12d
    lea rdi, [rel fb_debug_msg + 9]
    mov ecx, 8
.hexloop:
    rol eax, 4
    mov edx, eax
    and edx, 0x0F
    cmp edx, 10
    jb .digit
    add edx, 'A' - 10 - '0'
.digit:
    add edx, '0'
    mov [rdi], dl
    inc rdi
    dec ecx
    jnz .hexloop

    xor rcx, rcx
    lea rdx, [rel fb_debug_msg]
    lea r8, [rel fb_debug_title]
    mov r9d, 0
    call MessageBoxA

    pop rdx
    pop rcx
    pop rdi
    pop rax
    xor eax, eax

.done:
    add rsp, 32
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreFreeFramebuffer
; --------------------------------------------
_cgxCoreFreeFramebuffer:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    mov rcx, [rel _cgxCoreState + CGXState.framebuffer]
    test rcx, rcx
    jz .freeDepth

    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree

    mov qword [rel _cgxCoreState + CGXState.framebuffer], 0

.freeDepth:
    call _cgxCoreDepthFree

    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreClear
; Input: ecx = mas (CGX_COLOR_BIT)
; Fills framebuffer with clear color
; --------------------------------------------
_cgxCoreClear:
    push rbp
    mov rbp, rsp
    push rbx

    ; if depth bit set, clear depth buffer
    test ecx, CGX_DEPTH_BIT
    jz .skipDepthClear

    push rcx
    call _cgxCoreDepthClear
    pop rcx

.skipDepthClear:
    test ecx, CGX_COLOR_BIT
    jz .done

    ; Load clear color floats
    movss xmm0, [rel _cgxCoreState + CGXState.clearR]
    movss xmm1, [rel _cgxCoreState + CGXState.clearG]
    movss xmm2, [rel _cgxCoreState + CGXState.clearB]
    movss xmm3, [rel _cgxCoreState + CGXState.clearA]

    ; Multiply by 255.0f
    mov eax, 0x437F0000     ; 255.0f
    movd xmm4, eax
    mulss xmm0, xmm4
    mulss xmm1, xmm4
    mulss xmm2, xmm4
    mulss xmm3, xmm4

    ; Convert to int
    cvttss2si r8d, xmm0      ; R
    cvttss2si r9d, xmm1      ; G
    cvttss2si r10d, xmm2     ; B
    cvttss2si r11d, xmm3     ; A

    ; Clamp each to 0..255
    cmp r8d, 0
    jge .OKr
    xor r8d, r8d

        ; R
        .OKr:
            cmp r8d, 255
            jle .DONEr
            mov r8d, 255
        .DONEr:
            cmp r9d, 0
            jge .OKg
            xor r9d, r9d
        ; G
        .OKg:
            cmp r9d, 255
            jle .DONEg
            mov r9d, 255
        .DONEg:
            cmp r10d, 0
            jge .OKb
            xor r10d, r10d
        ; B
        .OKb:
            cmp r10d, 255
            jle .DONEb
            mov r10d, 255
        .DONEb:
            cmp r11d, 0
            jge .OKa
            xor r11d, r11d
        ; A
        .OKa:
            cmp r11d, 255
            jle .DONEa
            mov r11d, 255
        .DONEa:
            ; Pack RGB into 0x00RRGGBB (R high, B low)
            mov eax, r8d
            shl eax, 16
            mov ecx, r9d
            shl ecx, 8
            or eax, ecx
            or eax, r10d        ; B

            ; Convert to BGRA
            mov ecx, eax
            call _cgxCoreRgbToBgra

            ; Fill framebuffer
            mov rdi, [rel _cgxCoreState + CGXState.framebuffer]
            mov ecx, [rel _cgxCoreState + CGXState.width]
            imul ecx, [rel _cgxCoreState + CGXState.height]
            rep stosd

.done:
    pop rbx
    pop rbp
    ret