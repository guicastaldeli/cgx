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
    