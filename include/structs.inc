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
    .vaoPool                resq 1
    .vaoCount               resd 1
    .vaoCapacity            resd 1
    .nextVaoId              resd 1
    .boundVAO               resd 1
    .depthBuffer            resq 1
    .depthFunc              resd 1
    .drawDepth              resd 1
    .depthTestEnabled       resb 1
    .padDepth               resb 3
    .matrixMode             resd 1
    .mvTop                  resd 1
    .projTop                resd 1
    .padM                   resd 1
    .mvStack                resb 64 * 32
    .projStack              resb 64 * 32
    .cullFaceEnabled        resd 1
    .cullMode               resd 1
    .frontFace              resd 1
    .blendEnabled           resd 1
    .blendSrc               resd 1
    .blendDst               resd 1
    .drawAlpha              resd 1
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

; --- Attribute struct ---
struc Attrib
    .enabled                resb 1
    .size                   resb 1
    .type                   resb 1
    .normalized             resb 1
    .stride                 resd 1
    .offset                 resd 1
endstruc

; --- VAO struct ---
struc VAO
    .id                     resd 1
    .vbo                    resd 1
    .ebo                    resd 1
    .inUse                  resb 1
    .pad0                   resb 3
    .attribs                resb Attrib_size * 16
endstruc
