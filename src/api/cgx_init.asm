; ============================================
; api/cgx_init.asm - CGXInit, CGXShutdown
; ============================================

default rel

%include "structs.inc"
%include "platform/win32.inc"

extern _cgxWin32CreateWindow
extern _cgxWin32DestroyWindow
extern _cgxWin32InitBlit
extern _cgxCoreInitFramebuffer
extern _cgxCoreFreeFramebuffer
extern MessageBoxA

global CGXInit
global CGXShutdown

section .data
    err_title  db "CGXInit Debug", 0
    err_win  db "CreateWindow FAILED", 0
    err_fb db "Framebuffer init FAILED", 0
    ok_msg db "CGXInit: all steps passed", 0

section .text

; --------------------------------------------
; CGXInit
; Input: rcx = width, rdx = height, r8 = title
; Output: eax = 1 ok, 0 fail 
; --------------------------------------------
CGXInit:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 40

    ; Save args
    mov ebx, ecx
    mov r12d, edx
    mov r13, r8

    ; Create Window
    mov ecx, ebx
    mov edx, r12d
    mov r8, r13
    call _cgxWin32CreateWindow
    test eax, eax
    jz .fail_window

    ; Init framebuffer
    mov ecx, ebx
    mov edx, r12d
    call _cgxCoreInitFramebuffer
    test eax, eax
    jz .fail_fb

    ; Prepare Blit
    call _cgxWin32InitBlit

    mov eax, 1
    jmp .done

.fail_window:
    xor rcx, rcx
    lea rdx, [rel err_win]
    lea r8, [rel err_title]
    mov r9d, 0
    call MessageBoxA
    xor eax, eax
    jmp .done

.fail_fb:
    xor rcx, rcx
    lea rdx, [rel err_fb]
    lea r8, [rel err_title]
    mov r9d, 0
    call MessageBoxA
    xor eax, eax

.done:
    add rsp, 40
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; CGXShutdown
; --------------------------------------------
CGXShutdown:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    call _cgxCoreFreeFramebuffer
    call _cgxWin32DestroyWindow

    mov rsp, rbp
    pop rbp
    ret