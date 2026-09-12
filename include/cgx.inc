; ============================================
; cgx.inc - Public CGX API
; Apps include this file only.
; ============================================

; --- Lifecycle ---
extern CGXInit
extern CGXShutdown

; --- Window / Events ---
extern CGXPollEvents
extern CGXShouldClose
extern CGXGetWidth
extern CGXGetHeight
extern CGXSetWindowTitle

; --- Graphics ---
extern CGXSetClearColor
extern CGXClear
extern CGXSwapBuffers

; --- Input ---
extern CGXGetKey
extern CGXGetMouseX
extern CGXGetMouseY
extern CGXGetMouseButton