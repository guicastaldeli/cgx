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
extern CGXBufferSubData

; --- VAOs ---
extern CGXCreateVertexArray
extern CGXDeleteVertexArray
extern CGXBindVertexArray
extern CGXVertexAttribPointer
extern CGXEnableVertexAttribArray
extern CGXDisableVertexAttribArray

; --- Draw calls ---
extern CGXDrawElements

; --- State ---
extern CGXEnable
extern CGXDisable
extern CGXDepthFunc

; --- Matrix ---
extern CGXMatrixMode
extern CGXLoadIdentity
extern CGXPushMatrix
extern CGXPopMatrix
extern CGXLoadMatrix
extern CGXMultMatrix
extern CGXTranslate
extern CGXRotate
extern CGXScale
extern CGXPerspective
extern CGXOrtho

; --- Culling ---
extern CGXCullFace
extern CGXFrontFace

; --- Blending ---
extern CGXBlendFunc

; --- Textures ---
extern CGXGenTextures
extern CGXDeleteTextures
extern CGXBindTexture
extern CGXTexImage2D
extern CGXTexParameteri
extern CGXTexEnvi
extern CGXActiveTexture