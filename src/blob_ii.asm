; hardware.inc
INCLUDE "hardware.inc"

; project libs
INCLUDE "actor.inc"
INCLUDE "display.inc"
INCLUDE "kernel.inc"
INCLUDE "oam.inc"

SECTION "Blob II Code", ROM0

RSRESET
ANIMATION_FRAME RW 1
ANIMATION_INTERVAL RB 1
ANIMATION_TILE_DST RW 1
ANIMATION_TILE_SRC RW 1
ANIMATION_SIZE RB 0

; Public interface for Blob
RSRESET
BLOB_II_ACTOR RB ACTOR_SIZE
BLOB_II_SPRITE RB SPRITE_SIZE
BLOB_II_ANIMATION RB ANIMATION_SIZE
BLOB_II_SPRITE_BUFFER RW 1
BLOB_II_VECTORS RB 1
BLOB_II_SIZE RB 0

RSRESET
FRAME_INTERVAL RB 1
FRAME_NEXT_REEL RB 0
FRAME_TILE_SRC RW 1
FRAME_SIZE RB 0

REEL_SENTINEL EQU 0

REEL_JUMP: MACRO
	db REEL_SENTINEL
	dw \1

	ENDM

REEL_CLIP: MACRO
	db \1
	dw \2 + (\3 * SIZEOF_TILE)

	ENDM

; Flags for BLOB_II_VECTORS
BLOB_II_VECTOR_Y EQU 0
BLOB_II_VECTOR_X EQU 1

; Constants for Blob dimensions
BLOB_II_W EQU 8
BLOB_II_H EQU 8

SIZEOF_TILE EQU 16

BLOB_II_MASS_H EQU 1
BLOB_II_MASS_W EQU 1
BLOB_II_MASS EQU (BLOB_II_MASS_H * BLOB_II_MASS_W)

BLOB_II_TYPE::
	dw Blob_Update
	dw Blob_Animate
	dw Blob_VramSetup
	dw Blob_VramWrite

BLOB_SHEET:
INCBIN "blob.2bpp"
BLOB_SHEET_END:
BLOB_SHEET_SIZE EQU BLOB_SHEET_END-BLOB_SHEET

BLOB_II_REEL_UP:

BLOB_II_REEL_DOWN:
	REEL_CLIP 15, BLOB_SHEET, 0
BLOB_II_REEL_DOWN_2:
	REEL_CLIP 15, BLOB_SHEET, (1 * BLOB_II_MASS)
	REEL_JUMP BLOB_II_REEL_DOWN

	ret

Blob_Animate:
; Animate Pipeline Method for Blob type
; bc <~> This

	; If Interval is 0 we pick the nextFrame
	MEMBER_ADDRESS (BLOB_II_ANIMATION + ANIMATION_INTERVAL)
	dec [hl]
	jr z, .nextFrame

	YIELD

.nextFrame
	; Put next Frame in BC
	MEMBER_PEEK_WORD (BLOB_II_ANIMATION + ANIMATION_FRAME)
	ld hl, FRAME_SIZE
	add hl, de
	ld b, h
	ld c, l

	; If Interval is REEL_SENTINEL we jump to the next reel
	MEMBER_PEEK_BYTE (FRAME_INTERVAL)
	and a
	jr z, .jumpReel

	; Preserve Interval
	push af

	; Preserve Frame Tile Src
	MEMBER_PEEK_WORD (FRAME_TILE_SRC)
	push de

	; Preserve Frame address
	push bc

	jr .setAnimation

.jumpReel
	; Get the Next Reel and set BC to it
	MEMBER_PEEK_WORD (FRAME_NEXT_REEL)
	ld b, d
	ld c, e

	; Preserve Interval
	MEMBER_PEEK_BYTE (FRAME_INTERVAL)
	push af

	; Preserve Tile Src
	MEMBER_PEEK_WORD (FRAME_TILE_SRC)
	push de

	; Preserve Frame
	push bc

	jr .setAnimation

.setAnimation
	ACTOR_THIS

	; Set Frame
	pop de
	MEMBER_POKE_WORD (BLOB_II_ANIMATION + ANIMATION_FRAME)

	; Set Animation Tile Src
	pop de
	MEMBER_POKE_WORD (BLOB_II_ANIMATION + ANIMATION_TILE_SRC)

	; Set Animation Interval
	pop af
	MEMBER_POKE_BYTE (BLOB_II_ANIMATION + ANIMATION_INTERVAL)

	YIELD

Blob_II_Init::
; Setup a Blob actor
; bc <~ Address of new Blob

	; Spawn our actor
	ld bc, BLOB_II_SIZE
	call Actor_Spawn

	; Set type
	ld de, BLOB_II_TYPE
	MEMBER_POKE_WORD (ACTOR_TYPE)

	ld de, $1111
	MEMBER_POKE_WORD (BLOB_II_SPRITE + SPRITE_OFFSET)

	ld de, BLOB_II_REEL_DOWN
	MEMBER_POKE_WORD (BLOB_II_ANIMATION + ANIMATION_FRAME)

	push bc

	MEMBER_PEEK_BYTE (BLOB_II_ANIMATION + ANIMATION_FRAME)
	ld b, d
	ld c, e

	MEMBER_PEEK_BYTE (FRAME_INTERVAL)
	MEMBER_PEEK_WORD (FRAME_TILE_SRC)

	pop bc

	MEMBER_POKE_BYTE (BLOB_II_ANIMATION + ANIMATION_INTERVAL)
	MEMBER_POKE_WORD (BLOB_II_ANIMATION + ANIMATION_TILE_SRC)

	ret

Blob_Update:
; Update Pipeline Method for Blob type
; bc ~> This

.getVectorY
; Get the Vector Y and decide to moveUp or moveDown
	MEMBER_BIT bit, BLOB_II_VECTORS, BLOB_II_VECTOR_Y
	jr nz, .moveUp
	jr .moveDown

.moveDown
	MEMBER_ADDRESS (BLOB_II_SPRITE + SPRITE_Y)
	inc [hl]

	;jr .getVectorX
	jr .getFaceY

.moveUp
	MEMBER_ADDRESS (BLOB_II_SPRITE + SPRITE_Y)
	dec [hl]

	;jr .getVectorX
	jr .getFaceY

.getVectorX
; Get the Vector X and decide whether to moveRight or moveLeft
	MEMBER_BIT bit, BLOB_II_VECTORS, BLOB_II_VECTOR_X
	jr z, .moveRight
	jr nz, .moveLeft

.moveLeft
	MEMBER_ADDRESS (BLOB_II_SPRITE + SPRITE_X)
	dec [hl]

	jr .getFaceY

.moveRight
	MEMBER_ADDRESS (BLOB_II_SPRITE + SPRITE_X)
	inc [hl]

	jr .getFaceY

.getFaceY
; Change the Vector and Frame if This Y collides with the edge of the display
	; Get BLOB_II_SPRITE + SPRITE_Y
	MEMBER_PEEK_BYTE (BLOB_II_SPRITE + SPRITE_Y)

	; If at top of the display faceDown
	cp DISPLAY_T
	jr z, .faceDown

	; If at bottom of the display faceUp
	cp DISPLAY_B - BLOB_II_H
	jr z, .faceUp

	jr .getFaceX

.faceDown
	MEMBER_BIT res, BLOB_II_VECTORS, BLOB_II_VECTOR_Y

	ld de, BLOB_II_REEL_DOWN
	MEMBER_POKE_WORD (BLOB_II_ANIMATION + ANIMATION_FRAME)

	;jr .getFaceX
	YIELD

.faceUp
	MEMBER_BIT set, BLOB_II_VECTORS, BLOB_II_VECTOR_Y

	ld de, BLOB_II_REEL_UP
	MEMBER_POKE_WORD (BLOB_II_ANIMATION + ANIMATION_FRAME)

	;jr .getFaceX
	YIELD

.getFaceX
; Change the Vector and Frame if This X collides with the edge of the display
	MEMBER_PEEK_BYTE (BLOB_II_SPRITE + SPRITE_X)


	cp DISPLAY_L
	jr z, .faceRight

	cp DISPLAY_R
	jr z, .faceLeft

	; Yield when not colliding with edge of display
	YIELD

.faceRight
	MEMBER_BIT res, BLOB_II_VECTORS, BLOB_II_VECTOR_X

	;ld de, BLOB_II_REEL_RIGHT
	MEMBER_POKE_WORD (BLOB_II_ANIMATION + ANIMATION_FRAME)

	YIELD

.faceLeft
	MEMBER_BIT set, BLOB_II_VECTORS, BLOB_II_VECTOR_X

	;ld de, BLOB_II_REEL_LEFT
	MEMBER_POKE_WORD (BLOB_II_ANIMATION + ANIMATION_FRAME)

	YIELD

Blob_VramSetup:
; VramSetup Pipeline Method for Blob type
; bc <~> This

	; Preserve This
	push bc

	; Ask OAM for Sprite Buffer
	OAM_SPRITE_REQUEST (BLOB_II_MASS)
	MEMBER_POKE_WORD (BLOB_II_SPRITE_BUFFER)

	; Ask OAM for Tile Offset
	OAM_TILE_REQUEST (BLOB_II_MASS)
	MEMBER_POKE_BYTE (BLOB_II_SPRITE + SPRITE_TILE)

	; Set the Tile Dst to tile offset in VRAM
	ld d, 0
	ld e, a
	ld hl, _VRAM
	add hl, de
	ld d, h
	ld e, l
	MEMBER_POKE_WORD (BLOB_II_ANIMATION + ANIMATION_TILE_DST)

	; Preserve the Sprite Offset
	MEMBER_PEEK_WORD (BLOB_II_SPRITE + SPRITE_OFFSET)
	push de

	; Preserve the Sprite Attributes
	MEMBER_PEEK_WORD (BLOB_II_SPRITE + SPRITE_ATTRIBUTES)
	push de

	; Get the Sprite Buffer and put it in BC
	MEMBER_PEEK_WORD (BLOB_II_SPRITE_BUFFER)
	ld b, d
	ld c, e

	; Write the Sprite Attributes to the Sprite Buffer
	pop de
	MEMBER_POKE_WORD (SPRITE_ATTRIBUTES)

	; Write the Sprite Offset to the Sprite Buffer
	pop de
	MEMBER_POKE_WORD (SPRITE_OFFSET)

	; Refresh This
	pop bc

	YIELD

Blob_VramWrite:
; VramWrite Pipeline Method for Blob type
; bc <~> This

	; Preserve This
	push bc

	; Get Tile Dst and preserve it
	MEMBER_PEEK_WORD (BLOB_II_ANIMATION + ANIMATION_TILE_DST)
	push de

	; Get the Tile Src
	MEMBER_PEEK_WORD (BLOB_II_ANIMATION + ANIMATION_TILE_SRC)

	; Refresh Tile Dst
	pop hl

	; Number of Tiles to copy
	ld bc, (SIZEOF_TILE * BLOB_II_MASS)

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

	YIELD
