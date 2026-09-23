; Shader-internal definitions shared across lexer/parser/compiler/VM...

; Token struc
struc Token
    .type                       resd 1
    .pos                        resd 1
    .value                      resd 1
    .pad0                       resd 1
    .text                       resq 1
endstruc

; Token type constants
CGX_TOK_EOF                     equ 0
CGX_TOK_IDENT                   equ 1
CGX_TOK_KEYWORD                 equ 2
CGX_TOK_NUMBER                  equ 3
CGX_TOK_LPAREN                  equ 4
CGX_TOK_RPAREN                  equ 5
CGX_TOK_LBRACE                  equ 6
CGX_TOK_RBRACE                  equ 7
CGX_TOK_COMMA                   equ 8
CGX_TOK_SEMICOLON               equ 9
CGX_TOK_DOT                     equ 10
CGX_TOK_ASSIGN                  equ 11
CGX_TOK_PLUS                    equ 12
CGX_TOK_MINUS                   equ 13
CGX_TOK_STAR                    equ 14
CGX_TOK_SLASH                   equ 15
CGX_TOK_PLUS_ASSIGN             equ 16
CGX_TOK_MINUS_ASSIGN            equ 17
CGX_TOK_STAR_ASSIGN             equ 18
CGX_TOK_SLASH_ASSIGN            equ 19