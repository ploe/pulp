; hardware.inc
INCLUDE "hardware.inc"

; project libs
INCLUDE "actor.inc"
INCLUDE "controller.inc"
INCLUDE "display.inc"
INCLUDE "kernel.inc"
INCLUDE "oam.inc"

SECTION "Daisy Code", ROM0

; Public interface for Daisy
RSRESET
DAISY_ACTOR RB ACTOR_SIZE
DAISY_SPRITE RB SPRITE_SIZE
DAISY_SIZE RB 0

DAISY_MASS_W EQU 2
DAISY_MASS_H EQU 2
DAISY_MASS EQU (DAISY_MASS_H * DAISY_MASS_W)

DAISY_TYPE:
	dw Daisy_Update
	dw Daisy_Animate

Daisy_Spritesheet:
INCBIN "daisy.2bpp"
Daisy_Spritesheet_End:
DAISY_SHEET_SIZE EQU (Daisy_Spritesheet_End - Daisy_Spritesheet)

DAISY_REEL_DOWN:
	REEL_CLIP 12, Daisy_Spritesheet, DAISY_MASS * 1, 0
	REEL_CLIP 12, Daisy_Spritesheet, 0, 0
	REEL_CLIP 12, Daisy_Spritesheet, DAISY_MASS * 1, 0
	REEL_CLIP 12, Daisy_Spritesheet, DAISY_MASS * 2, 0
	REEL_JUMP DAISY_REEL_DOWN

DAISY_REEL_UP:
	REEL_CLIP 12, Daisy_Spritesheet, DAISY_MASS * 4, 0
	REEL_CLIP 12, Daisy_Spritesheet, DAISY_MASS * 3, 0
	REEL_CLIP 12, Daisy_Spritesheet, DAISY_MASS * 4, 0
	REEL_CLIP 12, Daisy_Spritesheet, DAISY_MASS * 5, 0
	REEL_JUMP DAISY_REEL_UP

DAISY_REEL_LEFT:
	REEL_CLIP 12, Daisy_Spritesheet, DAISY_MASS * 7, 0
	REEL_CLIP 12, Daisy_Spritesheet, DAISY_MASS * 6, 0
	REEL_CLIP 12, Daisy_Spritesheet, DAISY_MASS * 7, 0
	REEL_CLIP 12, Daisy_Spritesheet, DAISY_MASS * 8, 0
	REEL_JUMP DAISY_REEL_LEFT

DAISY_REEL_RIGHT:
	REEL_CLIP 12, Daisy_Spritesheet, DAISY_MASS * 10, 0
	REEL_CLIP 12, Daisy_Spritesheet, DAISY_MASS * 9, 0
	REEL_CLIP 12, Daisy_Spritesheet, DAISY_MASS * 10, 0
	REEL_CLIP 12, Daisy_Spritesheet, DAISY_MASS * 11, 0
	REEL_JUMP DAISY_REEL_RIGHT


Daisy_Update:
	CONTROLLER_KEY_CHANGED CONTROLLER_DOWN, .faceDown
	CONTROLLER_KEY_CHANGED CONTROLLER_UP, .faceUp
	CONTROLLER_KEY_CHANGED CONTROLLER_LEFT, .faceLeft
	CONTROLLER_KEY_CHANGED CONTROLLER_RIGHT, .faceRight

	jr .moveY

.faceDown
	ld de, DAISY_REEL_DOWN

	jr .updateSprite

.faceUp
	ld de, DAISY_REEL_UP

	jr .updateSprite

.faceLeft
	ld de, DAISY_REEL_LEFT

	jr .updateSprite

.faceRight
	ld de, DAISY_REEL_RIGHT

	jr .updateSprite

.updateSprite
	MEMBER_POKE_WORD (DAISY_SPRITE + SPRITE_FRAME)

	MEMBER_BIT set, (DAISY_SPRITE + SPRITE_STATUS), SPRITE_FLAG_UPDATED

	YIELD

.moveY
	CONTROLLER_KEY_HELD CONTROLLER_DOWN, .moveDown
	CONTROLLER_KEY_HELD CONTROLLER_UP, .moveUp

	jr .moveX

.moveDown
	MEMBER_ADDRESS (DAISY_SPRITE + SPRITE_Y)
	inc [hl]

	jr .moveX

.moveUp
	MEMBER_ADDRESS (DAISY_SPRITE + SPRITE_Y)
	dec [hl]

	jr .moveX

.moveX
	CONTROLLER_KEY_HELD CONTROLLER_LEFT, .moveLeft
	CONTROLLER_KEY_HELD CONTROLLER_RIGHT, .moveRight

	YIELD

.moveLeft
	MEMBER_ADDRESS (DAISY_SPRITE + SPRITE_X)
	dec [hl]

	YIELD

.moveRight
	MEMBER_ADDRESS (DAISY_SPRITE + SPRITE_X)
	inc [hl]

	YIELD

MEMBER_TO_THIS: MACRO
; \1 ~> Member
; bc ~> This
; bc <~ This->Member
	MEMBER_ADDRESS \1

	; Put This->Member in BC
	ld c, [hl]
	inc hl
	ld b, [hl]

	ENDM

Daisy_Animate:
; Sets BC to Sprite and hands over to general Sprite animate function
; bc ~> This
; bc <~ Sprite

	; If Interval is 0 we pick the nextFrame
	MEMBER_ADDRESS (DAISY_SPRITE)
	ld b, h
	ld c, l

	call Sprite_Animate

	YIELD

DAISY_SPAWN: MACRO
	call Daisy_Init

	ld a, \1
	MEMBER_POKE_BYTE (DAISY_SPRITE + SPRITE_Y)

	ld a, \2
	MEMBER_POKE_BYTE (DAISY_SPRITE + SPRITE_X)

	ENDM

Daisy_Spawn::
	DAISY_SPAWN $33, $33
	DAISY_SPAWN $66, $66
	;DAISY_SPAWN $99, $99
	DAISY_SPAWN $33, $99

	ret

Daisy_Init::
; Setup a Daisy actor
; bc <~ This

	; Spawn our actor
	ld bc, DAISY_SIZE
	call Actor_Spawn

	; Preserve our actor
	push bc

	; Set type
	ld de, DAISY_TYPE
	MEMBER_POKE_WORD (ACTOR_TYPE)

	ld de, DAISY_REEL_DOWN
	MEMBER_POKE_WORD (DAISY_SPRITE + SPRITE_FRAME)

	ld de, Sprite_Set_Oam_Buffer_2x2
	MEMBER_POKE_WORD (DAISY_SPRITE + SPRITE_METHOD_SET_OAM)

	ld de, (TILE_SIZE * DAISY_MASS)
	MEMBER_POKE_WORD (DAISY_SPRITE + SPRITE_TOTAL_BYTES)

	; Set the Tile offset and Tile Dst to tile offset in VRAM
	MEMBER_ADDRESS (DAISY_SPRITE)
	ld b, h
	ld c, l

	; Set Sprite attributes related to Sprite Request
	ld e, DAISY_MASS
	call Sprite_Request

	; Refresh our actor
	pop bc

	OAM_SET (DAISY_SPRITE)

	; Get Tile
	MEMBER_PEEK_BYTE (DAISY_SPRITE + SPRITE_TILE)

	MEMBER_PEEK_WORD (DAISY_SPRITE + SPRITE_OAM_BUFFER)

	; Load Tile in to Sprite 0
	ld hl, SPRITE_TILE
	add hl, de
	ld [hl], a

	; Load Tile in to Sprite 1
	inc a
	ld de, OAM_OBJECT_SIZE
	add hl, de
	ld [hl], a

	; Load Tile in to Sprite 2
	inc a
	ld de, OAM_OBJECT_SIZE
	add hl, de
	ld [hl], a

	; Load Tile in to Sprite 3
	inc a
	ld de, OAM_OBJECT_SIZE
	add hl, de
	ld [hl], a

	; Set Sprite as updated so animates on first page
	MEMBER_ADDRESS (DAISY_SPRITE + SPRITE_STATUS)
	set SPRITE_FLAG_UPDATED, [hl]

	ret
