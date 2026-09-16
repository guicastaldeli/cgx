; ============================================
; platform/win32/cgx_timer.asm
; High-resolution timing via QueryPerformanceCounter
; ============================================

default rel

%include "platform/win32.inc"

extern QueryPermormanceCounter
extern QueryPerformanceFrequency

extern _cgxWin32State
extern CGXWin32State

global _cgxWin32TimerInit
global _cgxWin32GetTime
global _cgxWin32GetTimeDelta

section .data
    one_double db 1.0

section .text

; --------------------------------------------
; _cgxWin32TimerInit
; Output: eax = 1 ok, 0 fail
; Initializes perf frequency and start time
; --------------------------------------------
_cgxWin32TimerInit:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; QueryPerformanceFrequency(&freq)
    lea rcx, [rel _cgxWin32State + CGXWin32State.prefFreq]
    call QueryPerformanceFrequency
    test eax, eax
    jz .fail

    ; QueryPerformanceCounter(&startTime)
    lea rcx, [rel _cgxWin32State + CGXWin32State.startTime]
    call QueryPerformanceCounter
    test eax, eax
    jz .fail

    ; lastTime = startTime
    mov rax, [rel _cgxWin32State + CGXWin32State.startTime]
    mov [rel _cgxWin32State + CGXWin32State.lastTime], rax

    mov byte [rel _cgxWin32State + CGXWin32State.timerInit], 1
    mov eax, 1
    jmp .done

.fail:
    mov byte [rel _cgxWin32State + CGXWin32State.timerInit], 0
    xor eax, eax

.done:
    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; _cgxWin32GetTime
; Output: xmm0 = seconds (double) since timer init
; --------------------------------------------
_cgxWin32GetTime:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; Check timer initialized
    cmp byte [rel _cgxWin32State + CGXWin32State.timerInit], 0
    jne .ok
    call _cgxWin32TimerInit

.ok:
    ; QueryPerformanceCounter(&now)
    sub rsp, 16
    lea rcx, [rsp]
    call QueryPerformanceCounter
    mov rax, [rsp]
    add rsp, 16

    ; elapsed = now - startTime
    sub rax, [rel _cgxWin32State + CGXWin32State.startTime]

    ; Convert to double
    cvtsi2sd xmm0, rax

    ; seconds = elapsed / freq
    cvtsi2sd xmm1, qword [rel _cgxWin32State + CGXWin32State.prefFreq]
    divsd xmm0, xmm1

    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; _cgxWin32GetTimeDelta
; Output: xmm0 = seconds (double) since last call
; --------------------------------------------
_cgxWin32GetTimeDelta:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; QueryPerformanceCounter(&now)
    sub rsp, 16
    lea rcx, [rsp]
    call QueryPerformanceCounter
    mov rax, [rsp]
    add rsp, 16

    ; delta = now - lastTime
    mov rcx, [rel _cgxWin32State + CGXWin32State.lastTime]
    sub rax, rcx

    ; Save now as lastTime
    mov rcx, [rel _cgxWin32State + CGXWin32State.lastTime]
    add rcx, rax
    mov [rel _cgxWin32State + CGXWin32State.lastTime], rcx

    ; Convert to double
    cvtsi2sd xmm0, rax

    ; seconds = delta / freq
    cvtsi2sd xmm1, qword [rel _cgxWin32State + CGXWin32State.prefFreq]
    divsd xmm0, xmm1

    mov rsp, rbp
    pop rbp
    ret