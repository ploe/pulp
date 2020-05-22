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
; bc <~> This
	; If Interval is 0 we pick the nextFrame
	MEMBER_ADDRESS (DAISY_SPRITE + SPRITE_INTERVAL)
	dec [hl]
	jr z, .nextFrame

	jp .updateOffset

.nextFrame
; When the Interval has elapsed we load increment the frame.

	MEMBER_ADDRESS (DAISY_SPRITE + SPRITE_STATUS)
	set SPRITE_FLAG_UPDATED, [hl]

	; Put next Frame in BC
	MEMBER_PEEK_WORD (DAISY_SPRITE + SPRITE_FRAME)
	ld hl, FRAME_SIZE
	add hl, de
	ld b, h
	ld c, l

	; If Interval is REEL_SENTINEL we jump to the next reel
	MEMBER_PEEK_BYTE (FRAME_INTERVAL)
	and a
	jr z, .jumpReel

	; Preserve Frame address
	ld d, b
	ld e, c

	ACTOR_THIS

	; Set Frame
	MEMBER_POKE_WORD (DAISY_SPRITE + SPRITE_FRAME)

	; Set Animation Interval
	MEMBER_POKE_BYTE (DAISY_SPRITE + SPRITE_INTERVAL)

	jr .updateOffset

.jumpReel
; When we've passed the last Frame we jump to a new Reel.

	; Get the Next Reel and set BC to it
	MEMBER_PEEK_WORD (FRAME_NEXT_REEL)
	ld b, d
	ld c, e

	; Preserve Interval
	MEMBER_PEEK_BYTE (FRAME_INTERVAL)

	; Preserve Frame
	ld d, b
	ld e, c

	ACTOR_THIS

	; Set Frame
	MEMBER_POKE_WORD (DAISY_SPRITE + SPRITE_FRAME)

	; Set Animation Interval
	MEMBER_POKE_BYTE (DAISY_SPRITE + SPRITE_INTERVAL)

	jr .updateOffset

.updateOffset
; Amend the Oam Buffer's Offset

	MEMBER_PEEK_BYTE (DAISY_SPRITE + SPRITE_X)

	MEMBER_PEEK_WORD (DAISY_SPRITE + SPRITE_OAM_BUFFER)
	ld hl, SPRITE_X
	add hl, de

	; Load X into Sprite 0
	ld [hl], a

	; Load X into Sprite 1
	ld de, OAM_OBJECT_SIZE
	add hl, de
	ld [hl], a

	; Increment X by 8
	add a, 8

	; Load X into Sprite 2
	ld de, OAM_OBJECT_SIZE
	add hl, de
	ld [hl], a

	; Load X into Sprite 3
	ld de, OAM_OBJECT_SIZE
	add hl, de
	ld [hl], a

	; Get X offset
	MEMBER_PEEK_BYTE (DAISY_SPRITE + SPRITE_Y)

	MEMBER_PEEK_WORD (DAISY_SPRITE + SPRITE_OAM_BUFFER)
	ld hl, SPRITE_Y
	add hl, de

	; Load Y into Sprite 0
	ld [hl], a

	; Load Y into Sprite 1
	add a, 8
	ld de, OAM_OBJECT_SIZE
	add hl, de
	ld [hl], a

	; Load Y into Sprite 2
	sub a, 8
	ld de, OAM_OBJECT_SIZE
	add hl, de
	ld [hl], a

	; Load Y into Sprite 3
	add a, 8
	ld de, OAM_OBJECT_SIZE
	add hl, de
	ld [hl], a

.ifUpdated
; YIELD if Sprite does not need updated

	; Don't update VRAM if Sprite not updated
	MEMBER_ADDRESS (DAISY_SPRITE + SPRITE_STATUS)
	bit SPRITE_FLAG_UPDATED, [hl]
	jr nz, .ifBankRefresh

	YIELD

.ifBankRefresh
; YIELD if the Sprite Bank isn't on a REFRESH step

	MEMBER_PEEK_WORD (DAISY_SPRITE + SPRITE_BANK)
	ld hl, SPRITE_BUFFER_FLAGS
	add hl, de
	bit SPRITE_BUFFER_FLAG_REFRESH, [hl]
	jr nz, .updateAttributes

	YIELD

.updateAttributes
; Update the Oam Buffer's Attributes

	; Preserve This
	push bc

	; Put Sprite Flags in D
	MEMBER_PEEK_WORD (DAISY_SPRITE + SPRITE_FRAME)
	ld hl, FRAME_SPRITE_FLAGS
	add hl, de
	ld d, [hl]
	MEMBER_ADDRESS (DAISY_SPRITE + SPRITE_FLAGS)
	ld [hl], d

	; Preserve the Sprite Attributes
	MEMBER_PEEK_BYTE (DAISY_SPRITE + SPRITE_TILE)
	ld e, a
	push de

	; Get the Sprite Buffer and put it in BC
	MEMBER_PEEK_WORD (DAISY_SPRITE + SPRITE_OAM_BUFFER)
	ld b, d
	ld c, e

	; Write the Sprite Attributes to the Sprite Buffer
	pop de
	MEMBER_POKE_WORD (SPRITE_ATTRIBUTES)

	; Refresh This
	pop bc

	; Put Tile Src in DE
	MEMBER_PEEK_WORD (DAISY_SPRITE + SPRITE_FRAME)
	ld hl, FRAME_TILE_SRC
	add hl, de
	ld e, [hl]
	inc hl
	ld d, [hl]

	; Set Animation Tile Src
	MEMBER_POKE_WORD (DAISY_SPRITE + SPRITE_TILE_SRC)

.copySprite

	; Preserve This
	push bc

	; Get Tile Dst and preserve it
	MEMBER_PEEK_WORD (DAISY_SPRITE + SPRITE_TILE_DST)
	push de

	; Get the Tile Src
	MEMBER_PEEK_WORD (DAISY_SPRITE + SPRITE_TILE_SRC)

	; Refresh Tile Dst
	pop hl

	; Number of Tiles to copy
	ld bc, (TILE_SIZE * DAISY_MASS)

.nextByte
	; Put source in to destination
	ld a, [de]
	ld [hl], a

	; Set  up for the nextByte
	inc hl
	inc de
	dec bc

	; If we have zero bytes left to copy we exit
	ld a, c
	or b
	jr nz, .nextByte

	; Refresh This
	pop bc

	; Sprite no longer needs to update
	MEMBER_ADDRESS (DAISY_SPRITE + SPRITE_STATUS)
	res SPRITE_FLAG_UPDATED, [hl]

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
