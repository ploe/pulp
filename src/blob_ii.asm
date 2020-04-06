; hardware.inc
INCLUDE "hardware.inc"

; project libs
INCLUDE "actor.inc"
INCLUDE "display.inc"
INCLUDE "kernel.inc"
INCLUDE "oam.inc"

SECTION "Blob II Code", ROM0

; Public interface for Blob
RSRESET
BLOB_II_ACTOR RB ACTOR_SIZE
BLOB_II_SPRITE RB SPRITE_SIZE
BLOB_II_OAM_BUFFER RW 1
BLOB_II_VECTORS RB 1
BLOB_II_FRAME RW 1
BLOB_II_INTERVAL RB 1
BLOB_II_SIZE RB 0

RSRESET
FRAME_DURATION RB 1
REEL_NEXT RB 0
FRAME_SPRITE RW 1
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
	REEL_CLIP 100, BLOB_SHEET, 0
	REEL_CLIP 100, BLOB_SHEET, (1 * BLOB_II_MASS)
	REEL_JUMP BLOB_II_REEL_DOWN

Blob_Animate:
	; Preserve This
	push bc

	; Put Interval in A
	MEMBER_PEEK_BYTE (BLOB_II_INTERVAL)

	; Get the Frame
	MEMBER_PEEK_WORD (BLOB_II_FRAME)
	ld b, d
	ld c, e

	; If Interval == Duration then nextFrame
	MEMBER_ADDRESS (FRAME_DURATION)
	cp a, [hl]
	jr z, .nextFrame

	; Refresh This and increment Interval
	pop bc
	MEMBER_ADDRESS (BLOB_II_INTERVAL)
	inc [hl]

	YIELD

.nextFrame
	; Increment the Frame
	ld hl, FRAME_SIZE
	add hl, bc

	; Put new Frame in BC and check to see we're at the end (0 Duration)
	ld b, h
	ld c, l
	MEMBER_PEEK_BYTE (FRAME_DURATION)
	and a
	jr z, .jumpReel

	; Put the new Frame in This
	ld d, b
	ld e, c
	pop bc
	MEMBER_POKE_WORD (BLOB_II_FRAME)

	jr .resetInterval

.jumpReel
	; Set the Frame to the next start of the next reel
	MEMBER_PEEK_WORD (REEL_NEXT)
	pop bc
	MEMBER_POKE_WORD (BLOB_II_FRAME)

.resetInterval
	xor a
	MEMBER_POKE_BYTE (BLOB_II_INTERVAL)

	YIELD

Blob_VramWrite:
Blob_VramSetup:
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
	MEMBER_POKE_WORD (BLOB_II_FRAME)

	;jr .getFaceX
	YIELD

.faceUp
	MEMBER_BIT set, BLOB_II_VECTORS, BLOB_II_VECTOR_Y

	ld de, BLOB_II_REEL_UP
	MEMBER_POKE_WORD (BLOB_II_FRAME)

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
	MEMBER_POKE_WORD (BLOB_II_FRAME)

	YIELD

.faceLeft
	MEMBER_BIT set, BLOB_II_VECTORS, BLOB_II_VECTOR_X

	;ld de, BLOB_II_REEL_LEFT
	MEMBER_POKE_WORD (BLOB_II_FRAME)

	YIELD
