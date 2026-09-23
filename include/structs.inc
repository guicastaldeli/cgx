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
    .texPool                resq 1
    .texCount               resd 1
    .texCapacity            resd 1
    .nextTexId              resd 1
    .boundTexture           resd 1
    .activeTexUnit          resd 1
    .texture2DEnabled       resd 1
    .texEnvMode             resd 1
    .drawU                  resd 1
    .drawV                  resd 1
    .shaderPool             resd 1 ; pointer to Shader array (CGX_MAX_SHADERS entries)
    .shaderCount            resd 1
    .nextShaderId           resd 1
    .programPool            resq 1 ; pointer to Program array (CGX_MAX_PROGRAMS entries)
    .programCount           resd 1
    .nextProgramId          resd 1
    .boundProgram           resd 1 ; current program id, 0 fixed-function
    .vertVM                 resb VMState_size
    .fragVM                 resb VMState_size
    .varyingFrag            resb CGX_MAX_VARYINGS * 16 ; 8 vec4 = 128 bytes
    .varyingVert            resb 3 * CGX_MAX_VARYINGS * 16 ; 3 verts x 8 vec4 = 384 bytes
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

; --- Texture struct ---
struc Texture
    .id                     resd 1
    .width                  resd 1
    .height                 resd 1
    .dataSize               resd 1
    .inUse                  resb 1
    .pad0                   resb 3
    .data                   resq 1
    .minFilter              resd 1
    .magFilter              resd 1
    .wrapS                  resd 1
    .wrapT                  resd 1
endstruc

; --- Symbol table entry ---
; Used for uniforms, attributes, varyings, and locals.
; Every declared identifier gets one of these.
struc Symbol
    .name                   resb 32 ; null-terminated identifier (max 31 chars)
    .type                   resb 1  ; CGX_TYPE_*
    .qualifier              resb 1  ; CGX_QUAL_*
    .reg                    resb 1  ; assigned register index (0..255)
    .pad0                   resb 1
    .location               resd 1  ; for uniforms/attribs: external binding location
endstruc

; --- Compiled shader ---
struc Shader
    .id                     resd 1
    .type                   resd 1 ; CGX_VERTEX_SHADER / CGX_FRAGMENT_SHADER
    .inUse                  resb 1
    .compileStatus          resb 1 ; 0 = uncompiled/error, 1 OK
    .pad0                   resb 2
    .source                 resq 1 ; pointer to source string (heap-allocated copy)
    .sourceLen              resd 1
    .instrCount             resd 1
    .instr                  resd 1 ; pointer to bytecode (heap-allocated)
    .infoLog                resq 1 ; pointer to info log buffer (heap-alocated, 1KB)
    .symbolCount            resd 1
    .symbols                resq 1 ; pointer to Symbol array
endstruc

; --- Program (linked shader pair) ---
struc Program
    .id                     resd 1
    .inUse                  resb 1
    .linkStatus             resb 1 ; 0 = unlinked/error, 1 OK
    .pad0                   resb 2
    .vertShader             resd 1 ; shader id or 0
    .fragShader             resd 1 ; shader id or 0
    .uniformCount           resd 1
    .uniforms               resq 1 ; pointer to Uniform[] (from both shaders)
    .attribCount            resd 1
    .attribs                resq 1 ; pointer to Symbol[] (attribs from vertex shader)
    .varyingCount           resd 1
    .varyings               resq 1 ; pointer to Symbol[] (matched varyings)
endstruc

; --- Uniform binding ---
; When linked, copy each unique uniform from both shaders into one array
; and record the register it lives in within each shader.
struc Uniform
    .name                   resb 32
    .type                   resb 1
    .vertReg                resb 1 ; register in vertex shader (or 255 if not used)
    .fragReg                resb 1 ; register in fragment shader (or 255)
    .pad0                   resb 1
    .location               resd 1 ; external location handed out by GetUniformLocation
endstruc

; -- VM execution state ---
struc VMState
    .regs                   resb 256 * 16 ; 256 vec4 registers = 4KB
    .pc                     resd 1        ; program counter
    .instrCount             resd 1
    .instr                  resq 1        ; pointer to bytecode
    .samplers               resd 16       ; texture unit -> texture id map (up to 16 samplers)
endstruc