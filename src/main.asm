; ============================================
; cgx.asm - CGX top-level aggregator 
; Public API surface, re-exports modules
; ============================================

default rel

; The public API is implemented in src/api/*.asm and
; src/platform/*/*.asm. This file exists as the
; top-level module so the build has a stable entry point.

section .text