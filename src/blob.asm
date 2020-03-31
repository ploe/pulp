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
dw Blob_MoveActor
dw Blob_DrawActor

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

Blob_PlayReel::
	; Push This to the stack
	push hl

	; get the Frame Address
	MEMBER_PEEK_WORD (BLOB_FRAME)
	push bc

	; Get the current interval and put it in B
	MEMBER_PEEK_BYTE (BLOB_INTERVAL)
	ld b, a

	; Get the Duration value from Frame address
	pop hl
	ld a, [hl]
	cp b

	; Get next frame in reel
	jr z, .next_frame

	; Otherwise just increment the interval
	pop hl
	ld de, BLOB_INTERVAL
	add hl, de
	inc [hl]

	ret

.next_frame
	; Reset interval
	pop hl
	xor a
	MEMBER_POKE_BYTE (BLOB_INTERVAL)

	; Push This to stack
	push hl

	; Put the value of BLOB_FRAME in BC
	MEMBER_PEEK_WORD (BLOB_FRAME)
	ld h, b
	ld l, c

	; Increment to next frame and load to BC
	ld de, REEL_FRAME_SIZE
	add hl, de
	ld b, h
	ld c, l

	; Pop This and store new frame
	pop hl
	MEMBER_POKE_WORD (BLOB_FRAME)

	; Load the Duration of the new frame
	ld h, b
	ld l, c
	ld a, [hl]
	and a

	; If the duration is REEL_SENTINEL we need set a new REEL
	ret nz

	; Get the address of the next reel to play and save it
	MEMBER_PEEK_WORD (REEL_NEXT)
	push bc

	; Set this->frame to the next reel
	ACTOR_GET_THIS
	pop bc
	MEMBER_POKE_WORD (BLOB_FRAME)

	ret

Blob_Init::
; Setup a Blob actor
; hl <~ Address of new Blob

	; Spawn our actor
	ld de, (BLOB_SIZE)
	call Actor_Spawn

	ld bc, BLOB_TYPE
	MEMBER_POKE_WORD (ACTOR_TYPE)

	; Put the address of Blob actor address in HL and push to stack
	PEEK_WORD (Actor_Top)
	ld h, b
	ld l, c

	; Load in the SPRITE_SHEET
	MEMCPY _VRAM, BLOB_SHEET, BLOB_SHEET_SIZE

	ret

Blob_DrawActor:
; Sets up the Blob to be rendered
	ACTOR_GET_THIS

	call Blob_PlayReel

	; Request Sprite from OAM
	OAM_SPRITE_REQUEST (1)
	push bc

	; SET OAM_BUFFER to response
	ACTOR_GET_THIS
	pop bc

	MEMBER_POKE_WORD (BLOB_OAM_BUFFER)

	MEMBER_PEEK_WORD (BLOB_OFFSET)
	push bc

	; Put the current frame in HL, push This to stack
	MEMBER_PEEK_WORD (BLOB_FRAME)
	ld h, b
	ld l, c

	; Get the CLIP
	INDEX_PEEK_BYTE (REEL_FRAME_CLIP)

	; Put address OAM_BUFFER in HL
	ACTOR_GET_THIS
	INDEX_PEEK_WORD (BLOB_OAM_BUFFER)
	ld h, b
	ld l, c

	; Set TILE to CLIP
	MEMBER_POKE_BYTE (SPRITE_TILE)

	; Set X and Y to OFFSET
	pop bc
	MEMBER_POKE_WORD (SPRITE_OFFSET)

	YIELD

moveDown:
; Static method
; hl ~> This
	MEMBER_SUCK_BYTE (BLOB_Y)
	inc a
	MEMBER_SPIT_BYTE

	ret

moveUp:
	MEMBER_SUCK_BYTE (BLOB_Y)
	dec a
	MEMBER_SPIT_BYTE

	ret

moveLeft:
	MEMBER_SUCK_BYTE (BLOB_X)
	inc a
	MEMBER_SPIT_BYTE

	ret

moveRight:
	MEMBER_SUCK_BYTE (BLOB_X)
	dec a
	MEMBER_SPIT_BYTE

	ret

Blob_MoveActor:
	ACTOR_GET_THIS

	MEMBER_BIT bit, BLOB_VECTORS, BLOB_VECTOR_Y

	call nz, moveUp
	call z, moveDown

	;MEMBER_BIT bit, BLOB_VECTORS, BLOB_VECTOR_X
	;call nz, moveRight
	;call z, moveLeft

	; Get BLOB_Y
	MEMBER_PEEK_BYTE (BLOB_Y)
	push af

	; If at top of the display faceDown
	cp DISPLAY_T
	call z, faceDown

	; If at bottom of the display faceUp
	pop af
	cp DISPLAY_B - BLOB_H
	call z, faceUp

	YIELD


faceDown:
	MEMBER_BIT res, BLOB_VECTORS, BLOB_VECTOR_Y

	ld bc, BLOB_REEL_DOWN
	MEMBER_POKE_WORD (BLOB_FRAME)

	ret

faceUp:
	MEMBER_BIT set, BLOB_VECTORS, BLOB_VECTOR_Y

	ld bc, BLOB_REEL_UP
	MEMBER_POKE_WORD (BLOB_FRAME)

	ret
