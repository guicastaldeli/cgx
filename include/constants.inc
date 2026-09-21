; ============================================
; constants.inc - Public constants
; ============================================

; --- Clear Masks ---
CGX_COLOR_BIT                       equ 0x00004000
CGX_DEPTH_BIT                       equ 0x00000100

; --- Primitives ---
CGX_POINTS                          equ 0
CGX_LINES                           equ 1
CGX_TRIANGLES                       equ 2

; --- Buffer Usage Hints ---
CGX_STATIC                          equ 0
CGX_DYNAMIC                         equ 1
CGX_STREAM                          equ 2

; --- Attribute types ---
CGX_FLOAT                           equ 0
CGX_UINT                            equ 1
CGX_UBYTE                           equ 2

; --- Errors ---
CGX_OK                              equ 0
CGX_ERR_NOMEM                       equ 1
CGX_ERR_WINDOW                      equ 2
CGX_ERR_INVALID                     equ 3

; --- Virtual keys codes (subsef of Windows VK_*) ---
CGX_KEY_ESC                         equ 0x1B
CGX_KEY_SPACE                       equ 0x20
CGX_KEY_LEFT                        equ 0x25
CGX_KEY_UP                          equ 0x26
CGX_KEY_RIGHT                       equ 0x27
CGX_KEY_DOWN                        equ 0x28
CGX_KEY_0                           equ 0x30
CGX_KEY_1                           equ 0x31
CGX_KEY_2                           equ 0x32
CGX_KEY_3                           equ 0x33
CGX_KEY_4                           equ 0x34
CGX_KEY_5                           equ 0x35
CGX_KEY_6                           equ 0x36
CGX_KEY_7                           equ 0x37
CGX_KEY_8                           equ 0x38
CGX_KEY_9                           equ 0x39
CGX_KEY_A                           equ 0x41
CGX_KEY_B                           equ 0x42
CGX_KEY_C                           equ 0x43
CGX_KEY_D                           equ 0x44
CGX_KEY_E                           equ 0x45
CGX_KEY_F                           equ 0x46
CGX_KEY_G                           equ 0x47
CGX_KEY_H                           equ 0x48
CGX_KEY_I                           equ 0x49
CGX_KEY_J                           equ 0x4A
CGX_KEY_K                           equ 0x4B
CGX_KEY_L                           equ 0x4C
CGX_KEY_M                           equ 0x4D
CGX_KEY_N                           equ 0x4E
CGX_KEY_O                           equ 0x4F
CGX_KEY_P                           equ 0x50
CGX_KEY_Q                           equ 0x51
CGX_KEY_R                           equ 0x52
CGX_KEY_S                           equ 0x53
CGX_KEY_T                           equ 0x54
CGX_KEY_U                           equ 0x55
CGX_KEY_V                           equ 0x56
CGX_KEY_W                           equ 0x57
CGX_KEY_X                           equ 0x58
CGX_KEY_Y                           equ 0x59
CGX_KEY_Z                           equ 0x5A

; --- Buffers usage hints ---
CGX_STATIC                          equ 0
CGX_DYNAMIC                         equ 1
CGX_STREAM                          equ 2

; --- Buffer type ---
CGX_BUFFER_VERTEX                   equ 0
CGX_BUFFER_INDEX                    equ 1

; --- State capabilities ---
CGX_DEPTH_TEST                      equ 0
CGX_CULL_FACE                       equ 1
CGX_BLEND                           equ 2

; --- Depth comparison function ---
CGX_NEVER                           equ 0
CGX_LESS                            equ 1
CGX_EQUAL                           equ 2
CGX_LEQUAL                          equ 3
CGX_GREATER                         equ 4
CGX_NOTEQUAL                        equ 5
CGX_GEQUAL                          equ 6
CGX_ALWAYS                          equ 7

; --- Face culling modes ---
CGX_FRONT                           equ 0
CGX_BACK                            equ 1
CGX_FRONT_AND_BACK                  equ 2

; --- Matrix modes ---
CGX_MODELVIEW                       equ 0
CGX_PROJECTION                      equ 1
CGX_TEXTURE                         equ 2

; --- Winding orders ---
CGX_CW                              equ 0
CGX_CCW                             equ 1

; --- Blend factors ---
CGX_ZERO                            equ 0
CGX_ONE                             equ 1
CGX_SRC_COLOR                       equ 2
CGX_ONE_MINUS_SRC_COLOR             equ 3
CGX_SRC_ALPHA                       equ 4
CGX_ONE_MINUS_SRC_ALPHA             equ 5
CGX_DST_COLOR                       equ 6
CGX_ONE_MINUS_DST_COLOR             equ 7
CGX_DST_ALPHA                       equ 8
CGX_ONE_MINUS_DST_ALPHA             equ 9

; --- Texture targets ---
CGX_TEXTURE_2D                      equ 0x0DE1

; --- Texture units ---
CGX_TEXTURE0                        equ 0x84C0

; --- Pixel formats ---
CGX_RGBA                            equ 0x1908
CGX_RGB                             equ 0x1907

; --- Pixel types ---
CGX_UNSIGNED_BYTE                   equ 0x1401

; --- Texture parameters ---
CGX_TEXTURE_MIN_FILTER              equ 0x2801
CGX_TEXTURE_MAG_FILTER              equ 0x2800
CGX_TEXTURE_WRAP_S                  equ 0x2802
CGX_TEXTURE_WRAP_T                  equ 0x2803

; --- Filter modes ---
CGX_NEAREST                         equ 0x2600
CGX_LINEAR                          equ 0x2601
CGX_NEAREST_MIPMAP_NEAREST          equ 0x2700
CGX_LINEAR_MIPMAP_NEAREST           equ 0x2701
CGX_NEAREST_MIPMAP_LINEAR           equ 0x2702
CGX_LINEAR_MIPMAP_LINEAR            equ 0x2703

; --- Wrap modes ---
CGX_REPEAT                          equ 0x2901
CGX_CLAMP                           equ 0x2900
CGX_CLAMP_TO_EDGE                   equ 0x812F

; --- TexEnv ---
CGX_TEXTURE_ENV                     equ 0x2300
CGX_TEXTURE_ENV_MODE                equ 0x2200
CGX_MODULATE                        equ 0x2100
CGX_DECAL                           equ 0x2101
CGX_REPLACE                         equ 0x1E01