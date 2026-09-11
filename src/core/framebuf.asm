; ============================================
; core/framebuf.asm - Framebuffer management
; Portable: only calls VirtualAlloc, no window code
; ============================================

default rel

global _cgxCoreInitFramebuffer
global _cgxCoreFreeFrameBuffer
global _cgxCoreClear

extern VirtualAlloc
extern VirtualFree

extern _cgxCoreState
extern _cgxCoreGetWidth
extern _cgxCoreGetHeight

extern CGXState
extern CGXState_size

MEM_COMMIT          equ 0x00001000
MEM_RESERVE         equ 0x00002000
MEM_RELEASE         equ 0x00008000
MEM_READWRITE       equ 0x04

CGX_COLOR_BIT       equ 0x00004000

section .text

; --------------------------------------------
; _cgxCoreInitFrameBuffer
; Input: ecx = width, edx = height
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreInitFramebuffer:
    push rbp,
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
    mov eax, ecx
    imul eax, edx
    shl eax, 2
    mov r12d, eax ; size
    mov [rel _cgxCoreState + CGXState.fbSize], rax

    ; VirtualAlloc(NULL, size, MEM_COMMIT|MEM_RESERVE, PAGE_READWRITE)
    xor rcx, rcx
    mov rdx, r12
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail

    mov [rel _cgxCoreState + CGXState.framebuffer], rax

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
    jz .done

    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree

    mov qword [rel _cgxCoreState + CGXState.framebuffer], 0

.done:
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
    cvttss2si eax, xmm0     ; R
    cvttss2si ebx, xmm1     ; G
    cvttss2si ecx, xmm2     ; B
    cvttss2si edx, xmm3     ; A

    ; Pack BGRA (little-endian: B | G << 8 | R << 16 | A << 24)
    and eax, 0xFF
    shl eax, 16             ; R << 16

    and ebx, 0xFF
    shl ebx, 8              ; G << 8

    and ecx, 0xFF           ; B

    and edx, 0xFF
    shl edx, 24             ; A << 24

    or eax, ebx
    or eax, ecx
    or eax, edx

    ; Fill
    mov rdi, [rel _cgxCoreState + CGXState.framebuffer]
    mov ecx, [rel _cgxCoreState + CGXState.width]
    imul ecx, [rel _cgxCoreState + CGXState.height]
    rep stosd

.done:
    mov rsp, rbp
    pop rbp
    ret