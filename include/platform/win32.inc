; ============================================
; platform/win32.inc - Win32-specific state
; Only included by platform/win32/*.asm
; ============================================

; --- Win32 window state ---
struc CGXWin32State
    .hwnd               resq 1
    .hInstance          resq 1
    .hdc                resq 1
    .msg                resb 48 ; MSG struct
    .shouldClose        resb 1
    .bmi                resb 44 ; BITMAPINFOHEADER (40) + 4 padding
    .keys               resb 256
    .mouseX             resd 1
    .mouseY             resd 1
    .mouseButtons       resb 3
    .padding            resb 1
endstruc