; hardware.inc
INCLUDE "hardware.inc"

; project libs
INCLUDE "actor.inc"
INCLUDE "display.inc"
INCLUDE "kernel.inc"
INCLUDE "oam.inc"

INCLUDE "blob.inc"

SECTION "Blob Code", ROM0

; Flags for BLOB_VECTORS
BLOB_VECTOR_Y EQU 0
BLOB_VECTOR_X EQU 1

; Constants for Blob dimensions
BLOB_W EQU 8
BLOB_H EQU 8

BLOB_TYPE::
dw NEW_Blob_Update
dw NEW_Blob_Animate
dw NEW_Blob_VramSetup


BLOB_SHEET:
INCBIN "blob.2bpp"
BLOB_SHEET_END:
BLOB_SHEET_SIZE EQU BLOB_SHEET_END-BLOB_SHEET

RSRESET
REEL_FRAME_DURATION RB 1
REEL_NEXT RB 0
REEL_FRAME_CLIP RB 1
REEL_FRAME_SPRITESHEET RW 1
REEL_FRAME_SIZE RB 0

REEL_SENTINEL EQU 0

BLOB_REEL_DOWN::
	; Frame 1
	db 15, BLOB_CLIP_DOWN
	dw BLOB_SHEET

	; Frame 2
	db 15, BLOB_CLIP_DOWN + 1
	dw BLOB_SHEET

	; Go back to start
	db REEL_SENTINEL
	dw BLOB_REEL_DOWN

BLOB_REEL_UP::
	; Frame 1
	db 15, BLOB_CLIP_UP
	dw BLOB_SHEET

	; Frame 2
	db 15, BLOB_CLIP_UP + 1
	dw BLOB_SHEET

	; Go back to start
	db REEL_SENTINEL
	dw BLOB_REEL_UP

BLOB_REEL_LEFT::
	; Frame 1
	db 15, BLOB_CLIP_LEFT
	dw BLOB_SHEET

	; Frame 2
	db 15, BLOB_CLIP_LEFT + 1
	dw BLOB_SHEET

	; Go back to start
	db REEL_SENTINEL
	dw BLOB_REEL_LEFT

BLOB_REEL_RIGHT::
	; Frame 1
	db 15, BLOB_CLIP_RIGHT
	dw BLOB_SHEET

	; Frame 2
	db 15, BLOB_CLIP_RIGHT + 1
	dw BLOB_SHEET

	; Go back to start
	db REEL_SENTINEL
	dw BLOB_REEL_RIGHT

NEW_Blob_Animate::
; Animate Pipeline Method for Blob type
; bc ~> This

	; Put Frame in DE
	NEW_MEMBER_PEEK_WORD (BLOB_FRAME)

	; Put Interval in A
	NEW_MEMBER_PEEK_BYTE (BLOB_INTERVAL)

	; Put Frame in HL, compare Frame Duration with Interval
	ld h, d
	ld l, e
	cp a, [hl]

	; If Duration and Interval match jump to the nextFrame
	jr z, .nextFrame

	; Or just increment the Interval
	ld hl, BLOB_INTERVAL
	add hl, bc
	inc [hl]

	YIELD

.nextFrame
; Reset Interval
	xor a
	NEW_MEMBER_POKE_BYTE (BLOB_INTERVAL)

	; Get the next Frame in the Reel
	NEW_MEMBER_PEEK_BYTE (BLOB_FRAME)
	ld hl, REEL_FRAME_SIZE
	add hl, de

	; If the Duration is 0 that's REEL_SENTINEL, so jump to nextReel
	ld a, [hl]
	and a
	jr z, .nextReel

	; Otherwise we write the new Frame
	ld d, h
	ld e, l
	NEW_MEMBER_POKE_WORD (BLOB_FRAME)

	YIELD

.nextReel
; Get the Next Reel

	ld de, REEL_NEXT
	add hl, de
	ld e, [hl]
	inc hl
	ld d, [hl]

	; Put the Next Reel in Frame
	NEW_MEMBER_POKE_WORD (BLOB_FRAME)

	YIELD

NEW_Blob_Init::
; Setup a Blob actor
; bc <~ Address of new Blob

	; Spawn our actor
	ld bc, BLOB_SIZE
	call NEW_Actor_Spawn

	; Set type
	ld de, BLOB_TYPE
	NEW_MEMBER_POKE_WORD (ACTOR_TYPE)

	; Load in the SPRITE_SHEET
	MEMCPY _VRAM, BLOB_SHEET, BLOB_SHEET_SIZE

	ret

NEW_Blob_VramSetup:
; VramSetup Pipeline Method for Blob type
; bc ~> This
	push bc

	; Request Sprite Buffer and store in OAM_BUFFER and preserve it
	NEW_OAM_SPRITE_REQUEST (1)
	push de
	NEW_MEMBER_POKE_WORD (BLOB_OAM_BUFFER)

	; Get the Y and X and preserve it
	NEW_MEMBER_PEEK_WORD (BLOB_OFFSET)
	push de

	; Load the current Frame in to BC, and preserve This
	NEW_MEMBER_PEEK_WORD (BLOB_FRAME)
	ld b, d
	ld c, e

	; Put Clip in A
	NEW_MEMBER_PEEK_BYTE (REEL_FRAME_CLIP)

	; Refresh BC to Sprite Buffer and DE to Offset
	pop de
	pop bc

	; Set Tile to Clip
	NEW_MEMBER_POKE_BYTE (SPRITE_TILE)

	NEW_MEMBER_POKE_WORD (SPRITE_OFFSET)

	pop bc

	YIELD

NEW_Blob_Update:
; Update Pipeline Method for Blob type
; bc ~> This

.getVectorY
; Get the Vector Y and decide to moveUp or moveDown
	NEW_MEMBER_BIT bit, BLOB_VECTORS, BLOB_VECTOR_Y
	jr nz, .NEW_moveUp
	jr z, .NEW_moveDown

.NEW_moveDown
	MEMBER_ADDRESS (BLOB_Y)
	inc [hl]

	jr .getVectorX

.NEW_moveUp
	MEMBER_ADDRESS (BLOB_Y)
	dec [hl]

	jr .getVectorX

.getVectorX
; Get the Vector X and decide whether to moveRight or moveLeft
	NEW_MEMBER_BIT bit, BLOB_VECTORS, BLOB_VECTOR_X
	jr z, .NEW_moveRight
	jr nz, .NEW_moveLeft

.NEW_moveLeft
	MEMBER_ADDRESS (BLOB_X)
	dec [hl]

	jr .getFaceY

.NEW_moveRight
	MEMBER_ADDRESS (BLOB_X)
	inc [hl]

	jr .getFaceY

.getFaceY
; Change the Vector and Frame if This Y collides with the edge of the display
	; Get BLOB_Y
	NEW_MEMBER_PEEK_BYTE (BLOB_Y)

	; If at top of the display faceDown
	cp DISPLAY_T
	jr z, .NEW_faceDown

	; If at bottom of the display faceUp
	cp DISPLAY_B - BLOB_H
	jr z, .NEW_faceUp

	jr .getFaceX

.NEW_faceDown
	NEW_MEMBER_BIT res, BLOB_VECTORS, BLOB_VECTOR_Y

	ld de, BLOB_REEL_DOWN
	NEW_MEMBER_POKE_WORD (BLOB_FRAME)

	jr .getFaceX

.NEW_faceUp
	NEW_MEMBER_BIT set, BLOB_VECTORS, BLOB_VECTOR_Y

	ld de, BLOB_REEL_UP
	NEW_MEMBER_POKE_WORD (BLOB_FRAME)

	jr .getFaceX

.getFaceX
; Change the Vector and Frame if This X collides with the edge of the display
	NEW_MEMBER_PEEK_BYTE (BLOB_X)


	cp DISPLAY_L
	jr z, .NEW_faceRight

	cp DISPLAY_R
	jr z, .NEW_faceLeft

	; Yield when not colliding with edge of display
	YIELD

.NEW_faceRight
	NEW_MEMBER_BIT res, BLOB_VECTORS, BLOB_VECTOR_X

	ld de, BLOB_REEL_RIGHT
	NEW_MEMBER_POKE_WORD (BLOB_FRAME)

	YIELD

.NEW_faceLeft
	NEW_MEMBER_BIT set, BLOB_VECTORS, BLOB_VECTOR_X

	ld de, BLOB_REEL_LEFT
	NEW_MEMBER_POKE_WORD (BLOB_FRAME)

	YIELD
