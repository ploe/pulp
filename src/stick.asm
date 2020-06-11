; hardware.inc
INCLUDE "hardware.inc"

; project libs
INCLUDE "actor.inc"
INCLUDE "display.inc"
INCLUDE "kernel.inc"
INCLUDE "oam.inc"

SECTION "Stick Code", ROM0

; Public interface for Stick
RSRESET
STICK_ACTOR RB ACTOR_SIZE
STICK_SPRITE RB SPRITE_SIZE
STICK_SIZE RB 0

STICK_MASS_W EQU 1
STICK_MASS_H EQU 2
STICK_MASS EQU (STICK_MASS_H * STICK_MASS_W)

STICK_TYPE:
	dw Stick_Update
	dw Stick_Animate

Stick_Spritesheet:
INCBIN "stick.2bpp"
Stick_Spritesheet_End:
STICK_SHEET_SIZE EQU (Stick_Spritesheet_End - Stick_Spritesheet)

STICK_REEL:
	REEL_CLIP 0, Stick_Spritesheet, 0, 0
	REEL_JUMP STICK_REEL

Stick_Update:
	YIELD

Stick_Animate:
; Sets BC to Sprite and hands over to general Sprite animate function
; bc ~> This
; bc <~ Sprite

	; If Interval is 0 we pick the nextFrame
	MEMBER_ADDRESS (STICK_SPRITE)
	ld b, h
	ld c, l

	call Sprite_Set_Oam_Buffer_2x1

	YIELD

Stick_Init::
; Setup a Stick actor
; bc <~ This

	; Spawn our actor
	ld bc, STICK_SIZE
	call Actor_Spawn

	; Preserve our actor
	push bc

	; Set type
	ld de, STICK_TYPE
	MEMBER_POKE_WORD (ACTOR_TYPE)

	ld de, STICK_REEL
	MEMBER_POKE_WORD (STICK_SPRITE + SPRITE_FRAME)

	ld de, (TILE_SIZE * STICK_MASS)
	MEMBER_POKE_WORD (STICK_SPRITE + SPRITE_TOTAL_BYTES)

	; Set the Tile offset and Tile Dst to tile offset in VRAM
	MEMBER_ADDRESS (STICK_SPRITE)
	ld b, h
	ld c, l

	; Set Sprite attributes related to Sprite Request
	ld e, STICK_MASS
	call Sprite_Request

	; Refresh our actor
	pop bc

	OAM_SET (STICK_SPRITE)

	; Get Tile
	MEMBER_PEEK_BYTE (STICK_SPRITE + SPRITE_TILE)

	MEMBER_PEEK_WORD (STICK_SPRITE + SPRITE_OAM_BUFFER)

	; Load Tile in to Sprite 0
	ld hl, SPRITE_TILE
	add hl, de
	ld [hl], a

	; Load Tile in to Sprite 1
	inc a
	ld de, OAM_OBJECT_SIZE
	add hl, de
	ld [hl], a

	ld a, $33
	MEMBER_POKE_BYTE (STICK_SPRITE + SPRITE_Y)
	MEMBER_POKE_BYTE (STICK_SPRITE + SPRITE_X)

	; Set Sprite as updated so animates on first page
	MEMBER_ADDRESS (STICK_SPRITE + SPRITE_STATUS)
	set SPRITE_FLAG_UPDATED, [hl]

	ret
