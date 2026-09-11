; ============================================
; structs.inc - Core (portable) structs
; ============================================

; --- Global CGX state (portable) ---
struc CGXState
    .width          resd 1 ; framebuffer width
    .height         resd 1 ; framebuffer height
    .framebuffer    resq 1 ; pointer to BGRA pixel buffer
    .fbSize         resq 1 ; size in bytes
    .clearR         resd 1 ; clear color R (float)
    .clearG         resd 1 ; clear color G (float)
    .clearB         resd 1 ; clear color B (float)
    .clearA         resd 1 ; clear color A (float)
endstruc
