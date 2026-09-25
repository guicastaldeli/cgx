; Shader-internal definitions shared across lexer/parser/compiler/VM...

; Token struc
struc Token
    .type                       resd 1
    .pos                        resd 1
    .value                      resd 1
    .pad0                       resd 1
    .text                       resq 1
endstruc

; AST node
struc ASTNode
    .type                       resd 1
    .a                          resd 1
    .b                          resd 1
    .c                          resd 1
    .typeId                     resd 1
    .pos                        resd 1
    .pad0                       resd 1
endstruc

; Parse State
struc ParseState
    .tokens                     resq 1
    .tokenCount                 resd 1
    .tokenIdx                   resd 1
    .shaderType                 resd 1
    .pad0                       resd 1
    .ast                        resq 1
    .astCount                   resd 1
    .astCap                     resd 1
    .symtab                     resq 1
    .errorPos                   resd 1
    .errorCode                  resd 1
    .pad1                       resd 1
endstruc

; VM instruction
struc Instr
    .op                         resd 1 ; opcode (CGX_OP_*)
    .dst                        resd 1 ; destination register (or -1)
    .srcA                       resd 1 ; source A register (or -1)
    .srcB                       resd 1 ; source B register (or -1)
    .srcC                       resd 1 ; third operand (mix, clamp) or -1
    .pad0                       resd 1
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

; AST node types
CGX_NODE_PROGRAM                equ 0
CGX_NODE_MAIN                   equ 1
CGX_NODE_DECL                   equ 2
CGX_NODE_ASSIGN                 equ 3
CGX_NODE_BINARY                 equ 4
CGX_NODE_UNARY                  equ 5
CGX_NODE_CALL                   equ 6
CGX_NODE_MEMBER                 equ 7
CGX_NODE_IDENT                  equ 8
CGX_NODE_LITERAL                equ 9