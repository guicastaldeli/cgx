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

; --- Timing ---
extern CGXGetTime
extern CGXGetTimeDelta

; --- Drawing ---
extern CGXSetColor
extern CGXDrawPixel
extern CGXDrawLine

; --- Buffers ---
extern CGXCreateVertexBuffer
extern CGXCreateIndexBuffer
extern CGXBindVertexBuffer
extern CGXBindIndexBuffer
extern CGXDeleteBuffer

; --- VAOs ---
extern CGXCreateVertexArray
extern CGXDeleteVertexArray
extern CGXBindVertexArray
extern CGXVertexAttribPointer
extern CGXEnableVertexAttribArray
extern CGXDisableVertexAttribArray