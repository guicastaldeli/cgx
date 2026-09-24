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
    sub rsp, 72

    ; --- Save state ---
    mov [rbp - 8], rcx              ; AST array
    mov [rbp - 16], rdx             ; node count
    mov [rbp - 24], r8              ; token array
    mov [rbp - 32], r9              ; Instr output
    mov rax, [rbp + 48]
    mov [rbp - 40], eax             ; Instr capacity
    mov dword [rbp - 44]            ; instrCount
    mov dword [rbp - 48], 200       ; tempRegHeight (temp register allocator)

    ; First pass: compile top-level DECLs in order
    ; Program node is at index 0 (or the first node)
    xor ebx, ebx                    ; node index

.progLoop:
    mov eax, [rbp - 16]             ; node count
    cmp ebx, eax
    jge .finish

    ; node ptr = ast + idx * ASTNode_size
    mov eax, ebx
    imul eax, ASTNode_size
    mov r12, [rbp - 8]
    add r12, rax

    mov ecx, [r12 + ASTNode.type]

    cmp ecx, CGX_NODE_DECL          ; NODE_DECL
    je .compileDeclTop
    cmp ecx, CGX_NODE_MAIN          ; NODE_MAIN
    je .compileMain
    cmp ecx, CGX_NODE_ASSIGN        ; NODE_ASSIGN
    je .compileAssign
    
    jmp .nextNode

;;;;;;;;;;
; Compile a top-level DECL:
; - if it has an initializer, compile the init, then MOV init -> symbol's reg.
; - Otherwise, skip
;;;;;;;;;;
.compileDeclTop:
    ; node.a = symbol index; node.b = init node or -1
    mov eax, [r12 + ASTNode.a]
    cmp eax, -1
    je .nextNode

    mov ecx, [r12 + ASTNode.b]
    cmp ecx, -1
    je .nextNode                        ; no initializer

    ; Look up the symbol's register
    mov rdi, [rbp - 8]
    mov rsi, [rbp - 24]
    call _getSymbolReg
    ; eax = reg or -1
    cmp eax, -1
    je .nextNode
    mov r13d, eax                       ; dest reg

    ; Compile the initializer
    mov rcx, [rbp - 8]
    mov edx, [r12 + ASTNode.b]
    mov r8, [rbp - 24]
    call _compileExpr
    cmp eax, -1
    je .err
    mov r14d, eax                       ; source reg

    ; EMit MOV dest, source
    mov ecx, CGX_OP_MOV
    mov edx, r13d
    mov r8d, r14d
    mov r9d, -1
    call _emit
    cmp eax, -1
    je .er

    jmp .nextNode

;;;;;;;;;;
; Compile a MAIN node: walk its statement list
;;;;;;;;;;
.compileMain:
    ; Main body statements are subsequent nodes.
    ; Continue the outer loop; assignments will be picked up by
    ; the ASSIGN handler on the next iteration...
    jmp .nextNode

;;;;;;;;;;
; Compile a top-level ASSIGN node
;;;;;;;;;;
.compileAssign:
    mov rdi, [rbp - 8]
    mov rsi, [rbp - 24]          ; node ptr
    mov rdx, r12
    call _compileAssign
    cmp eax, -1
    je .err
    jmp .nextNode

.nextNode:
    inc ebx
    jmp .projLoop

.finish:
    ; Emit HALT
    mov ecx, CGX_OP_HALT
    mov edx, -1
    mov r8d, -1
    mov r9d, -1
    call _emit
    cmp eax, -1
    je .err

    mov eax, [rbp - 44]         ; return instr count
    jmp .done

.err:
    xor eax, eax

.done:
    add rsp, 72
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
    sub rsp, 56

    mov [rbp - 8], rdi              ; asi
    mov [rbp - 16], rsi             ; tokens
    mov r12, rdx                    ; node

    ; LHS node
    mov eax, [r12 + ASTNode.a]
    mov [rbp - 24], 24              ; lhs idx

    ; RHS node
    mov eax, [r12 + ASTNode.b]
    mov [rbp - 28], eax             ; rhs idx

    ; Operator
    mov eax, [r12 + ASTNode.c]
    mov [rbp - 32], eax             ; op

    ; --- Handle LHS ---
    ; LHS must be an IDENT or MEMBER
    mov eax, [rbp - 24]
    mov ecx, eax
    imul ecx, ASTNode_size
    mov r13, [rbp - 8]
    add r13, rcx
    ; r13 = lhs node ptr

    mov ecx, [r13 + ASTNode.type]

    cmp ecx, CGX_NODE_IDENT
    je .lhsIdent
    cmp ecx, CGX_NODE_MEMBER
    je .lhsMember

    jmp .fail

.lhsIdent:
    ; lhs.a = symbol index
    mov rdi, [rbp - 8]
    mov rsi, [rbp - 16]
    mov eax, [r13 + ASTNode.a]
    call _getSymbolRegByIdx
    cmp eax, -1
    je .fail
    mov r14d, eax               ; dest reg
    jmp .compileRhs
.lheMember:
    jmp .fail
.compileRhs:
    ; Compile RHS expression
    mov rcx, [rbp - 8]
    mov edx, [rbp - 28]
    mov r8, [rbp - 16]
    call _compileExpr
    cmp eax, -1
    je .fail
    mov r15d, eax               ; source reg

    ; Emit MOV dest, source
    mov ecx, CGX_OP_MOV
    mov edx, r14d
    mov r8d, r15d
    mov r9d, -1
    call _emit
    cmp eax, -1
    je .fail

    ; TODO: compund assignment not yet supported...
    xor eax, eax

.fail:
    mov eax, -1

.done:
    add rsp, 56
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
    