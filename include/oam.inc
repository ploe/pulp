	IF !DEF(_PULP_OAM_INC)
_PULP_OAM_INC SET 1

; Struct for Sprite
RSRESET
SPRITE_OFFSET RB 0
SPRITE_Y RB 1
SPRITE_X RB 1
SPRITE_ATTRIBUTES RB 0
SPRITE_TILE RB 1
SPRITE_FLAGS RB 1
SPRITE_OAM_OBJECT_SIZE RB 0
SPRITE_FRAME RW 1
SPRITE_INTERVAL RB 1
SPRITE_TILE_DST RW 1
SPRITE_TILE_SRC RW 1
SPRITE_DYNAMIC_TILE_BUFFER RW 1
SPRITE_OAM_BUFFER RW 1
SPRITE_SIZE RB 0

OAM_LIMIT EQU 40

TILE_SIZE EQU 16

OAM_TILE_REQUEST: MACRO
; Return offset of where Tile Buffer starts
; \1 ~> Size
; a  <~ Dynamic_Tile_Buffer_0_Top Offset

	; Put the current Dynamic_Tile_Buffer_0_Top in L and A
	;ld a, [Dynamic_Tile_Buffer_0_Top]
	ld e, a

	; Add Dynamic_Tile_Buffer_0_Top to Size, and store it
	add a, \1

	;ld [Dynamic_Tile_Buffer_0_Top], a

	; Put Dynamic_Tile_Buffer_0_Top in A
	ld a, e

	ENDM

OAM_SPRITE_REQUEST: MACRO
; Return address of Sprite Buffer starts
; \1 ~> Size
; de <~ Oam_Sprite_Top address
	ld hl, \1 * SPRITE_OAM_OBJECT_SIZE
	call Oam_Sprite_Request

	ENDM

ENDC
