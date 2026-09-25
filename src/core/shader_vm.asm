; ============================================
; core/shader_vm.asm
; Register-based bytecode interpreter
; Executes Instr stream over a VMState
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"
%include "shader.inc"

extern _cgxCoreState
extern CGXState

global _cgxCoreVMExecute
global _cgxCoreVMReset

section .text

; --------------------------------------------
; _cgxCoreVMExecute
; Input: rcx = VMState ptr
;       rdx = Instr array ptr
;       r8 = instruction count
; Output: eax = 1 on success, 0 on error
; --------------------------------------------
_cgxCoreVMExecute:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 56

    mov r12, rcx            ; VMState
    mov r13, rdx            ; Instr array
    mov r14d, r8d           ; instruction count
    xor r15d, r15d          ; pc

.execLoop:
    cmp r15d, r14d
    jge .done

    ; instruction ptr = instrs + pc * Instr_size
    mov eax, r15d
    imul eax, Instr_size
    mov rbx, r13
    add rbx, rax
    ; rbx = current instruction

    mov eax, [rbx + Instr.op]

    ; HALT
    cmp eax, CGX_OP_HALT
    je .done

    ; NOP
    cmp eax, CGX_OP_NOP
    je .next

    ; MOV
    cmp eax, CGX_OP_MOV
    je .opMov

    ; ADD
    cmp eax, CGX_OP_ADD
    je .opAdd

    ; SUB
    cmp eax, CGX_OP_SUB
    je .opSub

    ; MUL
    cmp eax, CGX_OP_MUL
    je .opMul

    ; DOT
    cmp eax, CGX_OP_DOT
    je .opDot

    ; CROSS
    cmp eax, CGX_OP_CROSS
    je .opCross

    ; NORMALIZE
    cmp eax, CGX_OP_NORMALIZE
    je .opNormalize

    ; LENGTH
    cmp eax, CGX_OP_LENGTH
    je .opLength

    ; MIX
    cmp eax, CGX_OP_MIX
    je .opMix

    ; CLAMP
    cmp eax, CGX_OP_CLAMP
    je .opClamp

    ; TEXTURE2D
    cmp eax, CGX_OP_TEXTURE2D
    je .opTexture2D

    ; MAT_MUL_VEC4
    cmp eax, CGX_OP_MAT4_MUL_VEC4
    je .opMat4MulVec4

    ; VEC4_MUL_MAT4
    cmp eax, CGX_OP_VEC4_MUL_MAT4
    je .opVec4MulMat4

    ; NEG
    cmp eax, CGX_OP_NEG
    je .opNeg

    ; SWIZZLE
    cmp eax, CGX_OP_SWIZZLE
    je .opSwizzle

    ; Unknown op -- skip
    jmp .next

;;;;;;;;;;
; MOV
; if srcA == -1, load from srcB.x; else copy srcA to dst
;;;;;;;;;;
.opMov:
    mov eax, [rbx + Instr.dst]
    cmp eax, -1
    je .next
    cmp eax, 255
    jg .next

    ; dst reg ptr
    shl eax, 4              ; * 16
    lea rdi, [r12 + VMState.regs + rax]

    mov ecx, [rbx + Instr.srcA]
    cmp ecx, -1
    je .movImm

    ; Copy from srcA
    shl ecx, 4
    lea rsi, [r12 + VMState.regs + rcx]
    movups xmm0, [rsi]
    movups [rdi], xmm0
    jmp .next

.movImm:
    ; Broadcast srcB (float bits) into all 4 channels
    mov ecx, [rbx + Instr.srcB]
    movd xmm0, ecx
    shufps xmm0, xmm0, 0x00
    movups [rdi], xmm0
    jmp .next

;;;;;;;;;;
; Binary componentwise ops
;;;;;;;;;;
.opAdd:     ; ADD
    call _loadAB
    addps xmm2, xmm3
    call _storeD
    jmp .next

.opSub:     ; SUB
    call _loadAB
    subps xmm2, xmm3
    call _storeD
    jmp .next

.opMul:     ; MUL
    call _loadAB
    mulps xmm2, xmm3
    call _storeD
    jmp .next

.opDiv:     ; DIV
    call _loadAB
    divps xmm2, xmm3
    call _storeD
    jmp .next

;;;;;;;;;;
; DOT
; dst.x = sum(srcA * srcB)
;;;;;;;;;;
.opDot:
    call _loadAB
    mulps xmm2, xmm3
    ; horizontal sum
    movaps xmm4, xmm2
    shufps xmm4, xmm4, 0x4E         ; (z,w,x,y)
    addps xmm2, xmm4
    movaps xmm4, xmm2
    shufps xmm4, xmm4, 0xB1         ; (y,x,w,z)
    addps xmm2, xmm4
    
    call _storeDSplat
    jmp .next

;;;;;;;;;;
; CROSS
; dst.xyz = cross(srcA.xyz, scrB.xyz)
;;;;;;;;;;
.opCross:
    call _loadAB
    ; xmm2 = A, xmm3 = B
    ; cross (A.y*B.z - A.z*B.y, A.z*B.x - A.x*B.z, A.x*B.y - A.y*B.x)
    ; Broadcast components via shuffles
    ; A.xyz, B.zxy
    movaps xmm4, xmm2
    shufps xmm4, xmm4, 0xC9             ; yzx?
    
    movss xmm5, xmm2
    shufps xmm5, xmm5, 0x55             ; A.y
    movss xmm6, xmm3
    shufps xmm6, xmm6, 0xAA             ; B.z
    mulss xmm5, xmm6                    ; A.y * B.z

    movss xmm6, xmm2
    shufps xmm6, xmm6, 0xAA             ; A.z
    movss xmm7, xmm3
    shufps xmm7, xmm7, 0x55             ; B.y
    mulss xmm6, xmm7                    ; A.z * B.y

    subss xmm5, xmm6                    ; x = A.y*B.z - A.z*B.y

    movss xmm6, xmm2
    shufps xmm6, xmm6, 0xAA             ; A.z
    movss xmm7, xmm3
    shufps xmm7, xmm7, 0x00             ; B.x
    mulss xmm6, xmm7                    ; A.z * B.x

    movss xmm7, xmm2
    shufps xmm7, xmm7, 0x00             ; A.x
    movss xmm0, xmm3
    shufps xmm0, xmm0, 0xAA             ; B.z
    mulss xmm7, xmm0                    ; A.x * B.z

    subss xmm6, xmm7                    ; y = A.z*B.x - A.x*B.z

    movss xmm7, xmm2
    shufps xmm7, xmm7, 0x00             ; A.x
    movss xmm0, xmm3
    shufps xmm0, xmm0, 0x55             ; B.y
    mulss xmm7, xmm0                    ; A.x * B.y

    movss xmm0, xmm2
    shufps xmm0, xmm0, 0x55             ; A.y
    movss xmm1, xmm3
    shufps xmm1, xmm1, 0x00             ; B.x
    mulss xmm0, xmm1                    ; A.y * B.x

    subss xmm7, xmm0                    ; z = A.x*B.y - A.y*B.x

    ; Pack (x, y, z, 0)
    unpcklps xmm5, xmm6                 ; (x, y, ., .)
    unpcklps xmm7, xmm5

    pxor xmm4, xmm4
    movss xmm4, xmm5
    movss xmm0, xmm6
    shufps xmm0, xmm0, 0x00

    movaps xmm2, xmm4
    call _storeDSplat

    jmp .next

;;;;;;;;;;
; NORMALIZE
; dst = normaluze(srcA)
;;;;;;;;;;
.opNormalize:
    mov eax, [rbx + Instr.srcA]
    shl eax, 4
    lea rsi, [r12 + VMState.regs + rax]
    movups xmm2, [rsi]

    ; len = sqrt(dot(v, v))
    movaps xmm4, xmm2
    mulps xmm4, xmm4
    movaps xmm5, xmm4
    shufps xmm5, xmm5, 0x4E
    addps xmm4, xmm5
    movaps xmm5, xmm4
    shufps xmm5, xmm5, 0xB1
    addps xmm4, xmm5
    sqrtss xmm4, xmm4

    ; divide
    movaps xmm5, xmm4
    shufps xmm5, xmm5, 0x00
    divps xmm2, xmm5
    call _storeDSplat

    mov eax, [rbx + Instr.dst]
    cmp eax, -1
    je .next
    shl eax, 4
    lea rdi, [r12 + VMState.regs + rax]
    movups [rdi], xmm2
    jmp .next

;;;;;;;;;;
; LENGTH
; dst.x = length(srcA)
;;;;;;;;;;
.opLength:
    mov eax, [rbx + Instr.srcA]
    shl eax, 4
    lea rsi, [r12 + VMState.regs + rax]
    movups xmm2, [rsi]
    mulps xmm2, xmm2
    movaps xmm5, xmm2
    shufps xmm5, xmm5, 0x4E
    addps xmm2, xmm5
    movaps xmm5, xmm2
    shufps xmm5, xmm5, 0xB1
    addps xmm2, xmm5
    sqrtss xmm2, xmm2
    call _storeDSplat
    jmp .next

;;;;;;;;;;
; MIX
; dst = srcA*(1-srcC) + srcB*srcC
;;;;;;;;;;
.opMix:
    ; Load A, B, C
    mov eax, [rbx + Instr.srcA]
    shl eax, 4
    movups xmm2, [r12 + VMState.regs + rax]
    mov eax, [rbx + Instr.srcB]
    shl eax, 4
    movups xmm3, [r12 + VMState.regs + rax]
    mov eax, [rbx + Instr.srcC]
    shl eax, 4
    movups xmm4, [r12 + VMState.regs + rax]

    ; one = 1.0 in all channels
    mov eax, 0x3F800000
    movd xmm5, eax
    shufps xmm5, xmm5, 0x00

    subps xmm5, xmm5                    ; (1-C)
    mulps xmm2, xmm5                    ; A * (1-C)
    mulps xmm3, xmm4                    ; B * C
    addps xmm2, xmm3
    call _storeDFull
    jmp .next

;;;;;;;;;;
; CLAMP
; dst = clamp(srcA, srcB, srcC)
;;;;;;;;;;
.opClamp:
    mov eax, [rbx + Instr.srcA]
    shl eax, 4
    movups xmm2, [r12 + VMState.regs + rax]
    mov eax, [rbx + Instr.srcB]
    shl eax, 4
    movups xmm3, [r12 + VMState.regs + rax]
    mov eax, [rbx + Instr.srcC]
    shl eax, 4
    movups xmm4, [r12 + VMState.regs + rax]

    ; max(srcA, srcB)
    maxps xmm2, xmm3
    ; min(result, srcC)
    minps xmm2, xmm4
    call _storeDFull
    call _storeDFull
    jmp .next

;;;;;;;;;;
; TEXTURE2D
; dst = texture2D(sampler[srcA], srcB.xy)
; Uses the texture system
;;;;;;;;;;
.opTexture2D:
    mov eax, [rbx + Instr.dst]
    cmp eax, -1
    je .next

    ; Read UV from srcB reg
    mov ecx, [rbx + Instr.srcB]
    shl ecx, 4
    lea rsi, [r12 + VMState.regs + rcx]
    movss xmm0, [rsi]                       ; .x = u
    movss xmm1, [rsi + 4]                   ; .y = v

    ; Sampler: srcA holds the unit index (on int in .x)
    mov ecx, [rbx + Instr.srcA]
    shl ecx, 4
    lea rsi, [r12 + VMState.regs + rcx]

    mov eax, 0x3F800000
    movd xmm2, eax
    shufps xmm2, xmm2, 0x00
    mov eax, [rbx + Instr.dst]
    shl eax, 4
    lea rdi, [r12 + VMState.regs + rax]
    movups [rdi], xmm2
    jmp .next

;;;;;;;;;;
; MAT_MUL_VEC4
; dst = mat4(srcA) * vec4(srcB)
; mat4 occupies 4 consecutives registers starting at srcA
;;;;;;;;;;
.opMat4MulVec4:
    ; Load vec4 from srcB
    mov eax, [rbx + Instr.srcB]
    shl ecx, 4
    lea rsi, [r12 + VMState.regs + rax]
    movups xmm4, [rsi]                      ; (x, y, z, w)

    ; Broadcast each component
    movaps xmm5, xmm4
    shufps xmm5, xmm5, 0x00                 ; x
    movaps xmm6, xmm4
    shufps xmm6, xmm6, 0x55                 ; y
    movaps xmm7, xmm4
    shufps xmm7, xmm7, 0xAA                 ; z
    movaps xmm8, xmm4
    shufps xmm8, xmm8, 0xFF                 ; w

    ; Load mat4 columns
    mov eax, [rbx + Instr.srcA]
    shl eax, 4
    lea rsi, [r12 + VMState.regs + rax]
    movups xmm0, [rsi]                      ; col0
    movups xmm1, [rsi + 16]                 ; col1
    movups xmm2, [rsi + 32]                 ; col2
    movups xmm3, [rsi + 48]                 ; col3

    mulps xmm0, xmm5
    mulps xmm1, xmm6
    mulps xmm2, xmm7
    mulps xmm3, xmm8
    addps xmm0, xmm1
    addps xmm2, xmm3
    addps xmm0, xmm2

    ; Store to dst
    mov eax, [rbx + Instr.dst]
    cmp eax, -1
    je .next
    shl eax, 4
    lea rdi, [r12 + VMState.regs + rax]
    movups [rdi], xmm0
    jmp .next

;;;;;;;;;;
; VEC4_MUL_MAT4
; dst = vec4(srcA) * mat4(srcB)
;;;;;;;;;;
.opVec4MulMat4:
    ;  TODO: finish later
    jmp .next

;;;;;;;;;;
; NEG
; dst = -srcA
;;;;;;;;;;
.opNeg:
    mov eax, [rbx + Instr.srcA]
    shl eax, 4
    lea rsi, [r12 + VMState.regs + rax]
    movups xmm2, [rsi]

    ; negate via xor with sign bit
    mov eax, 0x80000000
    movd xmm5, eax
    shufps xmm5, xmm5, 0x00
    xorps xmm2, xmm5
    call _storeDFull
    jmp .next

;;;;;;;;;;
; SWIZZLE
; dst = srcA[srcB as mask]
; Mask: 4 bytes, eacg is a source index (0..3).
;;;;;;;;;;
.opSwizzle:
    mov eax, [rbx + Instr.srcA]
    shl eax, 4
    lea rsi, [r12 + VMState.regs + rax]
    movups xmm2, [rsi]

    ; mask byte 0 = component to broadcast
    mov ecx, [rbx + Instr.srcB]
    and ecx, 0xFF
    
    ; Choose shuffle imm
    cmp ecx, 0
    je .swz0
    cmp ecx, 1
    je .swz1
    cmp ecx, 2
    je .swz2
    ; Default: 3
    shufps xmm2, xmm2, 0xFF
    jmp .swzDone

.swz0:
    shufps xmm2, xmm2, 0x00
    jmp .swzDone
.swz1:
    shufps xmm2, xmm2, 0x55
    jmp .swzDone
.swz2:
    shufps xmm2, xmm2, 0xAA
.swzDone:
    call _storeDFull
    jmp .next

;;;;;;;;;;

.next:
    inc r15d
    jmp .execLoop

.done:
    mov eax, 1
    add rsp, 56
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; loadAB
; Loads srcA into xmm2, srcB into xmm3
; Assumes rbx = current Instr, r12 = VMState
; --------------------------------------------
_loadAB:
    mov eax, [rbx + Instr.srcA]
    shl eax, 4
    lea rsi, [r12 + VMState.regs + rax]
    movups xmm2, [rsi]

    mov eax, [rbx + Instr.srcB]
    shl eax, 4
    lea rsi, [r12 + VMState.regs + rax]
    movups xmm3, [rsi]
    ret

; --------------------------------------------
; _storeD
; Stores xmm2 into dst register (from Instr.dst)
; --------------------------------------------
_storeD:
    mov eax, [rbx + Instr.dst]
    cmp eax, -1
    je .skip
    cmp eax, 255
    jg .skip
    shl eax, 4
    lea rdi, [r12 + VMState.regs + rax]
    movups [rdi], xmm2

.skip:
    ret

; --------------------------------------------
; _storeDSplat
; Broadcasts xmm2.x to all channels and store into dst
; --------------------------------------------
_storeDSplat:
    shufps xmm2, xmm2, 0x00
    jmp _storeD

; --------------------------------------------
; _storeDFull
; Same as _storeD...
; --------------------------------------------
_storeDFull:
    jmp _storeD

; --------------------------------------------
; _cgxCoreVMReset
; Zeroes all registers. Useful before running the program.
; Input: rcx = VMState ptr
; --------------------------------------------
_cgxCoreVMReset:
    push rdi
    push rcx
    mov rdi, rcx
    mov rcx, 256 * 16 / 8           ; 512 qwords
    xor eax, eax
    rep stosq
    pop rcx
    pop rdi
    ret