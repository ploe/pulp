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

DAISY_REEL:
	REEL_CLIP 16, Daisy_Spritesheet, DAISY_MASS * 1, 0
	REEL_CLIP 16, Daisy_Spritesheet, 0, 0
	REEL_CLIP 16, Daisy_Spritesheet, DAISY_MASS * 1, 0
	REEL_CLIP 16, Daisy_Spritesheet, DAISY_MASS * 2, 0
	REEL_JUMP DAISY_REEL

Daisy_Update:

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

	ld de, DAISY_REEL
	MEMBER_POKE_WORD (DAISY_SPRITE + SPRITE_FRAME)

	; Ask OAM for Sprite Buffer
	OAM_SPRITE_REQUEST (DAISY_MASS)
	MEMBER_POKE_WORD (DAISY_SPRITE + SPRITE_OAM_BUFFER)

	; Set the Tile offset and Tile Dst to tile offset in VRAM
	MEMBER_ADDRESS (DAISY_SPRITE)
	ld b, h
	ld c, l

	; Set Sprite attributes related to Sprite Request
	ld e, DAISY_MASS
	call Sprite_Request

	; Refresh our actor
	pop bc

	ret
