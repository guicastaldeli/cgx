; ============================================
; constants.inc - Public constants
; ============================================

; --- Clear Masks ---
CGX_COLOR_BIT       equ 0x0004000
CGX_DEPTH_BUT       equ 0x0000100

; --- Primitives ---
CGX_POINTS          equ 0
CGX_LINES           equ 1
CGX_TRIANGLES       equ 2

; --- Buffer Usage Hints ---
CGX_STATIC         equ 0
CGX_DYNAMIC        equ 1
CGX_STREAM         equ 2

; --- Attribute types ---
CGX_FLOAT          equ 0
CGX_UINT           equ 1
CGX_UBYTE          equ 2

; --- Errors ---
CGX_OK             equ 0
CGX_ERR_NOMEM      equ 1
CGX_ERR_WINDOW     equ 2
CGX_ERR_INVALID    equ 3