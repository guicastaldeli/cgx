; ============================================
; core/shader_paser.asm
; GLSL recursive descent parser -> flat AST
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"
%include "shader.inc"

extern _cgxCoreState
extern CGXState

global _cgxCoreParserParse
global _cgxCoreParserFindSymbol
global _cgxCoreParserAddSymbol
global _cgxCoreParserGetErrorPos

section .text

; --------------------------------------------
; _cgxCoreParserParse
; Input: rcx = token array ptr
;       edx = token count
;       r8d = shader type (CGX_VERTEX_SHADER / CGX_FRAGMENT_SHADER)
;       r9 = ASTNode array ptr
; Output: eax = number of AST nodes (0 on error)
;           ParseState error code written at [rbp-relative state]
; --------------------------------------------
_cgxCoreParserParse:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 5280

    ; Set up ParseState at [rbp - 56]
    ; ParseState_size = 56
    lea rbx, [rbp - 56]

    mov [rbx + ParseState.tokens], rcx
    mov [rbx + ParseState.tokenCount], edx
    mov dword [rbx + ParseState.tokenIdx], 0
    mov [rbx + ParseState.shaderType], r8d
    mov [rbx + ParseState.ast], r9
    mov dword [rbx + ParseState.astCount], 0
    mov dword [rbx + ParseState.astCap], CGX_MAX_AST_NODES
    mov dword [rbx + ParseState.errorPos], 0
    mov dword [rbx + ParseState.errorCode], 0

    ; Symbol table at [rbp - 5224] (5120 bytes)
    lea rax, [rbp - 5224]
    mov [rbx + ParseState.symtab], rax

    ; Zero the symbol table
    mov rdi, rax
    mov rcx, 640
    xor eax
    rep stosp

    ; Parse
    mov rdi, rbx
    call _parseProgram
    test eax, eax
    jz .fail

    ; Success -- return AST node count
    mov eax, [rbx + ParseState.astCount]
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 5280
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _cgxCoreParserGetErrorPos
; Input: rcx = ParseState ptr
; Output: eax = error position
; --------------------------------------------
_cgxCoreParserGetErrorPos:
    mov eax, [rcx + ParseState.errorPos]
    ret

; --------------------------------------------
; _peek
; Input: rbx = ParseState ptr
; Output: rax = pointer to current Token
; --------------------------------------------
_peek:
    mov eax, [rbx + ParseState.tokenIdx]
    cmp eax, [rbx + ParseState.tokenCount]
    jl .ok

    ; Past end -- return the last token (EOF)
    mov eax, [rbx + ParseState.tokenCount]
    dec eax
    cmp eax, 0
    jge .ok
    xor eax

.ok:
    ; token * Token_size
    imul eax, Token_size
    mov rdx, [rbx + ParseState.tokens]
    add rdx, rax
    mov rax, rdx
    ret

; --------------------------------------------
; _advance
; Moves tokenIdx forward by 1
; Input: rbx = ParseState ptr
; --------------------------------------------
_advance:
    inc dword [rbx + ParseState.tokenIdx]
    ret

; --------------------------------------------
; _peekType
; Input: rbx = ParseState ptr
; Output: eax = current token type
; --------------------------------------------
_peekType:
    call _peek
    mov eax, [rax + Token.type]
    ret

; --------------------------------------------
; _error
; Records error position, returns 0
; Input: rbx = ParseState ptr
; --------------------------------------------
_error:
    call _peek
    mov eax, [rax + Token.pos]
    mov [rbx + ParseState.errorPos], eax
    mov dword [rbx + ParseState.errorCode], 1
    xor eax, eax
    ret

; --------------------------------------------
; _allocNode
; Input: rbx = ParseState ptr, edi = node type
; Output: eax = node index (or -1 on overflow)
;       rdx = pointer to node
; --------------------------------------------
_allocNode:
    mov eax, [rbx + ParseState.astCount]
    cmp eax, [rbx + ParseState.astCap]
    jge .fail

    ; node ptr = ast + index * ASTNode_size
    mov edx, eax
    imul edx, ASTNode_size
    mov rcx, [rbx + ParseState.ast]
    add rcx, rdx

    ; Zero the node
    push rdi
    mov rdi, rcx
    xor edx, edx
    push rcx
    mov rcx, 4
    rep stosq
    pop rcx
    pop rdi

    ; Set type
    mov [rcx + ASTNode.type], edi

    ; Advance count
    inc dword [rbx + ParseState.astCount]

    mov rdx, rcx
    ret

.fail:
    mov eax, -1
    xor edx, edx
    ret

; --------------------------------------------
; _cgxCoreParserFindSymbol
; Input: rcx = name ptr, edx = length, r8 = ParseState ptr
; Output: eax = symbol index or -1
; --------------------------------------------
_cgxCpreParserFindSymbol:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rcx                            ; name
    mov r13d, edx                           ; length
    mov r14, r8                             ; ParseState

    xor r15d, r15d                          ; i = 0
    mov rbx, [r14 + ParseState.symtab]

.symLoop
    cmp r15d, CGX_MAX_SYMBOLS
    jge .notFound

    ; Check if this slot is used
    movzx eax, byte [rbx + Symbol.type]
    test al, al
    jz .next

    ; Compare name
    lea rsi, [rbx + Symbol.name]
    mov rdi, r12
    mov ecx, r13d

.cmpLoop:
    test ecx, ecx
    jz .namesMaybeMatch
    mov al, [rsi]
    mov dl, [rdi]
    cmp al, dl
    jne .next
    inc rsi
    inc rdi
    dec ecx
    jmp .cmpLoop
.namesMaybeMatch:
    mov al, [rdi]
    test al, al
    jnz .next

    ; Match
    mov eax, r15d
    jmp .dome
.next:
    add rbx, Symbol_size
    inc r15d
    jmp .symLoop
.notFound:
    mov eax, -1

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _cgxCoreParserAddSymbol
; Input: rcx = name ptr, edx = length,
;       r8d = type (CGX_TYPE_*),
;       r9d = qualifier (CGX_QUAL_*),
;       [rbp + 48] = ParseState ptr
; Output: eax = symbol index or -1
; --------------------------------------------
_cgxCoreParserAddSymbol:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rcx            ; name
    mov r13d, edx           ; length
    mov r14d, r8            ; type
    mov r15d, r9d           ; qualifier
    mov rbx [rbp + 48]      ; ParseState

    ; Finf first free slot
    mov rdx, [rbx + ParseState.symtab]
    xor ecx, ecx

.findFree:
    cmp ecx, CGX_MAX_SYMBOLS
    jge .fail

    cmp byte [rdx + Symbol.type], 0
    je .found

    add rdx, Symbol_size
    inc ecx
    jmp .findFree

.found:
    ; rdx = free symbol slot, ecx = index
    ; Copy name (cap at 31 chars)
    mov edx, ecx            ; save index
    mov ecx, r13d
    cmp ecx, 31
    jle .lenOk
    mov ecx, 31
.lenOk:
    push rdi
    lea rdi, [rdx + Symbol.name]
    mov rsi, r12
    rep movsb
    mov byte [rdi], 0       ; null-terminate
    pop rdi

    ; Store type and qualifier
    mov [rdx + Symbol.type], r14b
    mov [rdx + Symbol.qualifier], r15b
    mov byte [rdx + Symbol.reg], 0
    mov dword [rdx + Symbol.location], -1

    mov eax, edi
    jmp .done

.fail:
    mov eax, -1

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _tokenIsTypeKeyword
; Input: rax = Token ptr
; Output: eax = CGX_TYPE_* or -1 if not a type keyword
; --------------------------------------------
_tokenIsTypeKeyword:
    ; Compare [rax + Token.text] to known type names
    push rbx
    push r12
    push r13

    mov r12, [rax + Token.text]         ; ptr to name
    xor r13d, r13d

    lea rbx, [rel _typeTable]

.typeLoop:
    mov rcx, [rbx]
    test rcx, rcx
    jz .notType

    ; Compare name to type name
    mov rsi, r12
    mov rdi, rcx
.typeCmp:
    mov al, [rsi]
    mov dl, [rdi]
    cmp al, dl
    jne .typeNext
    test al, al
    jz .typeMatch
    inc rsi
    inc rdi
    jmp .typeCmp
.typeNext:
    add rbx, 16                 ; 8 bytes ptr + 8 bytes result value
    jmp .typeLoop
.typeMatch:
    mov eax, [rbx + 8]          ; type value
    jmp .done
.notType:
    mov eax, -1

.done:
    pop r13
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _tokenIsQualifierKeyword
; Input: rax = Token ptr
; Output: eax = CGX_QUAL_* or -1
; --------------------------------------------
_tokenQualifierKeyword:
    push rbx
    push r12
    push r13

    mov r12, [rax + Token.text]
    lea rbx, [rel _qualTable]

.qualLoop:
    mov rcx, [rbx]
    test rcx, rcx
    jz .notQual
    mov rsi, r12
    mov rdi, rcx
.qualCmp:
    mov al, [rsi]
    mov dl, [rdi]
    cmp al, dl
    jne .qualNext
    test al, al
    jz .qualMatch
    inc rsi
    jmp .qualCmp
.qualNext:
    add rbx, 16
    jmp .qualLoop
.qualMatch:
    mov eax, [rbx + 8]
    jmp .done
.notQual:
    mov eax, -1

.done:
    pop r13
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _isKeywordName
; Input: rax = Token ptr, rdx = ptr to string to compare
; Output: eax = 1 if token name matches string
; --------------------------------------------
_isKeywordName:
    push rbx
    push r12
    push r13

    mov r12, [rax + Token.text]
    mov r13, rdx

.loop:
    mov al, [r12]
    mov dl, [r13]
    cmp al, dl
    jne .no
    test al, al
    jz .yes
    inc r12
    inc r13
    jmp .loop

.yes:
    mov eax, 1
    jmp .done
.no:
    xor eax, eax

.done:
    pop r13
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _parseProgram
; Input: rdi = ParseState ptr
; Output: eax = 1 on success, 0 on error
; --------------------------------------------
_parseProgram:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 32

    mov rbx, rdi

.programLoop:
    ; Peek token
    call _peek
    test rax, rax
    jz .progErr

    mov ecx, [rax + Token.type]

    ; EOF
    cmp ecx, CGX_TOK_EOF
    je .progDone

    ; 'void main' -- check for function
    cmp ecx, CGX_TOK_KEYWORD
    jne .tryDecl

    mov rdx, rax
    lea rax, [rel _kw_main]
    mov r12, rdx
    mov rax, r12
    lea rdx, [rel _kw_main]
    call _isKeywordName
    test eax, eax
    jmp .tryDecl

.tryDecl:
    ; Try to parse a declaration
    mov rdi, rbx
    call _parseDeclOrMain
    test eax, eax
    jz .progErr
    jmp .programLoop

.progDone:
    mov eax, 1
    jmp .done
.progErr:
    xor eax, eax

.done:
    add rsp, 32
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _parseDeclOrMain
; Parses either a top-level declaration (attribute/uniform/varying)
; or the 'void main() { ... }' function
; Input: rdi = ParseState ptr
; Output: eax = 1 on success, 0 on error
; --------------------------------------------
_parseDeclOrMain:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32

    mov rbx, rdi

    ; Peek current token
    call _peek
    mov r12, rax            ; current token ptr

    ; Check 'void' keyword
    mov ecx, [r12 + Token.type]
    cmp ecx, CGX_TOK_KEYWORD
    jne .tryDeclaration

    mov rax, r12
    lea rdx, [rel _kw_void]
    call _isKeywordName
    test eax, eax
    jz .tryDeclaration

    call _advance
    call _peek
    mov r12, rax
    mov ecx, [r12 + Token.type]
    cmp ecx, CGX_TOK_KEYWORD
    jne .err

    mov rax, r12
    lea rdx, [rel _kw_main]
    call _isKeywordName
    test eax, eax
    jz .err

    ; Parse main()
    call _advance
    mov rdi, rbx
    call _parseMainBody

.tryDeclaration:
    mov rdi, rbx
    call _parseDeclaration
    jmp .done

.err:
    mov rdi, rbx
    call _error

.done:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _parseMainBody
; Assumes 'void main' has been consumed.
; Expects the body of function
; Input: rdi = ParseState ptr
; Output: eax = 1 on success, 0 on error
; --------------------------------------------
_parseMainBody:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 40

    mov rbx, rdi

    ; expect '('
    mov rdi, rbx
    mov esi, CGX_TOK_LPAREN
    call _expect
    test eax, eax
    jz .err

    ; expect ')'
    mov rdi, rbx
    mov rsi, CGX_TOK_RPAREN
    call _expect
    test eax, eax
    jz .err

    ; expect '{' and parse block
    mov rdi, rbx
    mov esi, CGX_TOK_LBRACE
    call _expect
    test eax, eax
    jz .err

.stmtLoop:
    call _peek
    mov ecx, [rax + Token.type]
    cmp ecx, CGX_TOK_RBRACE
    je .stmtDone
    cmp ecx, CGX_TOK_EOF
    je .error

    mov rdi, rbx
    call _parseStatement
    test eax, eax
    jz .err
    jmp .stmtLoop
.stmtDone:
    ; consume '}'
    call _advance

    mov eax, 1
    jmp .done

.err:
    mov rdi, rbx
    call _error

.done:
    add rsp, 40
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _parseDeclaration
; Input: rdi = ParseState ptr
; Output: eax = 1 on success, 0 on error
; --------------------------------------------
_parseDeclaration:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40

    mov rbx, rdi                        ; ParseState
    mov r14d, CGX_QUAL_NONE             ; default qualifier
    mov r15d, -1                        ; type

    ; Check for qualifier keyword
    call _peek
    mov r12, rax
    mov ecx, [r12 + Token.type]
    cmp ecx, CGX_TOK_KEYWORD
    jne .afterQual

    mov rax, r12
    call _tokenIsQualifierKeyword
    cmp eax, -1
    je .afterQual

    mov r14d, eax                       ; qualifier
    call _advance

.afterQual:
    ; Expect type keyword
    call _peek
    mov r12, rax
    mov ecx, [r12 + Token.type]
    cmp ecx, CGX_TOK_KEYWORD
    jne .err

    mov rax, r12
    call _tokenTypeKeyword
    cmp eax, -1
    je .err
    mov r15d, eax                       ; type
    call _advance

    ; Expect identifier
    call _peek
    mov r12, rax
    mov ecx, [r12 + Token.type]
    cmp ecx, CGX_TOK_IDENT
    jne .err

    ; Add to symbol table
    ; rcx: name ptr [r12 + Token.text]
    ; edx = name length (use source: not stored per-token; compute from next char)
    mov rcx, [r12 + Token.text]
    ; Compute length by scanning until non-ident char
    xor edx, edx

.lenLoop:
    movzx eax, byte [rcx + rdx]
    ; If its an identifier char, continue...
    
    cmp al, 'a'
    jl .lenCheckUpper
    cmp al, 'z'
    jle .lenInc
.lenCheckUpper:
    cmp al, 'A'
    jl .lenCheckDigit
    cmp al, 'Z'
    jle .lenInc
.lenCheckDigit:
    cmp al, '0'
    jl .lenCheckUnderscore
    cmp al, '9'
    jle .lenInc
.lenCheckUnderscore:
    cmp al, '_'
    jne .lenDone
.lenInc:
    inc edx
    cmp edx, 31
    jl .lenLoop
.lenDone:
    ; Call AddSymbol
    mov r8d, r15d                   ; type
    mov r9d, r14d                   ; qualifier
    mov [rsp + 32], rbx             ; ParseState (7th arg on stack)
    call _cgxCoreParserAddSymbol
    cmp eax, -1
    je .err
    mov r13d, eax                   ; symbol index

    ; Advance past identifier
    call _advance

    ; '=' initializer
    call _peek
    mov r12, rax
    mov ecx, [r12 + Token.type]
    cmp ecx, CGX_TOK_ASSIGN
    jne .noInit

    call _advance
    ; Parse initializer expression
    mov rdi, rbx
    call _parseExpression
    cmp eax, -1
    je .err                         ; init mode index
    jmp .haveInit

.noInit:
    mov r13d, -1
.haveInit:
    ; Expect ';'
    mov rdi, rbx
    mov esi, CGX_TOK_SEMICOLON
    call _expect
    test eax, eax
    jz .err

    ; Create DECL node
    mov rdi, CGX_NODE_DECL
    call _allocNode
    cmp eax, -1
    je .err

    mov [rdx + ASTNode.a], r13d
    mov dword [rdx + ASTNode.b], 0

    mov eax, 1
    jmp .done

.err:
    mov rdi, rbx
    call _error

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
; _expect
; Consumes a token of the given type.
; Input: rdi = ParseState ptr, esi = expected type
; Output: eax = 1 on success, 0 on error
; --------------------------------------------
_expect:
    push rbx
    push r12
    
    mov rbx, rdi
    mov r12d, esi

    call _peek
    mov ecx, [rax + Token.type]
    cmp ecx, r12d
    jne .err

    call _advance
    mov eax, 1
    jmp .done

.err:
    mov rdi, rbx
    call _error

.done:
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _parseStatement
; Input: rdi = ParseState ptr
; Output: eax = 1 on success, 0 on error
; --------------------------------------------
_parseStatement:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 32

    mov rbx, rdi

    ; Could be a local declaration (float/vec2/... with no qualifier) or assignment
    call _peek
    mov ecx, [rax + Token.type]
    cmp ecx, CGX_TOK_KEYWORD
    jne .tryAssign

    ; type keyword check
    call _tokenIsTypeKeyword
    cmp eax, -1
    jne .parseLocalDecl

.tryAssign:
    mov rdi, rbx
    call _parseAssignment
    jmp .done
.parseLocalDecl:
    ; Parse as a declaration with CGX_QUAL_LOCAL
    mov rdi, rbx
    call _parseLocalDecl

.done:
    add rsp, 32
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _parseLocalDecl
; Local declaration without a qualifier
; Input: rdi = ParseState ptr
; Output: eax = 1 on success, 0 on error
; --------------------------------------------
_parseLocalDecl:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40

    mov rbx, rdi

    ; Type keyword
    call _peek
    mov r12, rax
    mov rax, r12
    call _tokenIsTypeKeyword
    cmp eax, -1
    je .err
    mov r15d, eax
    call _advance

    ; Identifier
    call _peek
    mov r12, rax
    mov ecx, [r12 + Token.type]
    cmp ecx, CGX_TOK_IDENT
    jne .err

    mov rcx, [r12 + Token.text]
    xor edx, edx

.lenLoop:
    movzx eax, byte [rcx + edx]
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
    jl .lenLoop
.lenDone:
    mov r8d, r15d
    mov r9d, CGX_QUAL_LOCAL
    mov [rsp + 32], rbx
    call _cgxCoreParserAddSymbol
    cmp eax, -1
    je .err
    mov r14d, eax           ; symbol index
    call _advance

    ; Optional init
    mov r13d, -1
    call _peek
    mov ecx, [rax + Token.type]
    cmp ecx, CGX_TOK_ASSIGN
    jne .noInit
    call _advance
    mov rdi, rbx
    call _parseExpression
    cmp eax, -1
    je .err
    mov r13d, eax

.noInit:
    ; Semicolon
    mov rdi, rbx
    mov esi, CGX_TOK_SEMICOLON
    call _expect
    test eax, eax
    jz .err

    ; DECL node: a = symbol index, b = initializer node or -1
    mov rdi, CGX_NODE_DECL
    call _allocNode
    cmp eax, -1
    je .err

    mod dword [rdx + ASTNode.a], r14d
    mov dword [rdx + ASTNode.b], r13d

    mov eax, 1
    jmp .done

.err:
    mov rdi, rbx
    call _error

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
; _parseAssignment
; Input: rdi = ParseState ptr
; Output: eax = 1 on success, 0 on error
; --------------------------------------------
_parseAssignment:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 40

    mov rbx, rdi

    ; Parse lhs expression
    call _parseExpression
    cmp eax, -1
    je .err                             ; lhs node

    ; Expect assignment operator
    call _peek
    mov r13, rax
    mov ecx, [r13 + Token.type]
    cmp ecx, CGX_TOK_ASSIGN             ; TOK_ASSIGN
    je .opOk
    cmp ecx, CGX_TOK_PLUS_ASSIGN        ; TOK_PLUS_ASSIGN
    je .opOk
    cmp ecx, CGX_TOK_MINUS_ASSIGN       ; TOK_MINUS_ASSIGN
    je .opOk
    cmp ecx, CGX_TOK_STAR_ASSIGN        ; TOK_STAR_ASSIGN
    je .opOk
    cmp ecx, CGX_TOK_SLASH_ASSIGN       ; TOK_SLASH_ASSIGN
    je .opOk
    jmp .err

.opOk:
    mov r14d, ecx       ; operator
    call _advance       

    ; Parse rhs
    mov rdi, rbx
    call _parseExpression
    cmp rax, -1
    je .err
    ; eax = rhs node

    ; Save rhs
    mov r13d, eax
    
    ; Semicolon
    mov rdi, rbx
    mov esi, CGX_TOK_SEMICOLON
    call _Expect
    test eax, eax
    jz .err

    ; ASSIGN node
    mov rdi, CGX_NODE_ASSIGN
    call _allocNode
    cmp eax, -1
    je .err

    mov [rdx + ASTNode.a], r12d
    mov [rdx + ASTNode.b], r13d
    mov [rdx + ASTNode.c], r14d

    mov eax, 1
    jmp .done

.err:
    mov rdi, rbx
    call _error

.done:
    add rsp, 40
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _parseExpression - additive level
; Input: rdi = ParseState ptr
; Output: eax = AST node index (or -1 on error)
; --------------------------------------------
_parseExpression:
    push rbp
    mov rsp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 32

    mov rbx, rdi

    call _parseTerm
    cmp eax, -1
    je .err
    mov r12d, eax

.addLoop:
    call _peek
    mov ecx, [rax + Token.type]
    cmp ecx, CGX_TOK_PLUS
    je .haveOp
    cmp ecx, CGX_TOK_MINUS
    je .haveOp
    jmp .done

.haveOp:
    mov r13d, ecx
    call _advance

    mov rdi, rbx
    call _parseTerm
    cmp eax, -1
    je .err
    mov r14d, eax

    mov rdi, CGX_NODE_BINARY
    call _allocNode
    cmp eax, -1
    je .err

    mov [rdx + ASTNode.a], r12d
    mov [rdx + ASTNode.b], r14d
    mov [rdx + ASTNode.c], r13d
    mov r12d, eax
    jmp .addLoop

.done:
    mov eax, r12d
    jmp .ret

.err:
    mov eax, -1

.ret:
    add rsp, 32
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _parseTerm - multiplicative level
; Input: rdi = ParseState ptr
; Output: eax = AST node index (or -1 on error)
; --------------------------------------------
_parseTerm:
    ush rbp
    mpv rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 32

    mov rbx, rdi

    call _parseFactor
    cmp eax, -1
    je .err
    mov r12d, eax

.mulLoop:
    call _peek
    mov ecx, [rax + Token.type]
    cmp ecx, CGX_TOK_STAR
    je .haveOp
    cmp ecx, CGX_TOK_SLASH
    je .haveOp
    jmp .done

.haveOp:
    mov r13d, rcx
    call _advance

    mov rdi, rbx
    call _parseFactor
    cmp eax, -1
    je .err
    mov r14d, eax

    mov rdi, CGX_NODE_BINARY
    call _allocNode
    cmp eax, -1
    je .err

    mov [rdx + ASTNode.a], r12d
    mov [rdx + ASTNode.b], r14d
    mov [rdx + ASTNode.c], r13d
    mov r12d, eax
    jmp .mulLoop

.done:
    mov eax, r12d
    jmp .ret

.err:
    mov eax, -1

.ret:
    add rsp, 32
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _parseFactor - primary with call suffixes
; Input: rdi = ParseState ptr
; Output: eax = AST node index (or -1 on error)
; --------------------------------------------
_parseFactor:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 32

    mov rbx, rdi

    call _parsePrimary
    cmp eax, -1
    je .err
    mov r12d, eax

.suffixLoop:
    call _peek
    mov ecx, [rax + Token.type]

    ; Swizzle -- '.'
    cmp ecx, CGX_TOK_DOT
    je .swizzle

    ; Call suffix -- '('
    cmp ecx, CGX_TOK_LPAREN
    je .callSuffix

    jmp .done

.swizzle:
    call _advance
    call _peek
    mov r13, rax
    mov ecx, [r13 + Token.type]
    cmp ecx, CGX_TOK_IDENT
    jne .err

    ; Pack the swizzle mask
    ; rcx = ptr to ident, scan 1-4 chars
    mov rsi, [r13 + Token.start]
    xor r14d, r14d                  ; mask accumulator
    xor ecx, ecx                    ; component count
.swizzleLoop:
    movzx eax, byte [rsi + rcx]
    cmp al, 'x'
    je .cx
    cmp al, 'y'
    je .cy
    cmp al, 'z'
    je .cz
    cmp al, 'w'
    je .cw
    cmp al, 'r'
    je .cx
    cmp al, 'g'
    je .cy
    cmp al, 'b'
    je .cz
    cmp al, 'a'
    je .cw

    jmp .swizzleDone

.cx:
    mov edx, 0
    jmp .packComp
.cy:
    mov edx, 1
    jmp .packComp
.cz:
    mov edx, 2
    jmp .packComp
.cw:
    mov edx, 3
.packComp:
    ; Shift into position: byte offset = ecx * 4 bits
    mov rdi, rcx
    shl rdi, 3          ; 8 bits per position
    mov rdi, rdx
    shl rdi, cl         ; shift by (component index * 8)

    mov rdi, rcx
    shl rdi, 3
    mov r8, rdx
    mov rcx, rdi
    shl r8, cl
    or r14d, r8
    inc rcx
    cmp ecx, 4
    jl .swizzleLoop

.swizzleDone:
    call _advance

    ; MEMBER node: a = base, b = mask
    mov rdi, CGX_NODE_MEMBER
    call _allocNode
    cmp eax, -1
    je .err

    mov [rdx + ASTNode.a], r12d
    mov [rdx + ASTNode.b], r14d
    mov r12d, eax
    jmp .suffixLoop

.callSuffix:
    call _advance
    mov rdi, rbx

    call _parseArgsPlaceholder

    mov rdi, CGX_NODE_CALL
    call _allocNode
    cmp eax, -1
    je .err
    mov [rdx + ASTNode.a], r12d
    mov dword [rdx + ASTNode.b], 0
    mov r12d, eax
    jmp .suffixLoop

.done:
    mov eax, r12d
    jmp .ret

.err:
    mov eax, -1

.ret:
    add rsp, 32
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _placeArgsPlaceholder
; Stub -- parses 'expr (, expr)*' and discards, return 1
; Input: rdi = ParseState ptr
; Output: eax = 1 on success
; --------------------------------------------
_parseArgsPlacehodler:
    