; ============================================
; api/cgx_graphics_api.asm
;   -> CGXSetClearColor, CGXClear, CGXSwapBuffers
;        CGXPollEvents, CGXShouldClose
;        CGXGetWidth, CGXHeight, CGXSetWindowTitle
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"

extern _cgxCoreSetClearColor
extern _cgxCoreClear
extern _cgxCoreGetWidth
extern _cgxCoreGetHeight
extern _cgxWin32BlitFramebuffer
extern _cgxWin32PollEvents
extern _cgxWin32ShouldClose
extern _cgxWin32GetHWND

extern SetWindowTextA

global CGXSetClearColor
global CGXClear
global CGXSwapBuffers
global CGXPollEvents
global CGXShouldClose
global CGXGetWidth
global CGXGetHeight
global CGXSetWindowTitle

section .text

; --------------------------------------------
; CGXSetClearColor
; Input: xmm0..xmm3 = r,g,b,a
; --------------------------------------------
CGXSetClearColor:
    jmp _cgxCoreSetClearColor

; --------------------------------------------
; CGXClear
; Input: ecx = mask
; --------------------------------------------
CGXClear:
    jmp _cgxCoreClear

; --------------------------------------------
; CGXSwapBuffers
; --------------------------------------------
CGXSwapBuffers:
    jmp _cgxWin32BlitFramebuffer

; --------------------------------------------
; CGXPollEvents
; --------------------------------------------
CGXPollEvents:
    jmp _cgxWin32PollEvents

; --------------------------------------------
; CGXShouldClose
; --------------------------------------------
CGXShouldClose:
    jmp _cgxWin32ShouldClose

; --------------------------------------------
; CGXGetWidth
; --------------------------------------------
CGXGetWidth:
    jmp _cgxCoreGetWidth

; --------------------------------------------
; CGXGetHeight
; --------------------------------------------
CGXGetHeight:
    jmp _cgxCoreGetHeight

; --------------------------------------------
; CGXSetWindowTitle
; Input: rcx = title ptr
; --------------------------------------------
CGXSetWindowTitle:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    mov rdx, rcx
    call _cgxWin32GetHWND
    mov rcx, rax
    call SetWindowTextA

    mov rsp, rbp
    pop rbp
    ret


