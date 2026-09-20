; ============================================
; core/matrix.asm
; Matrix stack management
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"

extern _cgxCoreState
extern CGXState

global _cgxCoreMatrixInit
global _cgxCoreMatrixMode
global _cgxCoreLoadIdentity
global _cgxCorePushMatrix
global _cgxCorePopMatrix
global _cgxCoreLoadMatrix
global _cgxCoreMultMatrix
global _cgxCoreTranslate
global _cgxCoreRotate
global _cgxCoreScale
global _cgxCorePerspective
global _cgxCoreOrtho
global _matrixMultiply
global _matrixMultiplyVec4

STACK_DEPTH         equ 32
MATRIX_SIZE         equ 64              ; 16 floats * 4 bytes
DEG_TO_RAD          equ 0x3C8EFA35      ; pi / 180
ONE_F               equ 0x3F800000
ZERO_F              equ 0x00000000

section .text

; --------------------------------------------
; _cgxCoreMatrixInit
; Initialized both matrix stacks to identity
; Output: eax = 1 ok, 0 fail
; --------------------------------------------
_cgxCoreMatrixInit:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 40

    ; Default mode: MODELVIEW
    mov dword [rel _cgxCoreState + CGXState.matrixMode], CGX_MODELVIEW

    ; Both stacks start at top = 0
    mov dword [rel _cgxCoreState + CGXState.mvTop], 0
    mov dword [rel _cgxCoreState + CGXState.projTop], 0

    ; Load identity into both stack bottoms
    lea rdi, [rel _cgxCoreState + CGXState.mvStack]
    call _writeIdentity
    lea rdi, [rel _cgxCoreState + CGXState.projStack]
    call _writeIdentity

    ; Culling defaults
    mov dword [rel _cgxCoreState + CGXState.cullFaceEnabled], 0
    mov dword [rel _cgxCoreState + CGXState.cullMode], CGX_BACK
    mov dword [rel _cgxCoreState + CGXState.frontFace], CGX_CCW

    ; Blending defaults: off, src=ONE, dst=ZERO
    mov dword [rel _cgxCoreState + CGXState.blendEnabled], 0
    mov dword [rel _cgxCoreState + CGXState.blendSrc], CGX_ONE
    mov dword [rel _cgxCoreState + CGXState.blendDst], CGX_ZERO
    mov dword [rel _cgxCoreState + CGXState.drawAlpha], 0x3F800000      ; 1.0f alpha value

    mov eax, 1
    add rsp, 40
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _writeIdentity
; Input: rdi = destination (64 bytes)
; Writes identity matrix in column-major order
; Clobbers: eax, rcx, rdi
; --------------------------------------------
_writeIdentity:
    ; Set everything to 0
    xor eax, eax
    mov ecx, 16
.clear:
    mov [rdi], eax
    add rdi, 4
    dec ecx
    jnz .clear

    mov eax, ONE_F
    mov [rdi - 64 + 0], eax
    mov [rdi - 64 + 20], eax
    mov [rdi - 64 + 40], eax
    mov [rdi - 64 + 60], eax
    ret

; --------------------------------------------
; _cgxCoreMatrixMode
; Input: ecx = mode
; --------------------------------------------
_cgxCoreMatrixMode:
    mov [rel _cgxCoreState + CGXState.matrixMode], ecx
    ret

; --------------------------------------------
; _cgxCoreLoadIdentity
; Sets current top of current stack of identity
; --------------------------------------------
_cgxCoreLoadIdentity:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; Get current top
    mov eax, [rel _cgxCoreState + CGXState.matrixMode]
    cmp eax, CGX_PROJECTION
    je .proj

    ; MODELVIEW
    mov eax, [rel _cgxCoreState + CGXState.mvTop]
    shl eax, 6          ; * 64
    lea rdi, [rel _cgxCoreState + CGXState.mvStack]
    add rdi, rax
    call _writeIdentity
    jmp .done

.proj:
    mov eax, [rel _cgxCoreState + CGXState.projTop]
    shl eax, 6
    lea rdi, [rel _cgxCoreState + CGXState.projStack]
    add rdi, rax
    call _writeIdentity

.done:
    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; _cgxCorePushMatrix
; Pushes a copy of current matrix onto stack
; Output: eax = 1 ok, 0 overflow
; --------------------------------------------
_cgxCorePushMatrix:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 40

    mov eax, [rel _cgxCoreState + CGXState.matrixMode]
    cmp eax, CGX_PROJECTION
    je .proj

    ; MODELVIEW
    mov eax, [rel _cgxCoreState + CGXState.mvTop]
    cmp eax, STACK_DEPTH - 1
    jge .overflow

    ; src = stack[top]
    mov edx, eax
    shl edx, 6
    lea rsi, [rel _cgxCoreState + CGXState.mvStack]
    add rsi, rdx

    ; dst = stack[top + 1]
    add edx, 64
    lea rdi, [rel _cgxCoreState + CGXState.mvStack]
    add rdi, rdx

    ; Copy 64 bytes
    mov edx, 16
    rep movsd

    inc dword [rel _cgxCoreState + CGXState.mvTop]
    mov eax, 1
    jmp .done

.proj:
    mov eax, [rel _cgxCoreState + CGXState.projTop]
    cmp eax, STACK_DEPTH - 1
    jge .overflow

    mov edx, eax
    shl edx, 6
    lea rsi, [rel _cgxCoreState + CGXState.projStack]
    add rsi, rdx

    add edx, 64
    lea rdi, [rel _cgxCoreState + CGXState.projStack]
    add rdi, rdx

    mov ecx, 16
    rep movsd

    inc dword [rel _cgxCoreState + CGXState.projTop]
    mov eax, 1
    jmp .done

.overflow:
    xor eax, eax

.done:
    add rsp, 40
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCorePopMatrix
; Pops current matrix off the stack
; Output: eax = 1 ok, 0 underflow
; --------------------------------------------
_cgxCorePopMatrix:
    push rbp
    mov rbp, rsp
    sub rsp, 40

    mov eax, [rel _cgxCoreState + CGXState.matrixMode]
    cmp eax, CGX_PROJECTION
    je .proj

    ; MODELVIEW
    mov eax, [rel _cgxCoreState + CGXState.mvTop]
    test eax, eax
    jz .underflow

    dec dword [rel _cgxCoreState + CGXState.mvTop]
    mov eax, 1
    jmp .done

.proj:
    mov eax, [rel _cgxCoreState + CGXState.projTop]
    test eax, eax
    jz .underflow

    dec dword [rel _cgxCoreState + CGXState.projTop]
    mov eax, 1
    jmp .done

.underflow:
    xor eax, eax

.done:
    mov rsp, rbp
    pop rbp
    ret

; --------------------------------------------
; Helper: _getCurrentMatrix
; Output: rdi = pointer to current top matrix
; --------------------------------------------
_getCurrentMatrix:
    mov eax, [rel _cgxCoreState + CGXState.matrixMode]
    cmp eax, CGX_PROJECTION
    je .proj

    mov eax, [rel _cgxCoreState + CGXState.mvTop]
    shl eax, 6
    lea rdi, [rel _cgxCoreState + CGXState.mvStack]
    add rdi, rax
    ret

.proj:
    mov eax, [rel _cgxCoreState + CGXState.projTop]
    shl eax, 6
    lea rdi, [rel _cgxCoreState + CGXState.projStack]
    add rdi, rax
    ret

; --------------------------------------------
; _matrixMultiply
; MULTIPLY: dst = a * b (4x4 * 4x4)
; Input: rdi = dst, rsi = a, rdx = b
; Column-major
; --------------------------------------------
_matrixMultiply:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    ; Save ptrs
    mov [rbp - 8], rdi      ; dst
    mov [rbp - 16], rsi     ; a
    mov [rbp - 24], rdx     ; b

    xor r8d, r8d            ; j = column index of b/dst

.colLoop:
    cmp r8d, 4
    jge .done

    ; Compute offset = j * 4, floats = j * 16
    mov eax, r8d
    shl eax, 4                  ; j * 16

    ; Load b's column j into xmm4 (4 floats: b[0..3][j])
    mov rsi, [rbp - 24]
    add rsi, rax
    movups xmm4, [rsi]          ; b[0][j], b[1][j], b[2][j], b[3][j]

    ; Broadcast each component into xmm5..xmm8
    ; xmm5 = (b0j, b0j, b0j, b0j)
    movups xmm5, xmm4
    shufps xmm5, xmm5, 0x00
    ; xmm6 = (b1j, b1j, b1j, b1j)
    movups xmm6, xmm4
    shufps xmm6, xmm6, 0x55
    ; xmm7 = (b2j, b2j, b2j, b2j)
    movups xmm7, xmm4
    shufps xmm7, xmm7, 0xAA
    ; xmm8 = (b3j, b3j, b3j, b3j)
    movups xmm8, xmm4
    shufps xmm8, xmm8, 0xFF

    ; Compute dst_col = a_col0 * b0j + a_col1 * b1j + a_col2 * b2j + a_col3 * b3j
    mov rsi, [rbp - 16]         ; a
    movups xmm0, [rsi + 0]      ; a_col0
    mulps xmm0, xmm5
    movups xmm1, [rsi + 16]     ; a_col1
    mulps xmm1, xmm6
    addps xmm0, xmm1
    movups xmm1, [rsi + 32]     ; a_col2
    mulps xmm1, xmm7
    addps xmm0, xmm1
    movups xmm1, [rsi + 48]     ; a_col3
    mulps xmm1, xmm8
    addps xmm0, xmm1

    ; Store dst_col
    mov rdi, [rbp - 8]
    mov eax, r8d
    shl eax, 4
    add rdi, rax
    movups [rdi], xmm0

    inc r8d
    jmp .colLoop

.done:
    add rsp, 64
    pop rbp
    ret

; --------------------------------------------
; _matrixMultiplyVec4
; Input: rdi = matrix ptr, xmm0..xmm3 = vector(x, y, z, w)
; Output: xmm0..xmm3 = result (x', y', z', w')
; Column-major: result = M * v
; --------------------------------------------
_matrixMultiplyVec4:
    ; Load vector components into xmm4 (broadcast pattern)
    ; col0 = (x, x, x, x)
    movups xmm4, xmm0
    shufps xmm4, xmm4, 0x00
    ; col1 = (y, y, y, y)
    movups xmm5, xmm1
    shufps xmm5, xmm5, 0x00
    ; col2 = (z, z, z, z)
    movups xmm6, xmm2
    shufps xmm6, xmm6, 0x00
    ; col3 = (w, w, w, w)
    movups xmm7, xmm3
    shufps xmm7, xmm7, 0x00

    ; result = col0 * M[0] + col1 * M[1] + col2 * M[2] + col3 * M[3]
    movups xmm0, [rdi + 0]
    mulps xmm0, xmm4
    movups xmm1, [rdi + 16]
    mulps xmm1, xmm5
    addps xmm0, xmm1
    movups xmm1, [rdi + 32]
    mulps xmm1, xmm6
    addps xmm0, xmm1
    movups xmm1, [rdi + 48]
    mulps xmm1, xmm7
    addps xmm0, xmm1

    ; xmm0 now holds (x', y', z', w')
    ; Split into xmm0..xmm3
    movups xmm1, xmm0
    shufps xmm1, xmm1, 0x55         ; y'
    movups xmm2, xmm0
    shufps xmm2, xmm2, 0xAA         ; z'
    movups xmm3, xmm0
    shufps xmm3, xmm3, 0xFF         ; w'
    shufps xmm0, xmm0, 0x00         ; x'

    ret

; --------------------------------------------
; _cgxCoreLoadMatrix
; Input: rcx = ptr to 4x4 (64 bytes)
; --------------------------------------------
_cgxCoreLoadMatrix:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 40

    mov rbx, rcx
    call _getCurrentMatrix

    mov ecx, 16
    mov rsi, rbx
    rep movsd

    add rsp, 40
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreMultMatrix
; Input: rcx = ptr to 4x4
; current = current * M
; --------------------------------------------
_cgxCoreMultMatrix:
    push rbp
    mov rbp, rsp
    sub rsp, 128

    ; Save M ptr
    mov [rbp - 8], rcx

    ; Get current matrix ptr
    call _getCurrentMatrix
    mov [rbp - 16], rdi         ; current ptr

    ; Copy current temp (dst = current)
    ; _matrixMultiply(dst, a, b) = dst = a * b
    ;   dst = current
    ;   a = current
    ;   b = M
    lea rdi, [rbp - 128]        ; temp 64 bytes
    mov rsi, [rbp - 16]         ; a = current
    mov rdx, [rbp - 8]          ; b = M
    call _matrixMultiply

    ; Copy temp back to current
    mov rdi, [rbp - 16]
    lea rsi, [rbp - 128]
    mov ecx, 16
    rep movsd

    add rsp, 128
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreTranslate
; Input: xmm0 = x, xmm1 = y, xmm2 = z
; --------------------------------------------
_cgxCoreTranslate:
    push rbp
    mov rbp, rsp
    sub rsp, 128

    ; Build translate matrix in temp (64 bytes at rbp-128)
    lea rdi, [rbp - 128]
    call _writeIdentity

    lea rdi, [rbp - 128]
    movss [rdi + 48], xmm0      ; M[3][0] = x
    movss [rdi + 52], xmm1      ; M[3][1] = y
    movss [rdi + 56], xmm2      ; M[3][2] = z

    ; current = current * T
    lea rcx, [rbp - 128]
    call _cgxCoreMultMatrix

    add rsp, 128
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreScale
; Input: xmm0 = x, xmm1 = y, xmm2 = z
; --------------------------------------------
_cgxCoreScale:
    push rbp
    mov rbp, rsp
    sub rsp, 128

    lea rdi, [rbp - 128]
    call _writeIdentity

    lea rdi, [rbp - 128]
    movss [rdi + 0], xmm0         ; M[0][0] = x
    movss [rdi + 20], xmm1        ; M[1][1] = y
    movss [rdi + 40], xmm2        ; M[2][2] = z

    lea rcx, [rbp - 128]
    call _cgxCoreMultMatrix

    add rsp, 128
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreRotate
; Input: xmm0 = angle (degrees), xmm1..xmm3 = axis (x, y, z)
; --------------------------------------------
_cgxCoreRotate:
    push rbp
    mov rbp, rsp
    sub rsp, 192

    ; Save angle and axis
    movss [rbp - 4], xmm0           ; angle
    movss [rbp - 8], xmm1           ; ax
    movss [rbp - 12], xmm2          ; ay
    movss [rbp - 16], xmm3          ; az

    ; angle_rad = angle * DEG_TO_RAD
    mov eax, DEG_TO_RAD
    movd xmm4, eax
    mulss xmm0, xmm4
    movss [rbp - 20], xmm0          ; angle_rad

    ; c = cos(angle_rad)
    fld dword [rbp - 20]
    fcos
    fstp dword [rbp - 24]

    ; s = sin(angle_rad)
    fld dword [rbp - 20]
    fsin
    fstp dword [rbp - 28]

    ; Normalize axis
    ; len = sqrt(ax*ax + ay*ay + az*az)
    movss xmm0, [rbp - 8]
    movss xmm1, [rbp - 12]
    movss xmm2, [rbp - 16]
    mulss xmm0, xmm0
    mulss xmm1, xmm1
    mulss xmm2, xmm2
    addss xmm0, xmm1
    addss xmm0, xmm2
    sqrtss xmm0, xmm0

    ; If len == 0, axis invalid -> treat as no rotation
    xorps xmm1, xmm1
    ucomiss xmm0, xmm1
    je .skipRotation

    ; nx = ax/len, ny = ay/len, nz = az/len
    movss xmm1, [rbp - 8]
    divss xmm1, xmm0
    movss [rbp - 32], xmm1          ; nx

    movss xmm2, [rbp - 12]
    divss xmm2, xmm0
    movss [rbp - 36], xmm2          ; ny

    movss xmm3, [rbp - 16]
    divss xmm3, xmm0
    movss [rbp - 40], xmm3          ; nz

    ; Build rotation matrix
    ; R = I + s*K + (1-c)*K^2
    ;
    ;
    ; R[0][0] = c + nx^2*(1-c)
    ; R[0][1] = nx*ny*(1-c) - nz*s
    ; R[0][2] = nx*nz*(1-c) + ny*s
    ; R[1][0] = ny*nx*(1-c) + nz*s
    ; R[1][1] = c + ny^2*(1-c)
    ; R[1][2] = ny*nz*(1-c) - nx*s
    ; R[2][0] = nz*nx*(1-c) - ny*s
    ; R[2][1] = nz*ny*(1-c) + nx*s
    ; R[2][2] = c + nz^2*(1-c)

    ; Compute 1-c
    movss xmm4, [rbp - 24]          ; c
    mov eax, ONE_F
    movd xmm5, eax
    subss xmm5, xmm4                ; 1-c

    ; Load nx, ny, nz, s, c into xmm0..xmm2, xmm3, xmm4
    movss xmm0, [rbp - 32]          ; nx
    movss xmm1, [rbp - 36]          ; ny
    movss xmm2, [rbp - 40]          ; nz
    movss xmm3, [rbp - 28]          ; s
    ; xmm4 = c, xmm5 = 1-c

    ; Build matrix in temp at rbp-128
    lea rdi, [rbp - 128]

    ; Zero it first
    xor eax, eax
    push rdi
    mov ecx, 16

.zeroLoop:
    mov [rdi], eax
    add rdi, 4
    dec ecx
    jnz .zeroLoop
    pop rdi

    ; R[0][0] = c + nx*nx*(1-c)
    movaps xmm6, xmm0
    mulss xmm6, xmm0
    mulss xmm6, xmm5
    addss xmm6, xmm4
    movss [rdi + 0], xmm6

    ; R[1][0] = ny*nx*(1-c) + nz*s
    movaps xmm6, xmm1
    mulss xmm6, xmm0
    mulss xmm6, xmm5
    movaps xmm7, xmm2
    mulss xmm7, xmm3
    addss xmm6, xmm7
    movss [rdi + 4], xmm6

    ; R[2][0] = nz*nx*(1-c) - ny*s
    movaps xmm6, xmm2
    mulss xmm6, xmm0
    mulss xmm6, xmm5
    movaps xmm7, xmm1
    mulss xmm7, xmm3
    subss xmm6, xmm7
    movss [rdi + 8], xmm6

    ; R[0][1] = nx*xy*(1-c) - nz*s
    movaps xmm6, xmm0
    mulss xmm6, xmm1
    mulss xmm6, xmm5
    movaps xmm7, xmm2
    mulss xmm7, xmm3
    subss xmm6, xmm7
    movss [rdi + 16], xmm6

    ; R[1][1] = c + ny*ny*(1-c)
    movaps xmm6, xmm1
    mulss xmm6, xmm1
    mulss xmm6, xmm5
    addss xmm6, xmm4
    movss [rdi + 20], xmm6

    ; R[2][1] = nz*ny*(1-c) + nx*s
    movaps xmm6, xmm2
    mulss xmm6, xmm1
    mulss xmm6, xmm5
    movaps xmm7, xmm0
    mulss xmm7, xmm3
    addss xmm6, xmm7
    movss [rdi + 24], xmm6

    ; R[0][2] = nx*nz*(1-c) + ny*s
    movaps xmm6, xmm0
    mulss xmm6, xmm2
    mulss xmm6, xmm5
    movaps xmm7, xmm1
    mulss xmm7, xmm3
    addss xmm6, xmm7
    movss [rdi + 32], xmm6

    ; R[1][2] = ny*nz*(1-c) - nx*s
    movaps xmm6, xmm1
    mulss xmm6, xmm2
    mulss xmm6, xmm5
    movaps xmm7, xmm0
    mulss xmm7, xmm3
    subss xmm6, xmm7
    movss [rdi + 36], xmm6

    ; R[2][2] = c + nz*nz*(1-c)
    movaps xmm6, xmm2
    mulss xmm6, xmm2
    mulss xmm6, xmm5
    addss xmm6, xmm4
    movss [rdi + 40], xmm6

    ; R[3][3] = 1.0
    mov eax, ONE_F
    mov [rdi + 60], eax

    ; current = current * R
    lea rcx, [rbp - 128]
    call _cgxCoreMultMatrix

.skipRotation:
    add rsp, 192
    pop rbp
    ret

; --------------------------------------------
; _cgxCorePerspective
; Input: xmm0 = fov (degrees), xmm1 = aspect,
;           xmm2 = near, xmm3 = far
; Sets current top = perspective matrix (loads, not multiplies)
; --------------------------------------------
_cgxCorePerspective:
    push rbp
    mov rbp, rsp
    sub rsp, 128

    ; Compute f = 1 / tan(fov/2)
    ; fov_rad = fov * DEG_TO_RAD
    ; half = fov_rad * 0.5
    mov eax, DEG_TO_RAD
    movd xmm4, eax
    mulss xmm0, xmm4            ; fov_rad
    mov eax, 0x3F000000         ; 0.5
    movd xmm4, eax
    mulss xmm0, xmm4            ; half_angle

    ; tan(half) via x87
    fld dword [rsp - 8]         ; **dummy load to init FPU stack...
    fstp dword [rsp - 8]
    movss [rsp - 4], xmm0
    fld dword [rsp - 4]
    fptan                       ; ST(0) = 1.0, ST(1) = tan(x)
    fstp st0                    ; pop the 1.0
    fstp dword [rsp - 8]        ; store tan

    ; f = 1.0 / tan
    mov eax, ONE_F
    movd xmm4, eax
    divss xmm4, [rsp - 8]
    movss [rsp - 12], xmm4      ; f

    ; Zero the temp matrix at rbp-128
    lea rdi, [rbp - 128]
    xor eax, eax
    mov ecx, 16

.zeroLoop:
    mov [rdi], eax
    add rdi, 4
    dec ecx
    jnz .zeroLoop

    lea rdi, [rbp - 128]

    ; M[0][0] = f / aspect
    movss xmm5, [rsp - 12]
    divss xmm5, xmm1
    movss [rdi + 0], xmm5

    ; M[1][1] = f
    movss xmm5, [rsp - 12]
    movss [rdi + 20], xmm5

    ; M[2][2] = (far+near) / (near - far)
    movaps xmm5, xmm3       ; far
    addss xmm5, xmm2        ; + near
    movaps xmm6, xmm2       ; near
    subss xmm6, xmm3        ; near - far
    divss xmm5, xmm6
    movss [rdi + 40], xmm5

    ; M[2][3] = -1.0
    mov eax, 0xBF800000
    mov dword [rdi + 44], eax

    ; M[3][2] = (2 * far * near) / (near - far)
    movaps xmm5, xmm3
    mulss xmm5, xmm2
    mov eax, 0x40000000     ; 2.0
    movd xmm6, eax
    mulss xmm5, xmm6
    movaps xmm6, xmm2
    subss xmm6, xmm3        ; near - far
    divss xmm5, xmm6
    movss [rdi + 56], xmm5

    ; M[3][3] = 0

    ; Load into current matrix
    lea rcx, [rbp - 128]
    call _cgxCoreLoadMatrix

    add rsp, 128
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreOrtho
; Input: xmm0=l, xmm1=r, xmm2=b, xmm3=t,
;           [rbp+16]=n, [rbp+24]=f
; --------------------------------------------
_cgxCoreOrtho:
    push rbp
    mov rbp, rsp
    sub rsp, 128

    ; Load near, far from stack
    movss xmm4, [rbp + 40]      ; n
    movss xmm5, [rbp + 48]      ; f

    ; Zero temp at rbp-128
    lea rdi, [rbp - 128]
    xor eax, eax
    mov ecx, 16

.zeroLoop:
    mov [rdi], eax
    add rdi, 4
    dec ecx
    jnz .zeroLoop

    lea rdi, [rbp - 128]

    ; M[0][0] = 2 / (r - l)
    movaps xmm6, xmm1
    subss xmm6, xmm0
    mov eax, 0x40000000
    movd xmm7, eax
    divss xmm7, xmm6
    movss [rdi + 0], xmm7

    ; M[1][1] = 2 / (t - b)
    movaps xmm6, xmm3
    subss xmm6, xmm2
    mov eax, 0x40000000
    movd xmm7, eax
    divss xmm7, xmm6
    movss [rdi + 20], xmm7

    ; M[2][2] = -2 / (f - n)
    movaps xmm6, xmm5
    subss xmm6, xmm4
    mov eax, 0xC0000000     ; -2.0
    movd xmm7, eax
    divss xmm7, xmm6
    movss [rdi + 40], xmm7

    ; M[3][0] = -(r + l) / (r - l)
    movaps xmm6, xmm1
    addss xmm6, xmm0
    movaps xmm7, xmm1
    subss xmm7, xmm0
    divss xmm6, xmm7
    mov eax, 0x80000000
    movd xmm7, eax
    xorps xmm6, xmm7        ; negate
    movss [rdi + 48], xmm6

    ; M[3][1] = -(t + b) / (t - b)
    movaps xmm6, xmm3
    addss xmm6, xmm2
    movaps xmm7, xmm3
    subss xmm7, xmm2
    divss xmm6, xmm7
    mov eax, 0x80000000
    movd xmm7, eax
    xorps xmm6, xmm7
    movss [rdi + 52], xmm6

    ; M[3][2] = -(f + n) / (f - n)
    movaps xmm6, xmm5
    addss xmm6, xmm4
    movaps xmm7, xmm5
    subss xmm7, xmm4
    divss xmm6, xmm7
    mov eax, 0x80000000
    movd xmm7, eax
    xorps xmm6, xmm7
    movss [rdi + 56], xmm6

    ; M[3][3] = 1.0
    mov eax, ONE_F
    mov [rdi + 60], eax

    lea rcx, [rbp - 128]
    call _cgxCoreLoadMatrix

    add rsp, 128
    pop rbp
    ret