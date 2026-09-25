; ============================================
; core/shader_compiler.asm
; Compile AST to bytecode (register-based VM)
; Scope: G1 subset (decls, assigns, 
;       expressions, built-in calls, swizzles)
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"
%include "shader.inc"

extern _cgxCoreState
extern CGXState

extern _parserState

global _cgxCoreCompile

section .data
    _cf_vec4                db "vec4", 0
    _cf_vec3                db "vec3", 0
    _cf_vec2                db "vec2", 0
    _cf_texture2D           db "texture2D", 0
    
    global _ccDebugStage
    _ccDebugStage           db 0

section .bss
    _ccInstrOut             resq 1
    _ccInstrCap             resd 1
    _ccInstrCount           resd 1
    _ccTempHigh             resd 1
    
section .text

; --------------------------------------------
; _cgxCoreCompile
; Input: rcx = AST array ptr
;       edx = AST node count
;       r8 = token array ptr
;       r9 = Instr output ptr
;       [rbp + 48] = Instr output capacity
; Output: eax = instruction count (>= 1) on success, 0 on error
; --------------------------------------------
_cgxCoreCompile:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 88

    mov byte [rel _ccDebugStage], 10

    ; --- Save state ---
    mov [rbp - 56], rcx                          ; AST array
    mov [rbp - 64], rdx                         ; node count
    mov [rbp - 72], r8                          ; token array
    mov [rel _ccInstrOut], r9                   ; Instr output
    mov rax, [rbp + 48]
    mov [rel _ccInstrCap], eax                  ; Instr capacity
    mov dword [rel _ccInstrCount], 0            ; instrCount
    mov dword [rel _ccTempHigh], 200            ; tempRegHeight (temp register allocator)

    mov byte [rel _ccDebugStage], 11

    ; First pass: compile top-level DECLs in order
    ; Program node is at index 0 (or the first node)
    xor ebx, ebx                                ; node index

.progLoop:
    mov eax, [rbp - 64]             ; node count
    cmp ebx, eax
    jge .finish

    ; node ptr = ast + idx * ASTNode_size
    mov eax, ebx
    imul eax, ASTNode_size
    mov r12, [rbp - 56]
    add r12, rax

    mov ecx, [r12 + ASTNode.type]

    cmp ecx, CGX_NODE_DECL          ; NODE_DECL
    je .compileDeclTop
    cmp ecx, CGX_NODE_MAIN          ; NODE_MAIN
    je .compileMain
    cmp ecx, CGX_NODE_ASSIGN        ; NODE_ASSIGN
    je .compileAssign

    ;mov byte [rel _ccDebugStage], 61    
    jmp .nextNode

;;;;;;;;;;
; Compile a top-level DECL:
; - if it has an initializer, compile the init, then MOV init -> symbol's reg.
; - Otherwise, skip
;;;;;;;;;;
.compileDeclTop:
    mov byte [rel _ccDebugStage], 20

    ; node.a = symbol index; node.b = init node or -1
    mov eax, [r12 + ASTNode.a]
    cmp eax, -1
    je .nextNode

    mov ecx, [r12 + ASTNode.b]
    cmp ecx, -1
    je .nextNode                        ; no initializer

    mov byte [rel _ccDebugStage], 21

    ; Look up the symbol's register
    mov eax, [r12 + ASTNode.a]
    call _getSymbolRegByIdx
    ; eax = reg or -1
    cmp eax, -1
    je .nextNode
    mov r13d, eax                       ; dest reg

    ; Compile the initializer
    mov rcx, [rbp - 56]
    mov edx, [r12 + ASTNode.b]
    mov r8, [rbp - 72]
    call _compileExpr
    cmp eax, -1
    je .errDeclEmit
    mov r14d, eax                       ; source reg

    mov byte [rel _ccDebugStage], 22

    ; Emit MOV dest, source
    mov ecx, CGX_OP_MOV
    mov edx, r13d
    mov r8d, r14d
    mov r9d, -1
    call _emit
    cmp eax, -1
    je .errDeclEmit

    jmp .nextNode

;;;;;;;;;;
; Compile a MAIN node: walk its statement list
;;;;;;;;;;
.compileMain:
    mov byte [rel _ccDebugStage], 30
    ; Main body statements are subsequent nodes.
    ; Continue the outer loop; assignments will be picked up by
    ; the ASSIGN handler on the next iteration...
    jmp .nextNode

;;;;;;;;;;
; Compile a top-level ASSIGN node
;;;;;;;;;;
.compileAssign:
    mov byte [rel _ccDebugStage], 40

    mov rdi, [rbp - 56]
    mov rsi, [rbp - 72]          ; node ptr
    mov rdx, r12
    call _compileAssign
    cmp eax, -1
    je .errAssign
    jmp .nextNode

.nextNode:
    inc ebx
    jmp .progLoop

.finish:
    mov byte [rel _ccDebugStage], 90
    
    ; Emit HALT
    mov ecx, CGX_OP_HALT
    mov edx, -1
    mov r8d, -1
    mov r9d, -1
    call _emit
    cmp eax, -1
    je .errHalt

    mov byte [rel _ccDebugStage], 91

    mov eax, [rel _ccInstrCount]         ; return instr count
    jmp .done

.errDeclExpr:
    xor eax, eax
    jmp .done
.errDeclEmit:
    xor eax, eax
    jmp .done
.errAssign:
    xor eax, eax
    jmp .done
.errHalt:
    xor eax, eax
    jmp .done
.err:
    xor eax, eax

.done:
    add rsp, 88
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _compileAssign
; Input: rdi = AST array, rsi = token array, rdx = ASSIGN node ptr
; Output: eax = 0 on success, -1 on error
; --------------------------------------------
_compileAssign:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40

    mov byte [rel _ccDebugStage], 41

    mov [rbp - 56], rdi             ; ast
    mov [rbp - 64], rsi             ; tokens
    mov r12, rdx                    ; node

    ; LHS node
    mov eax, [r12 + ASTNode.a]
    mov [rbp - 72], eax             ; lhs idx

    ; RHS node
    mov eax, [r12 + ASTNode.b]
    mov [rbp - 76], eax             ; rhs idx

    ; Operator
    mov eax, [r12 + ASTNode.c]
    mov [rbp - 80], eax              ; op

    ; --- Handle LHS ---
    ; LHS must be an IDENT or MEMBER
    mov eax, [rbp - 72]
    imul eax, ASTNode_size
    mov r13, [rbp - 56]
    add r13, rax
    ; r13 = lhs node ptr

    mov ecx, [r13 + ASTNode.type]
    cmp ecx, CGX_NODE_IDENT
    je .lhsIdent
    cmp ecx, CGX_NODE_MEMBER
    je .lhsMember

    mov byte [rel _ccDebugStage], 42

    mov eax, -1
    jmp .done

.lhsIdent:
    ; lhs.a = symbol index
    mov eax, [r13 + ASTNode.a]
    call _getSymbolRegByIdx
    cmp eax, -1
    je .errSymLookup
    mov r14d, eax               ; dest reg
    jmp .compileRhs

.errSymLookup:
    mov eax, -1
    jmp .done

.lhsMember:
    mov byte [rel _ccDebugStage], 44
    mov eax, -1
    jmp .done

.compileRhs:
    mov byte [rel _ccDebugStage], 45
    
    ; Compile RHS expression
    mov rcx, [rbp - 56]
    mov edx, [rbp - 76]
    mov r8, [rbp - 64]
    call _compileExpr
    cmp eax, -1
    je .errRhsExpr
    mov r15d, eax               ; source reg

    mov byte [rel _ccDebugStage], 46

    ; Emit MOV dest, source
    mov ecx, CGX_OP_MOV
    mov edx, r14d
    mov r8d, r15d
    mov r9d, -1
    call _emit
    cmp eax, -1
    je .errRhsEmit

    ; TODO: compund assignment not yet supported...
    xor eax, eax
    jmp .done

.errRhsExpr:
    mov eax, -1
    jmp .done
.errRhsEmit:
    mov byte [rel _ccDebugStage], 48
    mov eax, -1
    jmp .done

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
; _compileExpr
; Input: rcx = AST array, edx = node index, r8 = token array
; Output: eax = result register, or -1 on error
; --------------------------------------------
_compileExpr:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40

    mov byte [rel _ccDebugStage], 50

    mov [rbp - 48], rcx          ; ast
    mov [rbp - 56], r8           ; tokens

    ; node ptr
    mov eax, edx
    imul eax, ASTNode_size
    mov r12, rcx
    add r12, rax
    ; r12 = node ptr

    mov ecx, [r12 + ASTNode.type]

    cmp ecx, CGX_NODE_LITERAL       ; NODE_LITERAL
    je .exprLiteral
    cmp ecx, CGX_NODE_IDENT         ; NODE_IDENT
    je .exprIdent
    cmp ecx, CGX_NODE_BINARY        ; NODE_BINARY
    je .exprBinary
    cmp ecx, CGX_NODE_CALL          ; NODE_CALL
    je .exprCall
    cmp ecx, CGX_NODE_MEMBER        ; NODE_MEMBER
    je .exprMember

    mov byte [rel _ccDebugStage], 51

    jmp .fail

;;;;;;;;;;
; LITERAL: emit MOV temp, imm
;;;;;;;;;;
.exprLiteral:
    mov byte [rel _ccDebugStage], 52

    call _allocTemp
    cmp eax, -1
    je .errTemp
    mov r13d, eax

    ; Emit MOV dst, imm
    mov ecx, CGX_OP_MOV
    mov edx, r13d
    mov r8d, -1
    mov r9d, [r12 + ASTNode.a]      ; float bits
    call _emitImm
    cmp eax, -1
    je .errEmitImm

    mov eax, r13d
    jmp .done

.errTemp:
    mov byte [rel _ccDebugStage], 53
    jmp .fail
.errEmitImm:
    mov byte [rel _ccDebugStage], 54
    jmp .fail

;;;;;;;;;;

;;;;;;;;;;
; IDENT: result is the symbol's register
;;;;;;;;;;
.exprIdent:
    mov byte [rel _ccDebugStage], 55

    ; node.a = symbol index
    mov rdi, [rbp - 48]
    mov rsi, [rbp - 56]
    mov eax, [r12 + ASTNode.a]
    call _getSymbolRegByIdx
    cmp eax, -1
    je .errIdentSym
    jmp .done

.errIdentSym:
    jmp .fail

;;;;;;;;;;

;;;;;;;;;;
; BINARY: compile lhs, compile rhs, emit op.
;;;;;;;;;;
.exprBinary:
    mov byte [rel _ccDebugStage], 57

    ; lhs
    mov rcx, [rbp - 48]
    mov edx, [r12 + ASTNode.a]
    mov r8, [rbp - 56]
    call _compileExpr
    cmp eax, -1
    je .errBinLhs
    mov r13d, eax                       ; lhs reg

    ; rhs
    mov rcx, [rbp - 48]
    mov edx, [r12 + ASTNode.b]
    mov r8, [rbp - 56]
    call _compileExpr
    cmp eax, -1
    je .errBinRhs
    mov r14d, eax                       ; rhs reg

    ; Determine op
    mov ecx, [r12 + ASTNode.c]          ; operator token
    ; Map operator token -> VM opcode
    mov eax, CGX_OP_ADD
    cmp ecx, CGX_TOK_PLUS
    je .binopReady
    mov eax, CGX_OP_SUB
    cmp ecx, CGX_TOK_MINUS
    je .binopReady
    mov eax, CGX_OP_MUL
    cmp ecx, CGX_TOK_STAR
    je .binopReady
    mov eax, CGX_OP_DIV
    cmp ecx, CGX_TOK_SLASH  
    je .binopReady

    mov byte [rel _ccDebugStage], 58
    jmp .fail

.errBinLhs:
    jmp .fail
.errBinRhs:
    jmp .fail

.binopReady:
    mov r15d, eax                       ; opcode

    ; Special case: ma4 * vec4
    ; If lhs is mat4 and op is MUL use CGX_OP_MAT4_MUL_VEC4.
    ;mov ecx, [r12 + ASTNode.typeId]

    ; Allocate dest temp
    call _allocTemp
    cmp eax, -1
    je .errBinTemp
    mov ebx, eax                        ; dst reg

    ; Emit
    mov ecx, r15d                       ; op
    mov edx, ebx                        ; dst
    mov r8d, r13d                       ; srcA
    mov r9d, r14d                       ; srcB
    call _emit
    cmp eax, -1
    je .errBinEmit

    mov eax, ebx
    jmp .done

.errBinTemp:
    mov byte [rel _ccDebugStage], 61
    jmp .fail
.errBinEmit:
    mov byte [rel _ccDebugStage], 62
    jmp .fail

;;;;;;;;;;

;;;;;;;;;;
; CALL: built-in function or constructor
; node.a = token index
;;;;;;;;;;
.exprCall:
    mov byte [rel _ccDebugStage], 63
    mov eax, [r12 + ASTNode.a]

    ; token ptr = tokens + a * Token_size
    mov ecx, eax
    imul ecx, Token_size
    mov rsi, [rbp - 56]
    add rsi, rcx
    mov r13, [rsi + Token.text]     ; function name

    ; Compare with known names
    mov rsi, r13
    lea rdx, [rel _cf_vec4]
    call _strEq
    test eax, eax
    jnz .callVec4

    mov rsi, r13
    lea rdx, [rel _cf_texture2D]
    call _strEq
    test eax, eax
    jnz .callTexture2D

    ; Unknow -- default identity
    mov byte [rel _ccDebugStage], 64

    call _allocTemp
    cmp eax, -1
    je .errCallTemp
    jmp .done

.errCallTemp:
    mov byte [rel _ccDebugStage], 65
    jmp .fail

;;;;;;;;;;

;;;;;;;;;;
; vec4(a, b)
;;;;;;;;;;
.callVec4:
    mov byte [rel _ccDebugStage], 66

    ; TODO: parser must store arg node indices
    call _allocTemp
    cmp eax, -1
    je .errVec4Temp
    jmp .done

.errVec4Temp:
    mov byte [rel _ccDebugStage], 67
    jmp .fail

;;;;;;;;;;

;;;;;;;;;;
; texture2D(s, uv)
;;;;;;;;;;
.callTexture2D:
    mov byte [rel _ccDebugStage], 68

    ; temporary
    call _allocTemp
    cmp eax, -1
    je .errTexTemp
    jmp .done

.errTexTemp:
    mov byte [rel _ccDebugStage], 69
    jmp .fail

;;;;;;;;;;

;;;;;;;;;;
; MEMBER (swizzle): compile base, emit SWIZZLE.
;;;;;;;;;;
.exprMember:
    mov byte [rel _ccDebugStage], 70

    ; Compile base
    mov rcx, [rbp - 48]
    mov edx, [r12 + ASTNode.a]
    mov r8, [rbp - 56]
    call _compileExpr
    cmp eax, -1
    je .errMemBase
    mov r13d, eax                   ; base reg

    ; Allocate dest
    call _allocTemp
    cmp eax, -1
    je .errMemTemp
    mov r14d, eax

    ; Emit SWIZZLE dst, src, mask-as-srcC
    mov ecx, CGX_OP_SWIZZLE
    mov edx, r14d
    mov r8d, r13d
    mov r9d, [r12 + ASTNode.b]      ; mask
    call _emit
    cmp eax, -1
    je .errMemEmit

    mov eax, r14d
    jmp .done

.errMemBase:
    jmp .fail
.errMemTemp:
    mov byte [rel _ccDebugStage], 76
    jmp .fail
.errMemEmit:
    mov byte [rel _ccDebugStage], 77
    jmp .fail
.fail:
    mov eax, -1

.done:
    add rsp, 40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

;;;;;;;;;;

; --------------------------------------------
; _emit
; Input: ecx = op, edx = dst, r8d = srcA, r9d = srcB
; Output: eax = 0 on success, -1 on fail
; Clobbers: only scratch registers (rax)
; --------------------------------------------
_emit:
    push rbx
    push r12
    push r13

    ; Check capacity
    mov eax, [rel _ccInstrCount]            ; instCount
    cmp eax, [rel _ccInstrCap]              ; capacity
    jge .fail

    ; Instr ptr = output + instrCunt * Instr_size
    mov ebx, eax
    imul ebx, Instr_size
    add rbx, [rel _ccInstrOut]              ; output ptr

    ; Write instruction
    mov [rbx + Instr.op], ecx
    mov [rbx + Instr.dst], edx
    mov [rbx + Instr.srcA], r8d
    mov [rbx + Instr.srcB], r9d
    mov dword [rbx + Instr.srcC], -1
    mov dword [rbx + Instr.pad0], 0

    ; Increment count
    inc dword [rel _ccInstrCount]

    xor eax, eax
    jmp .done

.fail:
    mov eax, -1

.done:
    pop r13
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _emitImm
; Input: ecx = op, edx = dst, r8d = -1 (marker), r9d = immediate bits
; Output: eax = 0 on success, -1 on fail
; --------------------------------------------
_emitImm:
    push rbx
    push r12
    push r13

    mov eax, [rel _ccInstrCount]
    cmp eax, [rel _ccInstrCap]
    jge .fail

    mov ebx, eax
    imul ebx, Instr_size
    add rbx, [rel _ccInstrOut]

    mov [rbx + Instr.op], ecx
    mov [rbx + Instr.dst], edx
    mov [rbx + Instr.srcA], r8d
    mov [rbx + Instr.srcB], r9d
    mov dword [rbx + Instr.srcC], -1
    mov dword [rbx + Instr.pad0], 0

    inc dword [rel _ccInstrCount]

    xor eax, eax
    jmp .done

.fail:
    mov eax, -1

.done:
    pop r13
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _allocTemp
; Output: eax = a fresh register (>=200), or -1 on overflow
; --------------------------------------------
_allocTemp:
    mov eax, [rel _ccTempHigh]         ; tempRegHigh
    cmp eax, 255
    jge .fail
    inc dword [rel _ccTempHigh]
    ret

.fail:
    mov eax, -1
    ret

; --------------------------------------------
; _getSymbolRegByIdx
; Input: rdi = ast (unused), rsi = token (unused)
; Output: eax = register or -1 
; --------------------------------------------
_getSymbolRegByIdx:
    ; save caller-saved
    push rbx
    push r12
    mov r12d, eax                       ; symbol index
    lea rbx, [rel _parserState]
    mov rsi, [rbx + ParseState.symtab]
    
    test rsi, rsi
    jz .failZeroSymTab

    ; slot = symtab + tab * Symbol_size
    mov eax, r12d
    imul eax, Symbol_size
    add rsi, rax

    movzx eax, byte [rsi + Symbol.type]
    cmp al, 0xFF
    jz .failZeroType

    movzx eax, byte [rsi + Symbol.reg]
    pop r12
    pop rbx
    ret

.failZeroSymTab:
    mov byte [rel _ccDebugStage], 80
    jmp .fail
.failZeroType:
    mov byte [rel _ccDebugStage], 81
    jmp .fail
.fail:
    mov eax, -1
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _getSymbolReg
; --------------------------------------------
_getSymbolReg:
    xor eax, eax
    ret

; --------------------------------------------
; _strEq
; Input: rsi = str1, rdx = str2
; Output: eax = 1 if equal
; --------------------------------------------
_strEq:
    push rsi
    push rdx

.loop:
    mov al, [rsi]
    mov cl, [rdx]
    test cl, cl
    jz .yes
    cmp al, cl
    jne .no
    inc rsi
    inc rdx
    jmp .loop

.yes:
    pop rdx
    pop rsi
    mov eax, 1
    ret
.no:
    pop rdx
    pop rsi
    xor eax, eax
    ret