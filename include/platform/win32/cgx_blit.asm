; ============================================
; platform/win32/cgx_blit.asm
; Framebuffer -> window
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"
%include "platform/win32.inc"

extern GetDC
extern ReleaseDC
extern StretchDIBits

extern _cgxWin32GetState
extern _cgxWin32GetHWND
extern _cgxCoreGetFramebuffer
extern _cgxCoreGetWidth
extern _cgxCoreGetHeight

extern CGXWin32State

global _cgxWin32InitBlit
global _cgxWin32BlitFramebuffer

SRCCOPY             equ 0x00CC0020
DIB_RGB_COLORS      equ 0

section .text

; --------------------------------------------
; _cgxWin32InitBlit
; Prepares BITMAPINFOHEADER...
; --------------------------------------------
_cgxWin32InitBlit:
    push rbp
    mov rbp, rsp
    push rbx

    lea rbx, [rel _cgxWin32State + CGXWin32.bmi]

    call _cgxCoreGetWidth
    mov ecx, eax
    call _cgxCoreGetHeight
    mov edx, eax

    mov dword [rbx + 0], 40     ; biSize
    mov dword [rbx + 4], ecx    ; biWidth
    mov dword [rbx + 8], edx    ; biHeight
    mov word [rbx + 12], 1      ; biPlanes
    mov word [rbx + 14], 32     ; biBitCount
    mov dword [rbx + 16], 0     ; biCompression = BI_RGB
    mov dword [rbx + 20], 0
    mov dword [rbx + 24], 0
    mov dword [rbx + 28], 0
    mov dword [rbx + 28], 0
    mov dword [rbx + 32], 0
    mov dword [rbx + 36], 0

    pop rbx
    mov rbp
    ret

; --------------------------------------------
; _cgxWin32BlitFramebuffer
; Blits the CGX framebuffer to the window
; --------------------------------------------
_cgxWin32BlitFramebuffer:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 128

    ; Get framebuffer pointer + dims
    call _cgxCoreGetFramebuffer
    mov r12, rax
    call _cgxCoreGetWidth
    mov r13d, eax
    call _cgxCoreGetHeight
    mov ebx, eax

    ; Get HDC
    mov rcx, [rel _cgxWin32 + CGXWin32State.hwnd]
    call GetDC
    mov [rel _cgxWin32State + CGXWin32State.hdc], rax

    ; StretchDIBits(hdc, xDst, yDst, wDst, hDst, xSrc, ySrc, wSrc, hSrc, bits, bmiusage, rop)
    mov rcx, rax                                ; hdc
    xor edx, edx                                ; xDest
    xor r8d, r8d                                ; yDest
    mov r9d, r13d                               ; DestWidth

    mov [rsp + 32], rbx                         ; DestHeight
    mov qword [rsp + 40], 0                     ; xSrc
    mov qword [rsp + 48], 0                     ; ySrc
    mov [rsp + 56], r13                         ; SrcWidth
    mov [rsp + 64], rbx                         ; SrcHeight
    mov [rsp + 72], r12                         ; lpBits
    lea rax, [rel _cgxWin32State + CGXWinState.bmi]
    mov [rsp + 80], rax                         ; lpbmi
    mov qword [rsp + 88], DIB_RGB_COLORS        ; iUsage
    mov qword [rsp + 96], SRCCOPY               ; rop

    call StretchDIBits

    ; Release DC
    mov rcx, [rel _cgxWin32State + CGXWin32State.hwnd]
    mov rdx, [rel _cgxWin32State + CGXWin32State.hdc]
    call ReleaseDC

    add rsp, 128
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret