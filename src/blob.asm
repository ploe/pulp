; hardware.inc
INCLUDE "hardware.inc"

; project libs
INCLUDE "display.inc"
INCLUDE "kernel.inc"
INCLUDE "process.inc"

INCLUDE "blob.inc"

SECTION "Blob Code", ROM0

; Flags for BLOB_VECTORS
;BLOB_VECTOR_Y EQU %00000010
BLOB_VECTOR_Y EQU 0
BLOB_VECTOR_X EQU 1

; Constants for Blob dimensions
BLOB_W EQU 8
BLOB_H EQU 8

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
	db 15, 0
	dw BLOB_SHEET

	; Frame 2
	db 15, 1
	dw BLOB_SHEET

	; Go back to start
	db REEL_SENTINEL
	dw BLOB_REEL_DOWN

Blob_PlayReel::
	; Push This to the stack
	call Process_GetThisData
	push hl

	; get the Frame Address
	MEMBER_PEEK_WORD BLOB_FRAME
	push bc

	; Get the current interval and put it in B
	MEMBER_PEEK_BYTE BLOB_INTERVAL
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
	ld de, BLOB_INTERVAL
	call Kernel_MemberPokeByte

	; Push This to stack
	push hl

	; Put the value of BLOB_FRAME in BC
	MEMBER_PEEK_WORD BLOB_FRAME
	ld h, b
	ld l, c

	; Increment to next frame and load to BC
	ld de, REEL_FRAME_SIZE
	add hl, de
	ld b, h
	ld c, l

	; Pop This and store new frame
	pop hl
	ld de, BLOB_FRAME
	call Kernel_MemberPokeWord

	; Load the Duration of the new frame
	ld h, b
	ld l, c
	ld a, [hl]
	and a

	; If the duration is REEL_SENTINEL we need set a new REEL
	ret nz

	; Get the address of the next reel to play and save it
	MEMBER_PEEK_WORD REEL_NEXT
	push bc

	; Set this->frame to the next reel
	call Process_GetThisData
	pop bc
	ld de, BLOB_FRAME
	call Kernel_MemberPokeWord

	ret


Blob_Init::
; Setup a Blob process
; hl <~ Address of new Blob

	; Allocate our process
	ld de, BLOB_SIZE + PROCESS_SIZE
	call Process_Alloc

	; Put the address of Blob process address in HL and push to stack
	ld hl, Process_Top
	call Kernel_PeekWord
	ld h, b
	ld l, c
	push hl

	; Set the Method for the Blob process to Blob_DrawProcess
	ld bc, Blob_DrawProcess
	call Kernel_PokeWord

	; Load in the SPRITE_SHEET
	MEMCPY _VRAM, BLOB_SHEET, BLOB_SHEET_SIZE

	; Get the address of the new Blob and leave it in HL
	pop hl
	ld bc, PROCESS_SIZE
	add hl, bc

	ret

Blob_DrawProcess:
	; Get This and push it to the stack
	call Process_GetThisData
	push hl

	; Put the current frame in HL
	MEMBER_PEEK_WORD BLOB_FRAME
	ld h, b
	ld l, c

	; Get the CLIP and set TILE on this
	MEMBER_PEEK_BYTE REEL_FRAME_CLIP
	pop hl
	ld de, BLOB_SPRITE + SPRITE_TILE
	call Kernel_MemberPokeByte

	; Set Source to this
	ld d, h
	ld e, l

	; Set Size
	ld bc, SPRITE_SIZE

	; Set Destination
	ld hl, Oam_Request_Buffer

	; Fire Memcpy to put the data in the OAM Buffer
	call Kernel_MemCpy

	call Oam_Request


	YIELD Blob_MoveProcess

Blob_MoveProcess:
; Move a Blob
	call Process_GetThisData

	; If BLOB_VECTOR_Y is set then move_up
	MEMBER_BIT bit, BLOB_VECTORS, BLOB_VECTOR_Y
	jr nz, .move_up

	; Otherwise move_down
	jr .move_down

.move_down
	inc [hl]
	jr .yield

.move_up
	dec [hl]
	jr .yield

.yield
	YIELD Blob_UpdateProcess

Blob_UpdateProcess:
; Update a Blob
; de ~> address of Blob

	; Switch BLOB_Y
	call Process_GetThisData
	ld a, [hl]

	; case DISPLAY_T
	cp DISPLAY_T
	jr z, .face_down

	; case DISPLAY_H
	cp DISPLAY_B - BLOB_H
	jr z, .face_up

	jr .yield

.face_down
	; Unset BLOB_VECTOR_Y in BLOB_VECTORS
	MEMBER_BIT res, BLOB_VECTORS, BLOB_VECTOR_Y

	; Face downwards
	ld a, BLOB_CLIP_DOWN
	jr .set_clip

.face_up
	; Put BLOB_VECTOR_Y in BLOB_VECTORS
	MEMBER_BIT set, BLOB_VECTORS, BLOB_VECTOR_Y

	; Face upwards
	ld a, BLOB_CLIP_UP
	jr .set_clip

.set_clip
	; Set Blob Tile to Clip
	ld de, BLOB_SPRITE + SPRITE_TILE
	call Kernel_MemberPokeByte

	jr .yield

.yield
	call Blob_PlayReel

	YIELD Blob_DrawProcess
