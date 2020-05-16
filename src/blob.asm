; hardware.inc
INCLUDE "hardware.inc"

; project libs
INCLUDE "actor.inc"
INCLUDE "controller.inc"
INCLUDE "display.inc"
INCLUDE "kernel.inc"
INCLUDE "oam.inc"

SECTION "Blob Code", ROM0

; Public interface for Blob
RSRESET
BLOB_ACTOR RB ACTOR_SIZE
BLOB_SPRITE RB SPRITE_SIZE
BLOB_VECTORS RB 1
BLOB_START_X RB 1
BLOB_START_Y RB 1
BLOB_START_VECTORS RB 1
BLOB_SIZE RB 0

RSRESET
FRAME_INTERVAL RB 1
FRAME_NEXT_REEL RB 0
FRAME_TILE_SRC RW 1
FRAME_SPRITE_FLAGS RB 1
FRAME_SIZE RB 0

REEL_SENTINEL EQU 0

REEL_JUMP: MACRO
	db REEL_SENTINEL
	dw \1

	ENDM

REEL_CLIP: MACRO
	db \1
	dw \2 + (\3 * SIZEOF_TILE)
	db \4

	ENDM

; Flags for BLOB_VECTORS
BLOB_VECTOR_Y EQU 0
BLOB_VECTOR_X EQU 1

; Constants for Blob dimensions
BLOB_W EQU 8
BLOB_H EQU 8

SIZEOF_TILE EQU 16

BLOB_MASS_H EQU 1
BLOB_MASS_W EQU 1
BLOB_MASS EQU (BLOB_MASS_H * BLOB_MASS_W)

BLOB_TYPE::
	dw Blob_Update
	dw Blob_Animate
	;dw Blob_VramSetup
	;dw Blob_updateAttributes

BLOB_SHEET:
INCBIN "blob.2bpp"
BLOB_SHEET_END:
BLOB_SHEET_SIZE EQU BLOB_SHEET_END-BLOB_SHEET

RSRESET
BLOB_FACE_DOWN RW 1
BLOB_FACE_LEFT RW 0
BLOB_FACE_RIGHT RW 1
BLOB_FACE_UP RW 1

BLOB_REEL_UP:
	REEL_CLIP 16, BLOB_SHEET, (BLOB_FACE_UP + 1), 0
	REEL_CLIP 16, BLOB_SHEET, BLOB_FACE_UP, 0
	REEL_JUMP BLOB_REEL_UP

BLOB_REEL_DOWN:
	REEL_CLIP 16, BLOB_SHEET, BLOB_FACE_DOWN + 1, 0
	REEL_CLIP 16, BLOB_SHEET, BLOB_FACE_DOWN, 0
	REEL_JUMP BLOB_REEL_DOWN

BLOB_REEL_LEFT:
	REEL_CLIP 16, BLOB_SHEET, (BLOB_FACE_LEFT + 1), OAMF_XFLIP
	REEL_CLIP 16, BLOB_SHEET, BLOB_FACE_LEFT, OAMF_XFLIP
	REEL_JUMP BLOB_REEL_LEFT

BLOB_REEL_RIGHT:
	REEL_CLIP 16, BLOB_SHEET, (BLOB_FACE_LEFT + 1), 0
	REEL_CLIP 16, BLOB_SHEET, BLOB_FACE_LEFT, 0
	REEL_JUMP BLOB_REEL_RIGHT

Blob_Animate:
; Animate Pipeline Method for Blob type
; bc <~> This

	; If Interval is 0 we pick the nextFrame
	MEMBER_ADDRESS (BLOB_SPRITE + SPRITE_INTERVAL)
	dec [hl]
	jr z, .nextFrame

	jp .updateOffset

.nextFrame
; When the Interval has elapsed we load increment the frame.

	MEMBER_ADDRESS (BLOB_SPRITE + SPRITE_STATUS)
	set SPRITE_FLAG_UPDATED, [hl]

	; Put next Frame in BC
	MEMBER_PEEK_WORD (BLOB_SPRITE + SPRITE_FRAME)
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
	MEMBER_POKE_WORD (BLOB_SPRITE + SPRITE_FRAME)

	; Set Animation Interval
	MEMBER_POKE_BYTE (BLOB_SPRITE + SPRITE_INTERVAL)

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
	MEMBER_POKE_WORD (BLOB_SPRITE + SPRITE_FRAME)

	; Set Animation Interval
	MEMBER_POKE_BYTE (BLOB_SPRITE + SPRITE_INTERVAL)

	jr .updateOffset

.updateOffset
; Amend the Oam Buffer's Offset

	; Preserve the Sprite Offset
	MEMBER_PEEK_WORD (BLOB_SPRITE + SPRITE_OFFSET)
	push de

	; Put offset address of Oam Buffer in HL
	MEMBER_PEEK_WORD (BLOB_SPRITE + SPRITE_OAM_BUFFER)
	ld hl, (SPRITE_OFFSET)
	add hl, de

	; Set offset of Oam Buffer
	pop de
	ld [hl], e
	inc hl
	ld [hl], d

.ifUpdated
; YIELD if Sprite does not need updated

	; Don't update VRAM if Sprite not updated
	MEMBER_ADDRESS (BLOB_SPRITE + SPRITE_STATUS)
	bit SPRITE_FLAG_UPDATED, [hl]
	jr nz, .ifBankRefresh

	YIELD

.ifBankRefresh
; YIELD if the Sprite Bank isn't on a REFRESH step

	MEMBER_PEEK_WORD (BLOB_SPRITE + SPRITE_BANK)
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
	MEMBER_PEEK_WORD (BLOB_SPRITE + SPRITE_FRAME)
	ld hl, FRAME_SPRITE_FLAGS
	add hl, de
	ld d, [hl]
	MEMBER_ADDRESS (BLOB_SPRITE + SPRITE_FLAGS)
	ld [hl], d

	; Preserve the Sprite Attributes
	MEMBER_PEEK_BYTE (BLOB_SPRITE + SPRITE_TILE)
	ld e, a
	push de

	; Get the Sprite Buffer and put it in BC
	MEMBER_PEEK_WORD (BLOB_SPRITE + SPRITE_OAM_BUFFER)
	ld b, d
	ld c, e

	; Write the Sprite Attributes to the Sprite Buffer
	pop de
	MEMBER_POKE_WORD (SPRITE_ATTRIBUTES)

	; Refresh This
	pop bc

	; Put Tile Src in DE
	MEMBER_PEEK_WORD (BLOB_SPRITE + SPRITE_FRAME)
	ld hl, FRAME_TILE_SRC
	add hl, de
	ld e, [hl]
	inc hl
	ld d, [hl]

	; Set Animation Tile Src
	MEMBER_POKE_WORD (BLOB_SPRITE + SPRITE_TILE_SRC)

.copySprite

	; Preserve This
	push bc

	; Get Tile Dst and preserve it
	MEMBER_PEEK_WORD (BLOB_SPRITE + SPRITE_TILE_DST)
	push de

	; Get the Tile Src
	MEMBER_PEEK_WORD (BLOB_SPRITE + SPRITE_TILE_SRC)

	; Refresh Tile Dst
	pop hl

	; Number of Tiles to copy
	ld bc, (SIZEOF_TILE * BLOB_MASS)

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
	MEMBER_ADDRESS (BLOB_SPRITE + SPRITE_STATUS)
	res SPRITE_FLAG_UPDATED, [hl]

	YIELD

Blob_Init::
; Setup a Blob actor
; bc <~ Address of new Blob

	; Spawn our actor
	ld bc, BLOB_SIZE
	call Actor_Spawn

	; Preserve our actor
	push bc

	; Set type
	ld de, BLOB_TYPE
	MEMBER_POKE_WORD (ACTOR_TYPE)

	; Set Sprite as updated so animates on first page
	MEMBER_ADDRESS (BLOB_SPRITE + SPRITE_STATUS)
	set SPRITE_FLAG_UPDATED, [hl]

	; Ask OAM for Sprite Buffer
	OAM_SPRITE_REQUEST (BLOB_MASS)
	MEMBER_POKE_WORD (BLOB_SPRITE + SPRITE_OAM_BUFFER)

	; Set the Tile offset and Tile Dst to tile offset in VRAM
	MEMBER_ADDRESS (BLOB_SPRITE)
	ld b, h
	ld c, l

	; Set Sprite attributes related to Sprite Request
	ld e, BLOB_MASS
	call Sprite_Request

	; Refresh our actor
	pop bc

	ret

BLOB_SPAWN: MACRO
; Create a Blob actor
; \1 ~> SPRITE_Y
; \2 ~> SPRITE_X
; \3 ~> BLOB_VECTORS
; \4 ~> REEL
; bc <~ Blob Data address
	call Blob_Init

	ld a, \1
	MEMBER_POKE_BYTE (BLOB_SPRITE + SPRITE_Y)
	MEMBER_POKE_BYTE (BLOB_START_Y)

	ld a, \2
	MEMBER_POKE_BYTE (BLOB_SPRITE + SPRITE_X)
	MEMBER_POKE_BYTE (BLOB_START_X)

	ld a, \3
	MEMBER_POKE_BYTE (BLOB_VECTORS)
	MEMBER_POKE_BYTE (BLOB_START_VECTORS)

	ld de, \4
	MEMBER_POKE_WORD (BLOB_SPRITE + SPRITE_FRAME)

	ENDM

Blob_Spawn_All::
	BLOB_SPAWN $33, $33, %00000001, BLOB_REEL_UP
	BLOB_SPAWN $55, $55, %00000011, BLOB_REEL_LEFT
	BLOB_SPAWN $77, $77, %00000010, BLOB_REEL_DOWN
	BLOB_SPAWN $11, $88, %00000000, BLOB_REEL_DOWN
	BLOB_SPAWN $34, $66, %00000001, BLOB_REEL_DOWN
	BLOB_SPAWN $54, $40, %00000011, BLOB_REEL_DOWN
	BLOB_SPAWN $74, $22, %00000010, BLOB_REEL_DOWN
	BLOB_SPAWN $24, $22, %00000010, BLOB_REEL_UP
	BLOB_SPAWN $43, $44, %00000001, BLOB_REEL_UP
	BLOB_SPAWN $64, $66, %00000011, BLOB_REEL_UP
	BLOB_SPAWN $84, $88, %00000001, BLOB_REEL_UP
	BLOB_SPAWN $24, $77, %00000010, BLOB_REEL_UP
	BLOB_SPAWN $45, $55, %00000001, BLOB_REEL_UP
	BLOB_SPAWN $65, $33, %00000001, BLOB_REEL_UP
	BLOB_SPAWN $35, $42, %00000011, BLOB_REEL_UP
	BLOB_SPAWN $11, $22, %00000001, BLOB_REEL_LEFT
	BLOB_SPAWN $35, $88, %00000010, BLOB_REEL_DOWN
	BLOB_SPAWN $88, $36, %00000000, BLOB_REEL_DOWN
	BLOB_SPAWN $21, $13, %00000001, BLOB_REEL_DOWN
	BLOB_SPAWN $91, $94, %00000011, BLOB_REEL_DOWN
	BLOB_SPAWN $12, $34, %00000010, BLOB_REEL_DOWN
	BLOB_SPAWN $56, $78, %00000010, BLOB_REEL_UP
	BLOB_SPAWN $23, $45, %00000001, BLOB_REEL_UP
	BLOB_SPAWN $67, $89, %00000011, BLOB_REEL_UP
	BLOB_SPAWN $01, $23, %00000001, BLOB_REEL_UP
	BLOB_SPAWN $45, $67, %00000010, BLOB_REEL_UP
	BLOB_SPAWN $89, $01, %00000001, BLOB_REEL_UP
	BLOB_SPAWN $C0, $CC, %00000001, BLOB_REEL_UP
	BLOB_SPAWN $67, $34, %00000011, BLOB_REEL_UP
	BLOB_SPAWN $01, $01, %00000011, BLOB_REEL_UP
	BLOB_SPAWN $09, $09, %00000001, BLOB_REEL_UP
	BLOB_SPAWN $0F, $0F, %00000010, BLOB_REEL_UP
	BLOB_SPAWN $13, $13, %00000001, BLOB_REEL_UP
	BLOB_SPAWN $17, $17, %00000011, BLOB_REEL_UP
	BLOB_SPAWN $20, $20, %00000000, BLOB_REEL_UP
	BLOB_SPAWN $25, $25, %00000011, BLOB_REEL_UP
	BLOB_SPAWN $29, $29, %00000010, BLOB_REEL_UP
	BLOB_SPAWN $37, $37, %00000001, BLOB_REEL_UP
	BLOB_SPAWN $29, $29, %00000010, BLOB_REEL_UP
	BLOB_SPAWN $37, $37, %00000001, BLOB_REEL_UP

	ret

UPDATE_INTERVAL: MACRO
; de ~> Frame
	ld hl, (FRAME_INTERVAL)
	add hl, de
	ld a, [hl]
	MEMBER_POKE_BYTE (BLOB_SPRITE + SPRITE_INTERVAL)

	ENDM

Blob_Update:
; Update Pipeline Method for Blob type
; bc ~> This

	; When A is pressed the Blob's move off in their original direction
	CONTROLLER_KEY_CHANGED CONTROLLER_A, .resetVectors

	; When B is pressed the Blob's reset to their original position
	CONTROLLER_KEY_CHANGED CONTROLLER_B, .resetOffset

	jr .getFaceY

.resetVectors
	MEMBER_PEEK_BYTE (BLOB_START_VECTORS)
	MEMBER_POKE_BYTE (BLOB_VECTORS)

	jr .getFaceY

.resetOffset

	MEMBER_PEEK_BYTE (BLOB_START_Y)
	MEMBER_POKE_BYTE (BLOB_SPRITE + SPRITE_Y)

	MEMBER_PEEK_BYTE (BLOB_START_X)
	MEMBER_POKE_BYTE (BLOB_SPRITE + SPRITE_X)

	jr .getFaceY

.getFaceY
; Change the Vector and Frame if This Y collides with the edge of the display

	; Get BLOB_SPRITE + SPRITE_Y
	MEMBER_PEEK_BYTE (BLOB_SPRITE + SPRITE_Y)

	; If at top of the display faceDown
	cp DISPLAY_T
	jr z, .faceDown

	; If at bottom of the display faceUp
	cp DISPLAY_B - BLOB_H
	jr z, .faceUp

	CONTROLLER_KEY_CHANGED CONTROLLER_DOWN, .faceDown
	CONTROLLER_KEY_CHANGED CONTROLLER_UP, .faceUp

	jr .getFaceX

.faceDown
	MEMBER_BIT res, BLOB_VECTORS, BLOB_VECTOR_Y

	ld de, BLOB_REEL_DOWN
	MEMBER_POKE_WORD (BLOB_SPRITE + SPRITE_FRAME)

	UPDATE_INTERVAL

	jr .getFaceX

.faceUp
	MEMBER_BIT set, BLOB_VECTORS, BLOB_VECTOR_Y

	ld de, BLOB_REEL_UP
	MEMBER_POKE_WORD (BLOB_SPRITE + SPRITE_FRAME)

	UPDATE_INTERVAL

	jr .getFaceX

.getFaceX

	; Change the Vector and Frame if This X collides with the edge of the display
	MEMBER_PEEK_BYTE (BLOB_SPRITE + SPRITE_X)

	cp DISPLAY_L
	jr z, .faceRight

	cp DISPLAY_R
	jr z, .faceLeft

	CONTROLLER_KEY_CHANGED CONTROLLER_RIGHT, .faceRight
	CONTROLLER_KEY_CHANGED CONTROLLER_LEFT, .faceLeft

	; Yield when not colliding with edge of display
	jr .getVectorY

.faceRight
	MEMBER_BIT res, BLOB_VECTORS, BLOB_VECTOR_X

	ld de, BLOB_REEL_RIGHT
	MEMBER_POKE_WORD (BLOB_SPRITE + SPRITE_FRAME)

	UPDATE_INTERVAL

	jr .getVectorY

.faceLeft
	MEMBER_BIT set, BLOB_VECTORS, BLOB_VECTOR_X

	ld de, BLOB_REEL_LEFT
	MEMBER_POKE_WORD (BLOB_SPRITE + SPRITE_FRAME)

	jr .getVectorY

.getVectorY
; Get the Vector Y and decide to moveUp or moveDown
	MEMBER_BIT bit, BLOB_VECTORS, BLOB_VECTOR_Y
	jr nz, .moveUp
	jr .moveDown

.moveDown
	MEMBER_ADDRESS (BLOB_SPRITE + SPRITE_Y)
	inc [hl]

	jr .getVectorX

.moveUp
	MEMBER_ADDRESS (BLOB_SPRITE + SPRITE_Y)
	dec [hl]

	jr .getVectorX

.getVectorX
; Get the Vector X and decide whether to moveRight or moveLeft
	MEMBER_BIT bit, BLOB_VECTORS, BLOB_VECTOR_X
	jr z, .moveRight
	jr nz, .moveLeft

.moveLeft
	MEMBER_ADDRESS (BLOB_SPRITE + SPRITE_X)
	dec [hl]

	YIELD

.moveRight
	MEMBER_ADDRESS (BLOB_SPRITE + SPRITE_X)
	inc [hl]

	YIELD
