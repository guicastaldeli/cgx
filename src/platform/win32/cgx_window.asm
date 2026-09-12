; ============================================
; platform/win32/cgx_window.asm - Win32 window
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"
%include "platform/win32.inc"

extern GetModuleHandleA
extern RegisterClassExA
extern CreateWindowExA
extern ShowWindow
extern UpdateWindow
extern GetMessageA
extern PeekMessageA
extern TranslateMessage
extern DispatchMessageA
extern DefWindowProcA
extern PostQuitMessage
extern DestroyWindow
extern GetClientRect

global _cgxWin32CreateWindow
global _cgxWin32DestroyWindow
global _cgxWin32PollEvents
global _cgxWin32ShouldClose
global _cgxWin32GetHWND
global _cgxWin32GetDC
global _cgxWin32GetWidth
global _cgxWin32GetHeight
global _cgxWin32GetState
global _cgxWin32State

; --- Constants ---
CS_HREDRAW              equ 0x0002
CS_VREDRAW              equ 0x0001
WS_OVERLAPPEDWINDOW     equ 0x00CF0000
SW_SHOWNORMAL           equ 0x0001
WM_DESTROY              equ 0x0002
PM_REMOVE               equ 0x0001
NULL                    equ 0

; --- Keys ---
WM_KEYDOWN              equ 0x0100
WM_KEYUP                equ 0x0101
WM_MOUSEMOVE            equ 0x0200
WM_LBUTTONDOWN          equ 0x0201
WM_LBUTTONUP            equ 0x0202
WM_RBUTTONDOWN          equ 0x0204
WM_RBUTTONUP            equ 0x0205
WM_MBUTTONDOWN          equ 0x0207
WM_MBUTTONUP            equ 0x0208

section .data
    _win32ClassName db "CGXWindowClass", 0

section .bss
    _cgxWin32State resb CGXWin32State_size

section .text

; --------------------------------------------
; _cgxWin32CreateWindow
; Input: ecx = width, edx = height, r8 title ptr
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxWin32CreateWindow:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 96

    mov r12d, ecx       ; width
    mov r13d, edx       ; height
    mov r14, r8         ; title

    ; Get Instance
    xor rcx, rcx
    call GetModuleHandleA
    mov [rel _cgxWin32State + CGXWin32State.hInstance], rax
    mov rbx, rax

    ; --- Register window class ---
    ; Zero WNDCLASSEX (80 bytes on stack)
    lea rdi, [rsp]
    xor eax, eax
    mov ecx, 20
    rep stosd

    lea rdi, [rsp]
    mov dword [rdi + 0], 80
    mov dword [rdi + 4], CS_HREDRAW | CS_VREDRAW
    lea rax, [rel _cgxWin32WndProc]
    mov qword [rdi + 8], rax        ; lpfnWndProc
    mov dword [rdi + 16], 0         ; cbClsExtra
    mov dword [rdi + 20], 0         ; cbWndExtra
    mov qword [rdi + 24], rbx       ; hInstance
    mov qword [rdi + 32], 0         ; hIcon
    mov qword [rdi + 40], 0         ; hCursor
    mov qword [rdi + 48], 0         ; hbrBackground
    mov qword [rdi + 56], 0         ; lpszMenuName
    lea rax, [rel _win32ClassName]
    mov qword [rdi + 64], rax       ; lpszClassName
    mov qword [rdi + 72], 0         ; hIconSm

    mov rcx, rdi
    call RegisterClassExA
    test eax, eax
    jz .fail

    ; --- Create window ---
    ; Prepare stack args (5th onward)
    ; CreateWindowExA(exStyle, className, title, style,
    ;                    x, y, w, h, parent, menu, hInstance, param)
    sub rsp, 96                     ; shadow space + stack args
    mov qword [rsp + 32], 0         ; x
    mov qword [rsp + 40], 0         ; y
    mov qword [rsp + 48], r12       ; width
    mov qword [rsp + 56], r13       ; height
    mov qword [rsp + 64], 0         ; parent
    mov qword [rsp + 72], 0         ; menu
    mov qword [rsp + 80], rbx       ; hInstance
    mov qword [rsp + 88], 0         ; param

    xor rcx, rcx
    lea rdx, [rel _win32ClassName]
    mov r8, r14
    mov r9d, WS_OVERLAPPEDWINDOW
    call CreateWindowExA
    add rsp, 96

    test rax, rax
    jz .fail

    mov [rel _cgxWin32State + CGXWin32State.hwnd], rax

    ; Show Window
    mov rcx, rax
    mov edx, SW_SHOWNORMAL
    call ShowWindow

    mov rcx, [rel _cgxWin32State + CGXWin32State.hwnd]
    call UpdateWindow

    mov byte [rel _cgxWin32State + CGXWin32State.shouldClose], 0
    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 96
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxWin32DestroyWindow
; --------------------------------------------
_cgxWin32DestroyWindow:
    push rbp
    mov rbp, rsp
    sub rsp, 48

    mov rcx, [rel _cgxWin32State + CGXWin32State.hwnd]
    test rcx, rcx
    jz .done
    call DestroyWindow

.done:
    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; _cgxWin32PollEvents
; Non-blocking peek of Win32 messages
; --------------------------------------------
_cgxWin32PollEvents:
    push rbp
    mov rbp, rsp
    sub rsp, 48

.loop:
    lea rcx, [rel _cgxWin32State + CGXWin32State.msg]
    xor rdx, rdx            ; hWnd filter
    xor r8d, r8d            ; min
    xor r9d, r9d            ; max
    mov qword [rsp + 32], PM_REMOVE
    call PeekMessageA
    test eax, eax
    jz .done

    lea rcx, [rel _cgxWin32State + CGXWin32State.msg]
    call TranslateMessage

    lea rcx, [rel _cgxWin32State + CGXWin32State.msg]
    call DispatchMessageA
    jmp .loop

.done:
    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; _cgxWin32ShouldClose
; Output: eax = 1 if should close
; --------------------------------------------
_cgxWin32ShouldClose:
    movzx eax, byte [rel _cgxWin32State + CGXWin32State.shouldClose]
    ret

; --------------------------------------------
; _cgxWin32GetHWND
; --------------------------------------------
_cgxWin32GetHWND:
    mov rax, [rel _cgxWin32State + CGXWin32State.hwnd]
    ret

; --------------------------------------------
; _cgxWin32GetDC
; --------------------------------------------
_cgxWin32GetDC:
    mov rax, [rel _cgxWin32State + CGXWin32State.hdc]
    ret

; --------------------------------------------
; _cgxWin32GetState
; --------------------------------------------
_cgxWin32GetState:
    lea rax, [rel _cgxWin32State]
    ret

; --------------------------------------------
; _cgxWin32GetWidth
; --------------------------------------------
_cgxWin32GetWidth:
    xor eax, eax
    ret

; --------------------------------------------
; _cgxWin32GetHeight
; --------------------------------------------
_cgxWin32GetHeight:
    xor eax, eax
    ret

; --------------------------------------------
; Window procedure (internal)
; --------------------------------------------
_cgxWin32WndProc:
    push rbp
    mov rbp, rsp
    sub rsp, 48

    ; rcx = hWnd
    ; rdx = uMsg
    ; r8 = wParam
    ; r9 = lParam
    mov [rsp + 0], rcx
    mov [rsp + 8], rdx
    mov [rsp + 16], r8
    mov [rsp + 24], r9

    cmp edx, WM_DESTROY
    je .onDestroy

    ; Input
    cmp edx, WM_KEYDOWN
    je .onKeyDown
    cmp edx, WM_KEYUP
    je .onKeyUp
    cmp edx, WM_MOUSEMOVE
    je .onMouseMove
    cmp edx, WM_LBUTTONDOWN
    je .onLButtonDown
    cmp edx, WM_LBUTTONUP
    je .onLButtonUp
    cmp edx, WM_RBUTTONDOWN
    je .onRButtonDown
    cmp edx, WM_RBUTTONUP
    je .onRButtonUp
    cmp edx, WM_MBUTONDOWN
    je .onMButtonDown
    cmp edx, WM_MBUTTONUP
    je .onMButtonUp

    ; Default handling
    mov rcx, [rsp + 0]
    mov rdx, [rsp + 8]
    mov r8, [rsp + 16]
    mov r9, [rsp + 24]
    call DefWindowProcA
    jmp .finish

.onDestroy:
    mov byte [rel _cgxWin32State + CGXWin32State.shouldClose], 1
    xor rcx, rcx
    call PostQuitMessage
    xor eax, eax

.onKeyDown:
    ; wParam (r8): virtual key code
    movzx eax, r8b
    mov byte [rel _cgx32State + CGX32State.keys + rax], 1
    xor eax, eax
    jmp .finish

.onKeyUp:   
    movzx eax, r8b
    mov byte [rel _cgxWin32State + CGXWin32State.keys + rax], 0
    xor eax, eax
    jmp .finish

.onMouseMove:
    ; lParam (r9): low word = X, high word = Y
    mov eax, r9d
    and eax, 0xFFFF
    mov [rel _cgxWin32State + CGXWinState.mouseX], eax

    mov eax, r9d
    shr eax, 16
    and eax, 0xFFFF
    mov [rel _cgxWin32State + CGXWinState.mouseY], eax

    xor eax, eax
    jmp .finish

.onLButtonDown:
    mov byte [rel _cgxWin32State + CGXWin32State.mouseButtons + 0], 1
    xor eax, eax
    jmp .finish

.onLButtonUp:
    mov byte [rel _cgxWin32State + CGXWin32State.mouseButtons + 0], 0
    xor eax, eax
    jmp .finish

.onRButtonDown:
    mov byte [rel _cgxWin32State + CGXWin32State.mouseButtons + 2], 1
    xor eax, eax
    jmp .finish

.onRButtonUp:
    mov byte [rel _cgxWin32State + CGXWin32State.mouseButtons + 2], 0
    xor eax, eax
    jmp .finish

.onMButtonDown:
    mov byte [rel _cgxWin32State + CGXWin32State.mouseButtons + 1], 1
    xor eax, eax
    jmp .finish

.onMButtonUp:
    mov byte [rel _cgxWin32State + CGXWin32State.mouseButtons + 1], 0
    xor eax, eax

.finish:
    mov rsp, rbp
    pop rbp
    ret