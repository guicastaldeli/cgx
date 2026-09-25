; ============================================
; test_shader_vm.asm
; Runs a small instruction stream through the VM
; and prints the resulting register values
; ============================================

default rel

global main

%include "constants.inc"
%include "structs.inc"
%include "shader.inc"

extern CGXInit
extern CGXShutdown
extern MessageBoxA
extern _cgxCoreVMExecute
extern _cgxCoreVMReset

section .data
    title           db "VM Test", 0

    msg_mulx        db "reg2.x (expect 5): 000 ", 0
    msg_addx        db "reg3.x (expect 6): 000 ", 0
    msg_dotx        db "reg4.x (expect 70): 000 ", 0
    msg_len         db "reg5.x (expect sqrt(30)=5): 000", 0

    ; --- Program ---
    alignb 8
    program:
        ; MUL 2, 0, 1     ; reg2 = reg0 * reg1
        dd CGX_OP_MUL, 2, 0, 1, -1, 0
        ; ADD 3, 0, 2     ; reg3 = reg0 + reg2
        dd CGX_OP_ADD, 3, 0, 2, -1, 0
        ; DOT 4, 0, 1     ; reg4.x = dot(reg0, reg1)
        dd CGX_OP_DOT, 4, 0, 1, -1, 0
        ; LENGTH 5, 0     ; reg5.x = length(reg0)
        dd CGX_OP_LENGTH, 5, 0, -1, -1, 0
        ; HALT
        dd CGX_OP_HALT, -1, -1, -1, -1, 0
    programEnd:
    programCount equ (programEnd - program) / Instr_size

section .bss
    vmstate         resb VMState_size

section .text

_box:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    xor rcx, rcx
    lea r8, [rel title]
    xor r9d, r9d
    call MessageBoxA
    add rsp, 32
    pop rbp
    ret

_write3digits:
    push rbx
    mov rbx, 100
    xor edx, edx
    div ebx
    add al, '0'
    mov [rdi], al
    inc rdi

    mov eax, edx
    mov ebx, 10
    xor edx, edx
    div ebx
    add al, '0'
    mov [rdi], al
    inc rdi

    mov eax, edx
    add al, '0'
    mov [rdi], al
    pop rbx
    ret

_floatToInt:
    cvttss2si eax, xmm0
    ret

main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 40

    mov rcx, 800
    mov rdx, 600
    lea r8, [rel title]
    call CGXInit
    test eax, eax
    jz .fail

    ; Init VMState registers
    lea rcx, [rel vmstate]
    call _cgxCoreVMReset

    lea rdi, [rel vmstate + VMState.regs]

    ; reg0 = (1.0, 2.0, 3.0, 4.0)
    mov eax, 0x3F800000
    mov [rdi + 0], eax
    mov eax, 0x40000000
    mov [rdi + 4], eax
    mov eax, 0x40400000
    mov [rdi + 8], eax
    mov eax, 0x40800000
    mov [rdi + 12], eax

    ; reg1 = (5.0, 6.0, 7.0, 8.0)
    mov eax, 0x40A00000
    mov [rdi + 16], eax
    mov eax, 0x40C00000
    mov [rdi + 20], eax
    mov eax, 0x40E00000
    mov [rdi + 24], eax
    mov eax, 0x41000000
    mov [rdi + 28], eax

    ; Run
    lea rcx, [rel vmstate]
    lea rdx, [rel program]
    mov r8d, programCount
    call _cgxCoreVMExecute

    ; Read reg2.x, reg3.x, reg4.x, reg5.x and print
    lea rdi, [rel vmstate + VMState.regs]

    ; reg2.x
    movss xmm0, [rdi + 2 * 16]
    call _floatToInt
    lea rdi, [rel msg_mulx + 20]
    call _write3digits
    lea rdx, [rel msg_mulx]
    call _box

    ; reg3.x
    lea rdi, [rel vmstate + VMState.regs]
    movss xmm0, [rdi + 3 * 16]
    call _floatToInt
    lea rdi, [rel msg_addx + 20]
    call _write3digits
    lea rdx, [rel msg_addx]
    call _box

    ; reg4.x
    lea rdi, [rel vmstate + VMState.regs]
    movss xmm0, [rdi + 4 * 16]
    call _floatToInt
    lea rdi, [rel msg_dotx + 20]
    call _write3digits
    lea rdx, [rel msg_dotx]
    call _box

    ; reg5.x
    lea rdi, [rel vmstate + VMState.regs]
    movss xmm0, [rdi + 5 * 16]
    call _floatToInt
    lea rdi, [rel msg_len + 28]
    call _write3digits
    lea rdx, [rel msg_len]
    call _box

    call CGXShutdown
    xor eax, eax
    jmp .finish

.fail:
    call CGXShutdown
    mov eax, 1

.finish:
    add rsp, 40
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret