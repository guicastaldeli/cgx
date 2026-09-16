; ============================================
; structs.inc - Core (portable) structs
; ============================================

; --- Global CGX state (portable) ---
struc CGXState
    .width                  resd 1 ; framebuffer width
    .height                 resd 1 ; framebuffer height
    .framebuffer            resq 1 ; pointer to BGRA pixel buffer
    .fbSize                 resq 1 ; size in bytes
    .clearR                 resd 1 ; clear color R (float)
    .clearG                 resd 1 ; clear color G (float)
    .clearB                 resd 1 ; clear color B (float)
    .clearA                 resd 1 ; clear color A (float)
    .drawColor              resd 1 ; current draw color (0x00RRGGBB)
    .bufferPool             resq 1
    .bufferCount            resd 1
    .bufferCapacity         resd 1
    .nextBufferId           resd 1
    .boundVBO               resd 1
    .boundEBO               resd 1
endstruc

; --- Buffer struct ---
struc Buffer
    .id                     resd 1
    .usage                  resd 1
    .type                   resd 1
    .inUse                  resb 1
    .pad0                   resb 3
    .data                   resq 1
    .size                   resq 1
endstruc

