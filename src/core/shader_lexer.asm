; ============================================
; core/shader_lexer.asm
; GLSL tokenizer
; ============================================

default rel

%include "constants.inc"
%include "structs.inc"
%include "shader.inc"

extern _cgxCoreState
extern CGXState

global _cgxCoreLexerTokenize

section .text

; --------------------------------------------
; _cgxCoreLexerTokenize
; Input: rcx = source string ptr (null-terminated)
;       rdx = pointer to output Token array
;       r8d = max tokens
; Output: eax = number of tokens written (including EOF)
;       0 on error
; Clobbers: most registers (caller-saved only)
; Preserves: rbx, r12-r15, rbp
; --------------------------------------------
_cgxCoreLexerTokenize:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 64
    mov [rbp - 8], rcx

    mov r12, rcx        ; source ptr (current position)
    mov r13, rdx        ; output token array
    mov r14d, r8d       ; max tokens
    xor r15d, r15d      ; token count

    ; Check bounds
    test r14d, r14d
    jz .fail

.tokenLoop:
    ; Skip whitespace and comments
    call _skip

    ; Check for end of source
    movzx eax, byte [r12]
    test al, al
    jz .emitEOF

    ; Check max tokens (leave room for EOF)
    mov eax, r14d
    dec eax             ; max-1 before EOF
    cmp r15d, eax
    jge .fail

    ; Dispatch on the current character
    movzx eax, byte [r12]

    ; --- Identifier / keyword start? ---
    call _isIdentStart
    test al, al
    jnz .tokenIdent

    ; --- Number start? ---
    movzx eax, byte [r12]
    cmp al, '0'
    jl .notNumber
    cmp al, '9'
    jle .tokenNumber

.notNumber:
    ; Punctuation
    movzx eax, byte [r12]

    cmp al, '('
    je .tokenLParen
    cmp al, ')'
    je .tokenRParen
    cmp al, '{'
    je .tokenLBrace
    cmp al, '}'
    je .tokenRBrace
    cmp al, ','
    je .tokenComma
    cmp al, ';'
    je .tokenSemicolon
    cmp al, '+'
    je .maybePlus
    cmp al, '-'
    je .maybeMinus
    cmp al, '*'
    je .maybeStar
    cmp al, '/'
    je .maybeSlash
    cmp al, '='
    je .tokenAssign

    ; Unknown char
    jmp .fail

;;;;;;;;;;
    ;
    ; Identifier / keyword
    ;
    .tokenIdent:
        ; r12 points at first char of identifier
        mov rbx, r12            ; start of identifier
    .identLoop:
        movzx eax, byte [r12]
        call _isIdentChar
        test al, al
        jz .identDone
        inc r12
        jmp .identLoop
    .identDone:
        ; rbx = start, r12 = one past end
        ; Compute length
        mov rsi, r12
        sub rsi, rbx

        ; Check if this is a keyword
        mov rcx, rbx
        mov edx, esi
        call _isKeyword
        ; al = 1 if keyword, 0 otherwise

        ; Build token
        mov edx, r15d
        imul edx, Token_size    ; token index * 16
        add rdx, r13            ; rdx = &tokens[r15]

        test al, al
        jz .identStoreIdent
        mov dword [rdx + 0], CGX_TOK_KEYWORD
        jmp .identStoreRest
    .identStoreIdent:
        mov dword [rdx + 0], CGX_TOK_IDENT
    .identStoreRest:
        mov rax, rbx
        sub rax, [rbp - 8]
        mov [rdx + 4], eax          ; pos
        mov dword [rdx + 8], 0      ; value
        mov [rdx + 16], rbx         ; text ptr

        inc r15d
        jmp .tokenLoop
;;;;;;;;;;

;;;;;;;;;;
    ;
    ; Number
    ;
    .tokenNumber:
        mov rbx, r12                ; start of number
    .numIntLoop:
        movzx eax, byte [r12]
        cmp al, '0'
        jl .numIntDone
        cmp al, '9'
        jg .numIntDone
        inc r12
        jmp .numIntLoop
    .numIntDone:
        ; Fractional part
        movzx eax, byte [r12]
        cmp al, '.'
        jne .numFracDone
        inc r12
    .numFracLoop:
        movzx eax, byte [r12]
        cmp al, '0'
        jl .numFracDone
        cmp al, '9'
        jg .numFracDone
        inc r12
        jmp .numFracLoop
    .numFracDone:
        ; Parse the number from [rbx, r12]
        ; Call _parseFloatFromText(rbx, length) -> float in xmm0

        mov rcx, rbx
        mov rdx, r12
        sub rdx, rbx
        call _parseFloatFromText
        ; xmm0 = value

        ; Store value
        mov edx, r15d
        imul edx, Token_size
        add rdx, r13

        mov dword [rdx + 0], CGX_TOK_NUMBER

        mov rax, rbx
        sub rax, [rbp - 8]
        mov [rdx + 4], eax

        movss [rdx + 8], xmm0       ; value = float bits
        
        mov qword [rdx + 16], 0     ; text unused

        inc r15d
        jmp .tokenLoop
;;;;;;;;;;

;;;;;;;;;;
    ;
    ; Punctuation tokens
    ;
    .tokenLParen:
        mov eax, CGX_TOK_LPAREN
        jmp .emitPunct
    .tokenRParen:
        mov eax, CGX_TOK_RPAREN
        jmp .emitPunct
    .tokenLBrace:
        mov eax, CGX_TOK_LBRACE
        jmp .emitPunct
    .tokenRBrace:
        mov eax, CGX_TOK_RBRACE
        jmp .emitPunct
    .tokenComma:
        mov eax, CGX_TOK_COMMA
        jmp .emitPunct
    .tokenSemicolon:
        mov eax, CGX_TOK_SEMICOLON
        jmp .emitPunct
    .tokenDot:
        mov eax, CGX_TOK_DOT
        jmp .emitPunct
    .tokenAssign:
        mov eax, CGX_TOK_ASSIGN
        jmp .emitPunct
    
    .emitPunct:
        mov edx, r15d
        imul edx, Token_size
        add rdx, r13

        mov [rdx + 0], eax

        mov rax, r12
        sub rax, [rbp - 8]
        mov [rdx + 4], eax

        mov dword [rdx + 8], 0
        mov qword [rdx + 16], 0

        inc r12
        inc r15d
        jmp .tokenLoop
;;;;;;;;;;

;;;;;;;;;;
    ;
    ; Multi-char operators
    ;
    .maybePlus:
        ; '+=' or '+'
        cmp byte [r12 + 1], '='
        jne .opPlus
        mov eax, CGX_TOK_PLUS_ASSIGN
        jmp .emit2
    .opPlus:
        mov eax, CGX_TOK_PLUS
        jmp .emitPunct
    .maybeMinus:
        cmp byte [r12 + 1], '='
        jne .opMinus
        mov eax, CGX_TOK_MINUS_ASSIGN
        jmp .emit2
    .opMinus:
        mov eax, CGX_TOK_MINUS
        jmp .emitPunct
    .maybeStar:
        cmp byte [r12 + 1], '='
        jne .opStar
        mov eax, CGX_TOK_STAR_ASSIGN
        jmp .emit2
    .opStar:
        mov eax, CGX_TOK_STAR
        jmp .emitPunct
    .maybeSlash:
        cmp byte [r12 + 1], '='
        jne .opSlash
        mov eax, CGX_TOK_SLASH_ASSIGN
        jmp .emit2
    .opSlash:
        mov eax, CGX_TOK_SLASH
        jmp .emitPunct
    .emit2:
        mov edx, r15d
        imul edx, Token_size
        add rdx, r13

        mov [rdx + 0], eax

        mov rax, r12
        sub rax, [rbp - 8]
        mov [rdx + 4], eax

        mov dword [rdx + 8], 0
        mov qword [rdx + 16], 0

        add r12, 2
        inc r15d
        jmp .tokenLoop
;;;;;;;;;;

;;;;;;;;;;
    ;
    ; EOF
    ;
    .emitEOF:
        mov edx, r15d
        imul edx, Token_size
        add rdx, r13

        mov dword [rdx + 0], CGX_TOK_EOF

        mov rax, r12
        sub rax, [rbp - 8]
        mov [rdx + 4], eax

        mov dword [rdx + 8], 0
        mov qword [rdx + 16], 0

        inc r15d
        mov eax, r15d
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
;;;;;;;;;;

; --------------------------------------------
; _skip
; Advances r12 past whitespace,
; line comments,
; and /* */ block comments
; Clobbers: eax
; --------------------------------------------
_skip:
.loop:
    movzx eax, byte [r12]

    ; End of string
    test al, al
    jz .done

    ; Space, tab, newline, CR
    cmp al, ' '
    je .advance
    cmp al, 9
    je .advance
    cmp al, 10
    je .advance
    cmp al, 13
    je .advance

    ; Line comment: //
    cmp al, '/'
    jne .done
    cmp byte [r12 + 1], '/'
    je .lineComment
    cmp byte [r12 + 1], '*'
    je .blockComment
    jmp .done

.advance:
    inc r12
    jmp .loop
.lineComment:
    add r12, 2
.lcLoop:
    movzx eax, byte [r12]
    test al, al
    jz .done
    cmp al, 10
    je .lcEnd
    inc r12
    jmp .lcLoop
.lcEnd:
    inc r12
    jmp .loop
.blockComment:
    add r12, 2
.bcLoop:
    movzx eax, byte [r12]
    test al, al
    jz .done
    cmp al, '*'
    jne .bcAdvance
    cmp byte [r12 + 1], '/'
    je .bcEnd
.bcAdvance:
    inc r12
    jmp .bcLoop
.bcEnd:
    add r12, 2
    jmp .loop

.done:
    ret

; --------------------------------------------
; _isIdentStart
; Input: al = char
; Output: al = 1 if [a-zA-Z_], else 0
; --------------------------------------------
_isIdentStart:
    ; a-z
    cmp al, 'a'
    jl .tryUpper
    cmp al, 'z'
    jle .yes

.tryUpper:
    cmp al, 'A'
    jl .tryUnderscore
    cmp al, 'Z'
    jle .yes
.tryUnderscore:
    cmp al, '_'
    je .yes
    xor al, al
    ret

.yes:
    mov al, 1
    ret

; --------------------------------------------
; _isIdentChar
; Input: al = char
; Output: al = 1 if identifier char, else 0
; --------------------------------------------
_isIdentChar:
    ; digit
    cmp al, '0'
    jl .notDigit
    cmp al, '9'
    jle .yes

.notDigit:
    jmp _isIdentStart

.yes:
    mov al, 1
    ret

; --------------------------------------------
; _isKeyword
; Input: rcx = ptr to identifier in source, edx = length
; Output: al = 1 if keyword
; Uses: stack-scratch buffer for comparison
; --------------------------------------------
_isKeyword:
    ; Copy identifier to a scratch buffer, null-terminate, compare with table
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 40

    mov rbx, rcx        ; source ptr
    mov r12d, edx       ; length

    ; Reject lengths > 15
    cmp r12d, 15
    jg .no

    ; Copy to scratch
    lea rdi, [rbp - 48]
    mov rcx, r12
    mov rsi, rbx
    rep movsb
    mov byte [rdi], 0

    ; Now compare with keyword table
    lea r13, [rel _keywordTable]
    
.kwLoop:
    mov rcx, [r13]          ; ptr to keyword string
    test rcx, rcx
    jz .no                  ; end of table

    ; Compare strings
    lea rsi, [rbp - 48]
.kwCmp:
    mov al, [rsi]
    mov dl, [rcx]
    cmp al, dl
    jne .kwNext
    test al, al
    jz .yes                 ; both ended
    inc rsi
    inc rcx
    jmp .kwCmp
.kwNext:
    add r13, 8
    jmp .kwLoop

.yes:
    mov al, 1
    jmp .done
.no:
    xor al, al

.done:
    add rsp, 40
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --------------------------------------------
; _parseFloatFromText
; Input: rcx = ptr to text, rdx = length
; Output: xmm0 = float value
; --------------------------------------------
_parseFloatFromText:
    push rbx
    push r12

    mov rbx, rcx
    mov r12, rdx

    ; Integer part
    xor eax, eax        ; accumulator

.intLoop:
    test r12, r12
    jz .intDone
    movzx ecx, byte [rbx]
    cmp cl, '0'
    jl .intDone
    cmp cl, '9'
    jg .intDone
    imul eax, eax, 10
    sub ecx, '0'
    add eax, ecx
    inc rbx
    dec r12
    jmp .intLoop
.intDone:
    cvtsi2ss xmm0, eax      ; xmm0 = integer part as float

    ; Fractional part
    test r12, r12
    jz .done
    movzx ecx, byte [rbx]
    cmp cl, '.'
    jne .done
    inc rbx
    dec r12

    ; Multiplier = 0.1, 0.01, ...
    mov eax, 0x3DCCCCCD     ; 0.1f
    movd xmm1, eax
.fracLoop:
    test r12, r12
    jz .done
    movzx ecx, byte [rbx]
    cmp cl, '0'
    jl .done
    cmp cl, '9'
    jg .done

    sub ecx, '0'
    cvtsi2ss xmm3, ecx
    mulss xmm3, xmm1        ; digit * place
    addss xmm0, xmm3        ; accumulate

    ; Advance place
    mov eax, 0x3DCCCCCD
    movd xmm4, eax
    mulss xmm1, xmm4        ; place *= 0.1

    inc rbx
    dec r12
    jmp .fracLoop

.done:
    pop r12
    pop rbx
    ret

; --------------------------------------------
; _isKeywordLen (helper wrapper)
; --------------------------------------------
_isKeywordLen:
    jmp _isKeyword

section .data
    ; Keyword table: array of qword pointers, null-terminated
    _kw_attribute               db "attribute", 0
    _kw_uniform                 db "uniform", 0
    _kw_varying                 db "varying", 0
    _kw_void                    db "void", 0
    _kw_float                   db "float", 0
    _kw_vec2                    db "vec2", 0
    _kw_vec3                    db "vec3", 0
    _kw_vec4                    db "vec4", 0
    _kw_mat4                    db "mat4", 0
    _kw_int                     db "int", 0
    _kw_sampler2D               db "sampler2D", 0
    _kw_main                    db "main", 0

    align 8
    _keywordTable:
        dq _kw_attribute
        dq _kw_uniform
        dq _kw_varying
        dq _kw_void
        dq _kw_float
        dq _kw_vec2
        dq _kw_vec3
        dq _kw_vec4
        dq _kw_mat4
        dq _kw_int
        dq _kw_sampler2D
        dq _kw_main
        dq 0