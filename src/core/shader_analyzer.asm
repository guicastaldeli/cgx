; ============================================
; core/shader_analyze.asm
; Semantic analysis: resolve identifier names,
; assign types, assign registers
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"
%include "shader.inc"

extern _cgxCoreState
extern CGXState

extern _cgxCoreParserFindSymbol
extern _parserState

global _cgxCoreAnalyze

section .data
    ; GL methods
    _name_gl_Position           db "gl_Position", 0
    _name_gl_FragColor          db "gl_FragColor", 0

    ; Math methods
    _fn_vec2                    db "vec2", 0
    _fn_vec3                    db "vec3", 0
    _fn_vec4                    db "vec4", 0
    _fn_mat4                    db "mat4", 0
    _fn_dot                     db "dot", 0
    _fn_normalize               db "normalize", 0
    _fn_texture2D               db "texture2D", 0

section .text

; --------------------------------------------
; _cgxCoreAnalyze
; Input: rcx = AST array ptr
;       edx = AST node count
;       r8 = token array ptr
; Output: eax = 1 on succes, 0 on error
; Uses _parserState for symtab access
; --------------------------------------------
_cgxCoreAnalyze:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 56

    mov r12, rcx                    ; AST array
    mov r13d, edx                   ; node count
    mov r14, r8                     ; token array

    lea r15, [rel _parserState]     ; parser state (has symtab)

    xor ebx, ebx                    ; node index

.walkLoop:
    cmp ebx, r13d
    jge .assignRegs

    ; node ptr = ast + idx * ASTNode_size
    mov eax, ebx
    imul eax, ASTNode_size
    mov rdi, r12
    add rdi, rax
    mov [rbp - 8], rdi              ; save node ptr

    mov ecx, [rdi + ASTNode.type]

    cmp ecx, CGX_NODE_IDENT         ; NODE_IDENT
    je .resolveIdent
    cmp ecx, CGX_NODE_DECL          ; NODE_DECL
    je .resolveDecl
    cmp ecx, CGX_NODE_CALL          ; NODE_CALL
    je .resolveCall
    cmp ecx, CGX_NODE_LITERAL       ; NODE_LITERAL
    je .typeLiteral
    cmp ecx, CGX_NODE_BINARY        ; NODE_BINARY
    je .typeBinary
    cmp ecx, CGX_NODE_ASSIGN        ; NODE_ASSIGN
    je .typeAssign
    cmp ecx, CGX_NODE_MEMBER        ; NODE_MEMBER
    je .typeMember

    jmp .nextNode

;;;;;;;;;;
; IDENT: .a holds a token index
; Look up token.text in symtab. Replace .a with symbol index
; Set typeId from the symbol
;;;;;;;;;;
.resolveIdent:
    ; token index = node.a
    mov eax, [rdi + ASTNode.a]

    ; token ptr = tokens + idx * Token_size
    mov ecx, eax
    imul ecx, Token_size
    mov rsi, r14
    add rsi, rcx
    mov [rbp - 16], rsi         ; save token ptr

    ; name ptr = token.text
    mov rcx, [rsi + Token.text]

    ; Compute lengt by scanning until non-ident char
    xor edx, edx

.lenScan:
    movzx eax, byte [rcx + rdx]
    test al, al
    jz .lenDone
    cmp al, 'a'
    jl .lenUp
    cmp al, 'z'
    jle .lenInc
.lenUp:
    cmp al, 'A'
    jl .lenDig
    cmp al, 'Z'
    jle .lenInc
.lenDig:
    cmp al, '0'
    jl .lenUnd
    cmp al, '9'
    jle .lenInc
.lenUnd:
    cmp al, '_'
    jne .lenDone
.lenInc:
    inc edx
    cmp edx, 31
    jl .lenScan
.lenDone:
    ; Now rcx = name, edx = length
    mov r8, r15                         ; ParseState
    call _cgxCoreParserFindSymbol
    cmp eax, -1
    je .identMaybeBuiltin

    ; Found: replace .a with symbol index
    mov rdi, [rbp - 8]
    mov [rdi + ASTNode.a], eax

    ; typeId = symbol type
    mov rsi, [r15 + ParseState.symtab]
    mov ecx, eax
    imul ecx, Symbol_size
    add rsi, rcx
    movzx ecx, byte [rsi + Symbol.type]
    mov [rdi + ASTNode.typeId], ecx
    
    jmp .nextNode

.identMaybeBuiltin:
    ; Check for gl_Position / gl_FragColor by comparing the name string
    mov rdi, [rbp - 16]                 ; token ptr
    mov rsi, [rdi + Token.text]

    lea rdx, [rel _name_gl_Position]
    call _strEq
    test eax, eax
    jnz .isGLPosition
    
    mov rdi, [rbp - 16]
    mov rsi, [rdi + Token.text]
    lea rdx, [rel _name_gl_FragColor]
    call _strEq
    test eax, eax
    jnz .isGLFragColor

    ; Unknown Identifier -- set type to vec4 as fallback
    mov rdi, [rbp - 8]
    mov dword [rdi + ASTNode.typeId], CGX_TYPE_VEC4
    jmp .nextNode
;;;;;;;;;;

;;;;;;;;;;
;
; GL methods
;
;;;;;;;;;;
.isGLPosition:
    mov rdi, [rbp - 8]
    mov dword [rdi + ASTNode.a], 0                          ; symbol index 0 = gl_Position
    mov dword [rdi + ASTNode.typeId], CGX_TYPE_VEC4
    jmp .nextNode
.isGLFragColor:
    mov rdi, [rbp - 8]
    mov dword [rdi + ASTNode.a], 1                          ; symbol index 1 = gl_FragColor
    mov dword [rdi + ASTNode.typeId], CGX_TYPE_VEC4
    jmp .nextNode
;;;;;;;;;;

;;;;;;;;;;
;
; DECL: typeId = the symbol's type
;
;;;;;;;;;;
.resolveDecl:
    mov eax, [rdi + ASTNode.a]
    cmp eax, -1
    je .nextNode
    
    mov rsi, [r15 + ParseState.symtab]
    mov ecx, eax
    imul ecx, Symbol_size
    add rsi, rcx
    movzx ecx, byte [rsi + Symbol.type]
    mov [rdi + ASTNode.typeId], ecx

;;;;;;;;;;

;;;;;;;;;;
; CALL: node.a is a base node index (typically an IDENT)/
; Look up the node's token, read the function name,
; match agains built-in names, set typeId
;;;;;;;;;;
.resolveCall:
    mov eax, [rdi + ASTNode.a]
    cmp eax, -1
    je .callDefault

    ; base node = ast[a]
    mov ecx, eax
    imul ecx, ASTNode_size
    mov rsi, r12
    add rsi, rcx
    ; rsi = base node ptr
    mov ecx, [rsi + ASTNode.type]
    cmp ecx, CGX_NODE_IDENT
    jne .callDefault

    ; IDENT's .a is a token index
    mov eax, [rsi + ASTNode.a]
    mov ecx, eax
    imul ecx, Token_size
    mov rsi, r14
    add rsi, rcx
    mov rsi, [rsi + Token.text]         ; function name

    ; Compare with each known name
    mov rdi, rsi

    ; vec2?
    lea rdx, [rel _fn_vec2]
    call _strEq
    test eax, eax
    jnz .isVec2

    ; vec3?
    mov rdi, rsi
    lea rdx, [rel _fn_vec3]
    call _strEq
    test eax, eax
    jnz .isVec3

    ; vec4?
    mov rdi, rsi
    lea rdx, [rel _fn_vec4]
    call _strEq
    test eax, eax
    jnz .isVec4

    ; mat4?
    mov rdi, rsi
    lea rdx, [rel _fn_mat4]
    call _strEq
    test eax, eax
    jnz .isMat4

    ; dot?
    mov rdi, rsi
    lea rdx, [rel _fn_dot]
    call _strEq
    test eax, eax
    jnz .isDot

    ; normalize?
    mov rdi, rsi
    lea rdx, [rel _fn_normalize]
    call _strEq
    test eax, eax
    jnz .isNormalize

    ; is tex2d?
    mov rdi, rsi
    lea rdx, [rel _fn_texture2D]
    call _strEq
    test eax, eax
    jnz .isTexture2D

    jmp .callDefault

.isVec2:
    mov rdi, [rbp - 8]
    mov dword [rdi + ASTNode.typeId], CGX_TYPE_VEC2
    jmp .nextNode
.isVec3:
    mov rdi, [rbp - 8]
    mov dword [rdi + ASTNode.typeId], CGX_TYPE_VEC3
    jmp .nextNode
.isVec4:
    mov rdi, [rbp - 8]
    mov dword [rdi + ASTNode.typeId], CGX_TYPE_VEC4
    jmp .nextNode
.isMat4:
    mov rdi, [rbp - 8]
    mov dword [rdi + ASTNode.typeId], CGX_TYPE_MAT4
    jmp .nextNode
.isDot:
    mov rdi, [rbp - 8]
    mov dword [rdi + ASTNode.typeId], CGX_TYPE_FLOAT
    jmp .nextNode
.isNormalize:
    mov rdi, [rbp - 8]
    mov dword [rdi + ASTNode.typeId], CGX_TYPE_VEC3
    jmp .nextNode
.isTexture2D:
    mov rdi, [rbp - 8]
    mov dword [rdi + ASTNode.typeId], CGX_TYPE_VEC4
    jmp .nextNode

.callDefault:
    mov rdi, [rbp - 8]
    mov dword [rdi + ASTNode.typeId], CGX_TYPE_VEC4
    jmp .nextNode

;;;;;;;;;;

;;;;;;;;;;
; LITERAL: always float
;;;;;;;;;;
.typeLiteral:
    mov dword [rdi + ASTNode.typeId], CGX_TYPE_FLOAT
    jmp .nextNode

;;;;;;;;;;

;;;;;;;;;;
; BINARY: typeId = type of lhs node
;;;;;;;;;;
.typeBinary:
    mov eax, [rdi + ASTNode.a]
    cmp eax, -1
    je .nextNode
    mov ecx, eax
    imul ecx, ASTNode_size
    mov rdi, r12
    add rsi, rcx
    mov ecx, [rsi + ASTNode.typeId]
    mov [rdi + ASTNode.typeId], ecx
    jmp .nextNode

;;;;;;;;;;

;;;;;;;;;;
; ASSIGN: typeId = type of rhs node
;;;;;;;;;;
.typeAssign:
    mov eax, [rdi + ASTNode.b]
    cmp eax, -1
    je .nextNode
    mov ecx, eax
    imul ecx, ASTNode_size
    mov rsi, r12
    add rsi, rcx
    mov ecx, [rsi + ASTNode.typeId]
    mov [rdi + ASTNode.typeId], ecx
    jmp .nextNode

;;;;;;;;;;

;;;;;;;;;;
; MEMBER: component count derived from mask.
; Mask format: 4 bytes, each byte is a source index (0..3) or 0.
;;;;;;;;;;
.typeMember:
    mov dword [rdi + ASTNode.typeId], CGX_TYPE_VEC4
    jmp .nextNode

;;;;;;;;;;

.nextNode:
    inc ebx
    jmp .walkLoop

;;;;;;;;;;
; Second pass: assign registers to every used symbol.
; Register 0 reserved for gl_Position (vertex) or gl_FragColor (frag)
; Register 1 reserved for the other built-in
; User symbols start at register 2
;;;;;;;;;;
.assignRegs:
    mov rsi, [r15 + ParseState.symtab]
    xor eax, eax                                ; symbol index
    mov ecx, 2                                  ; next free register

.symLoop:
    cmp eax, CGX_MAX_SYMBOLS
    jge .done

    movzx edx, byte [rsi + Symbol.type]
    test dl, dl
    jz .nextSym

    mov [rsi + Symbol.reg], cl
    inc ecx

.nextSym:
    add rsi, Symbol_size
    inc eax
    jmp .symLoop

;;;;;;;;;;

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
; _strEq
; Input: rsi = str1, rdx = str2
; Output: eax = 1 if equal (null-terminated match)
; --------------------------------------------
_strEq:
    push rsi
    push rdx

.loop:
    mov al, [rsi]
    mov cl, [rdx]
    cmp al, cl
    jne .no
    test al, al
    jz .yes
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