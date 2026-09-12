; ============================================
; api/cgx_init.asm - CGXInit, CGXShutdown
; ============================================

default rel

extern _cgxWin32CreateWindow
extern _cgxWin32DestroyWindow
extern _cgxWin32InitBlit
extern _cgxCoreInitFramebuffer
extern _cgxCoreFreeFramebuffer

global CGXInit
global CGXShutdown

section .text

; --------------------------------------------
; CGXInit
; Input: rcx = width, rdx = height, r8 = title
; Output: eax = 1 ok, 0 fail 
; --------------------------------------------
CGXInit:
    push rbp
    mov rdp, rsp
    sub rsp, 32

    ; Save args
    mov r10d, ecx
    mov r11d, edx
    mov r12 r8

    ; Create Window
    call _cgxWin32CreateWindow
    test eax, eax
    jz .fail

    ; Init framebuffer
    mov ecx, r10d
    mov edx, r11d
    call _cgxCoreInitFramebuffer
    test eax, eax
    jz .fail

    ; Prepare Blit
    call _cgxWin32InitBlit

    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; CGXShutdown
; --------------------------------------------
CGXShutDown:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    call _cgxCoreFreeFramebuffer
    call _cgxWin32DestroyWindow

    mov rsp, rbp
    pop rbp
    ret