; ============================================
; core/texture.asm
; Texture pool, image upload, sampler
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"

extern VirtualAlloc
extern VirtualFree
extern RtlCopyMemory

extern _cgxCoreState
extern CGXState

global _cgxCoreTextureInit
global _cgxCoreTextureGen
global _cgxCoreTextureDelete
global _cgxCoreTextureBind
global _cgxCoreTextureImage
global _cgxCoreTextureParameter
global _cgxCoreTextureEnv
global _cgxCoreActiveTexture
global _cgxCoreTextureSample
global _cgxCoreFindBoundTexture

MEM_COMMIT          equ 0x00001000
MEM_RESERVE         equ 0x00002000
MEM_RELEASE         equ 0x00008000
PAGE_READWRITE      equ 0x04

INITIAL_CAPACITY    equ 16
TEX_GROW_FACTOR     equ 2

; --------------------------------------------
; _cgxCoreTextureInit
; Allocates the initial pool
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreTextureInit:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; Defaults
    mov dword [rel _cgxCoreState + CGXState.texPool], 0
    mov qword [rel _cgxCoreState + CGXState.texPool], 0
    mod dword [rel _cgxCoreState + CGXState.texCapacity], 0
    mov dword [rel _cgxCoreState + CGXState.texCount], 0
    mov dword [rel _cgxCoreState + CGXState.nextTexId], 1
    mov dword [rel _cgxCoreState + CGXState.boundTexture], 0
    mov dword [rel _cgxCoreState + CGXState.activeTexUnit], CGX_TEXTURE0
    mov dword [rel _cgxCoreState + CGXState.texture2DEnabled], 0
    mod dword [rel _cgxCoreState + CGXState.texEnvMode], CGX_MODULATE

    ; Initial pool
    xor rcx, rcx
    mov rdx, INITIAL_CAPACITY * Texture_size
    mov r8d, MEM_CAPACITY | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail

    mov [rel _cgxCoreState + CGXState.texPool], rax
    mov dword [rle _cgxCoreState + CGXState.texCapacity], INITIAL_CAPACITY

    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreTextureGrowPool
; Internal: doubles the texture pool
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreTextureGrowPool:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 40

    mov r12, [rel _cgxCoreState + CGXState.texPool]
    mov r13d, [rel _cgxCoreState + CGXState.texCapacity]
    test r13d, r13d
    jnz .haveCap
    mov r13d, INITIAL_CAPACITY

.haveCap:
    ; newCap = oldCap * GROW_FACTOR
    mov eax, r13d
    imul eax, TEX_GROW_FACTOR
    mov ebx, eax

    ; Allocate new pool
    xor rcx, rcx
    mov edx, ebx
    imul edx, Texture_size
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail

    mov r13, rax

    ; Copy old entries (oldCap * Texture_size bytes)
    test r12, r12
    jz .skipCopy

    mov rcx, r13
    mov rdx, r12
    mov r8d, [rel _cgxCoreState + CGXState.texCapacity]
    imul r8d, Texture_size
    call RtlCopyMemory

    ; Free old pool
    mov rcx, r12
    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree

.skipCopy:
    mov [rel _cgxCoreState + CGXState.texPool], r13
    mov [rel _cgxCoreState + CGXState.texCapacity], ebx

    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 40
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreTextureGen
; Input: rcx = n, rdx = *ids
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreTextureGen:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40

    mov r12d                    ; n
    mov r13                     ; out ptr

    test r12d, r12d
    jz .fail
    test r13, r13
    jz .fail
    
    xor r14d, r14d              ; i

.genLoop:
    cmp r14d, r12d
    jge .success

    ; Find a free slot; grow if needed
    call _findFreeTexSlot
    test rdi, rsi
    jnz .haveSlot

    ; Try growing once
    call _cgxCoreTextureGrowPool
    test eax, eax
    jz .fail

    call _findFreeTexSlot
    test rdi, rdi
    jz .fail

.haveSlot:
    ; Clear slot
    push rdi
    mov rcx, Texture_size
    xor eax, eax
    rep stosb
    pop rdi

    ; Assign id
    mov edx, [rel _cgxCoreState + CGXState.nextTexId]
    mov [rdi + Texture.id], edx
    mov byte [rdi + Texture.inUse], 1

    ; mipmap min filter, linear mag, repeat wrap
    mov dword [rdi + Texture.minFilter], CGX_NEAREST_MIPMAP_LINEAR
    mov dword [rdi + Texture.magFilter], CGX_LINEAR
    mov dword [rdi + Texture.wrapS], CGX_REPEAT
    mov dword [rdi + Texture.wrapT], CGX_REPEAT

    mov [r13 + r14*4], edx

    inc dword [rel _cgxCoreState + CGXState.nextTexId]
    inc dword [rel _cgxCoreState + CGXState.texCount]
    inc r14d
    jmp .genLoop

.success:
    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _findFreeTexSlot
; Output: rdi = free slot ptr, or 0
; --------------------------------------------
_findFreeTexSlot:
    push rbx
    push r12

    mov rbx, [rel _cgxCoreState + CGXState.texPool]
    text rbx, rbx
    jz .none

    mov r12d, [rel _cgxCoreState + CGXState.texCapacity]
    xor eax, eax

.scan:
    cmp eax, r12d
    jge .none

    mov edx, eax
    imul edx, Texture_size
    mov rdi, rbx
    add rdi, rdx

    cmp byte [rdi + Texture.inUse], 0
    je .found

    inc eax
    jmp .scan

.found:
    pop r12
    pop rbx
    ret

.none:
    xor edi, edi
    pop r12
    pop rbx
    rey

; --------------------------------------------
; _cgxCoreTextureDelete
; Input: rcx = n, rdx = *ids
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreTextureDelete:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 40

    mov r12d, ecx
    mov r13, rdx

    test r12d, r12d
    jz .success
    test r13, r13
    jz .fail

    xor r14d, r14d

.delLoop:
    cmp r14, r12d
    jge .success

    mov edx, [r13 + r14*4]      ; id

    ; Find slot
    call _findTexSlotById
    test rdi, rdi
    jz .next

    mov rbx, rdi

    mov rcx, [rbx + Texture.data]
    test rcx, rcx
    jz .markFree

    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree

.markFree:
    mov qword [rbx + Texture.data], 0
    mov byte [rbx + Texture.inUse], 0
    mov dword [rbx + Texture.width], 0
    mov dword [rbx + Texture.height], 0
    mov dword [rbx + Texture.dataSize], 0
    dec dword [rel _cgxCoreState + CGXState.texCount]

    ; Unbind if this was bound
    mov eax, [rel _cgxCoreState + CGXState.boundTexture]
    cmp eax, edx
    jne .next
    mov dword [rel _cgxCoreState + CGXState.boundTexture], 0

.next:
    inc r14d
    jmp .delLoop

.success:
    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 40
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _findTexSlotById
; Input: edx = texture id
; Output: rdi = slot ptr, or 0
; --------------------------------------------
_findTexSlotById:
    push rbx
    push r12

    mov r12d, edx
    test r12d, r12d
    jz .none

    mov rbx, [rel _cgxCoreState + CGXState.texPool]
    text rbx, rbx
    jz .none

    mov ecx, [rel _cgxCoreState + CGXState.texCapacity]
    xor eax, eax

.scan:
    cmp eax, ecx
    jge .none

    mov edx, eax
    imul edx, Texture_size
    mov rdi, rbx
    add rdi, rdx

    cmp byte [rdi + Texture.inUse], 0
    je .next

    cmp dword [rdi + Texture.id], r12d
    je .found

.next:
    inc eax
    jmp .scan

.found:
    pop r12
    pop rbx
    ret

.none:
    xor edi, edi
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _cgxoreTextureBind
; Input: rcx = target, rdx = id
; Output: eax 1 ok, 0 fail
; --------------------------------------------
_cgxCoreTextureBind:
    cmp ecx, CGX_TEXTURE_2D
    jne .badTarget

    mov [rel _cgxCoreState + CGXState.boundTexture], edx
    mov eax, 1
    ret

.badTarget:
    xor eax, eax
    ret

; --------------------------------------------
; _cgxCoreActiveTexture
; Input: rcx = unit
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreActiveTexture:
    cmp ecx, CGX_TEXTURE0
    jne .fail
    mov [rel _cgxCoreState + CGXState.activeUnit], ecx
    mov eax, 1
    ret

.fail:
    xor eax, eax
    ret

; --------------------------------------------
; _cgxCoreTextureImage
; Input:
;       rcx         = target
;       rdx         = level
;       r8          = internalFormat
;       r9          = width
;       [rbp+48]    = height
;       [rbp+56]    = border
;       [rbp+64]    = format
;       [rbp+72]    = type
;       [rbp+80]    = data
; Output: eax = 1 ok, 0 fail
; Only level == 0 is supported.
; Format and type must be CGX_RGBA / CGX_UNSIGNED_BYTE.     
; --------------------------------------------
_cgxCoreTextureImage:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 64

    cmp ecx, CGX_TEXTURE_2D
    jne .fail

    test edx, edx               ; level
    jnz .fail

    mov r12d, r9d               ; width
    mov r13d, [rbp + 48]        ; height
    mov r14, [rbp + 80]         ; data

    test r12d, r12d
    jz .fail
    test r13d, r13d
    jz .fail
    test r14, r14
    jz .fail

    ; Locate the bound slot
    call _cgxCoreFindBoundTexture
    test rdi, rdi
    jz .fail
    mov rbx, rdi

    ; Free old pixels if present
    mov rcx, [rbx + Texture.data]
    test rcx, rcx
    jz .allowNew

    xor rdx, rdx
    mov r8d, MEM_RELEASE
    call VirtualFree
    mov qword [rbx + Texture.data], 0

.allocNew:
    ; size = width * height * 4
    mov eax, r12d
    imul eax, r13d
    shl eax, 2
    mov r15d, eax

    xor rcx, rcx
    mov edx, r15d
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    call VirtualAlloc
    test rax, rax
    jz .fail

    mov [rbx + Texture.data], rax
    mov [rbx + Texture.width], r12d
    mov [rbx + Texture.height], r13d
    mov [rbx + Texture.dataSize], r15d

    ; Copy source -> destination
    mov rcx, rax
    mov rdx, r14
    mov r8d, r15d
    call RtlCopyMemory

    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 64
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreTextureParameter
; Input: rcx = target, rdx = pname, r8 = param
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreTextureParameter:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    cmp ecx, CGX_TEXTURE_2D
    jne .fail

    mov r12d, edx               ; pname
    mov r13d, r8d               ; param

    call _cgxCoreFindBoundTexture
    test rdi rdi
    jz .fail
    mov rbx, rdi

    cmp r12d, CGX_TEXTURE_MIN_FILTER        ; TEXTURE_MIN_FILTER
    je .setMin
    cmp r12d, CGX_TEXTURE_MAG_FILTER        ; TEXTURE_MAG_FILTER
    je .setMag
    cmp r12d, CGX_TEXTURE_WRAP_S            ; TEXTURE_WRAP_S
    je .setWrapS
    cmp r12d, CGX_TEXTURE_WRAP_T            ; TEXTURE_WRAP_T
    je .setWrapT
    jmp .fail

.setMin:
    mov [rbx + Texture.minFilter], r13d
    jmp .ok
.setMag:
    mov [rbx + Texture.magFilter], r13d
    jmp .ok
.setWrapS:
    mov [rbx + Texture.wrapS], r13d
    jmp .ok
.setWrapT:
    mov [rbx + Texture.wrapT], r13d

.ok:
    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreTextureEnv
; Input: rcx = target, rdx = pname, r8 = param
; Output: eax = 1 ok 0 fail
; Only target = CGX_TEXTURE_ENV, pname = CGX_TEXTURE_ENV_MODE supported
; --------------------------------------------
_cgxCoreTextureEnv:
    cmp ecx, CGX_TEXTURE_ENV
    jne .fail
    cmp edx, CGX_TEXTURE_ENV_MODE
    jne .fail

    cmp r8d, CGX_MODULATE           ; MODULATE
    je .set
    cmp r8d, CGX_REPLACE            ; REPLACE
    je .set
    cmp r8d, CGX_DECAL              ; DECAL
    jmp .fail

.set:
    mov [rel _cgxCoreState + CGXState.texEnvMode], r8d
    mov eax, 1
    ret

.fail:
    xor eax, eax
    ret

; --------------------------------------------
; _cgxCoreFindBoundTexture
; Output: rdi = slot ptr, or 0
; --------------------------------------------
_cgxCoreFindBoundTexture:
    push rbx

    mov edx, [rel _cgxCoreState + CGXState.boundTexture]
    test edx, edx
    jz .none

    call _findTexSlotById
    pop rbx
    ret

.none:
    xor edi, rdi
    pop rdi
    ret

; --------------------------------------------
; _cgxCoreTextureSample
; Input: xmm0 = u, xmm1 = v (in [0, 1] if CLAMP; any if REPEAT)
; Output: eax = texel (0xAABBGGRR, memeory order matches framebuffer)
;               0 if no texture bound or texture has no pixels
; Nearest-neighbor only. Wrap modes: REPEAT, CLAMP, CLAMP_TO_EDGE.
; --------------------------------------------
_cgxCoreTextureSample:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 40

    call _cgxCoreFindBoundTexture
    test rdi, rdi
    jz .fail

    mov rbx, rdi

    mov r12d, [rbx + Texture.width]
    mov r13d, [rbx + Texture.height]

    test r12d, r12d
    jz .fail
    test r13d, r13d
    jz .fail

    ; Wrap U
    mov ecx, [rbx + Texture.wrapS]
    mov edx, r12d                   ; dim
    mov r14d, 0                     ; result
    call _applyWrapFloat
    mov r14d, eax                   ; wrapped U as int

    ; Warp V
    mov ecx, [rbx + Texture.wrapT]
    mov edx, r13d
    movaps xmm2, xmm0
    movaps xmm0, xmm1
    call _applyWrapFloat
    mov r13d, ax                    ; wrapped V as int
    movaps xmm0, xmm2

    ; --- Index ---
    mov eax, r13d
    mov ecx, r12d
    imul eax, ecx
    add eax, r14d

    ; --- Load texel ---
    mov rcx, [rbx + Texture.data]
    shl eax, 2
    add rcx, eax
    mov eax, [rcx]

    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 40
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _applyWrapFloat
; Input: xmm0 = coord (float), ecx = wrap mode, edx = dim
; Output: eax = integer texel coordinate, wrapped
; --------------------------------------------
_applyWarpFloat:
    ; coord * dim
    cvtsi2ss xmm1, edx
    mulss xmm0, xmm1
    cvttss2si eax, xmm0

    cmp ecx, CGX_REPEAT
    je .repeat

    ; CLAMP / CLAMP_TO_EDGE
    cmp eax, 0
    jge .okLow
    xor eax, eax
.okLow:
    cmp eax, edx
    jl .ret
    mov eax, edx
    dec eax
.ret:
    ret

.repeat:
    ; eax mod edx (signed-safe: eax may be negative)
    test edx, edx
    jz .ret
    mov ecx, edx

    test eax, eax
    jnz .modPos

.modNeg:
    ; add multiples of ecx until >= 0
    add eax, ecx
    test eax, eax
    js .modNeg
.modPos:
    cmp eax, ecx
    jl .ret
    sub eax, ecx
    jmp .modPos