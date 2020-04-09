	IF !DEF(_PULP_OAM_INC)
_PULP_OAM_INC SET 1

; Struct for Sprite
RSRESET
SPRITE_START RB 0
SPRITE_OFFSET RB 0
SPRITE_Y RB 1
SPRITE_X RB 1
SPRITE_ATTRIBUTES RB 0
SPRITE_TILE RB 1
SPRITE_FLAGS RB 1
SPRITE_SIZE RB 0

OAM_LIMIT EQU 40

TILE_SIZEOF EQU 16

OAM_TILE_REQUEST: MACRO
; Return offset of where Tile Buffer starts
; \1 ~> Size
; a  <~ Oam_Tile_Top Offset

	; Put the current Oam_Tile_Top in L and A
	ld a, [Oam_Tile_Top]
	ld e, a

	; Add Oam_Tile_Top to Size, and store it
	add a, \1

	ld [Oam_Tile_Top], a

	; Put Oam_Tile_Top in A
	ld a, e

	ENDM

OAM_SPRITE_REQUEST: MACRO
; Return address of Sprite Buffer starts
; \1 ~> Size
; de <~ Oam_Sprite_Top address
	ld hl, \1 * SPRITE_SIZE
	call Oam_Sprite_Request

	ENDM

ENDC
