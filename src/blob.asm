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
ANIMATION_FRAME_DURATION RB 1
ANIMATION_FRAME_NEXT RB 0
ANIMATION_FRAME_CLIP RB 1
ANIMATION_FRAME_OAM_FLAGS RB 1
ANIMATION_FRAME_SPRITESHEET RW 1
ANIMATION_FRAME_SIZE RB 0

ANIMATION_END EQU 0

Blob_DownAnimation::
	; Frame 1
	db 60, 0, 0
	dw BLOB_SHEET

	; Frame 2
	db 60, 1, 0
	dw BLOB_SHEET

	; Go back to start
	db ANIMATION_END
;	db HIGH(Blob_DownAnimation), LOW(Blob_DownAnimation)
	dw Blob_DownAnimation
;	db 8, 8, 8

Blob_NewDraw::
	; Push This to the stack
	call Process_GetThisData
	push hl

	; get the Frame Address
	MEMBER_GET_W BLOB_FRAME
	push bc

	; Get the current interval and put it in B
	MEMBER_GET_B BLOB_INTERVAL
	ld b, a

	; Get the Duration value from Frame address
	pop hl
	ld a, [hl]
	cp b

	; Play next frame
	jr z, .next_frame

	; Otherwise just increment the interval
	jr .inc_interval

.next_frame
	; Reset interval
	pop hl
	xor a
	ld de, BLOB_INTERVAL
	call Kernel_MemberSetB

	; Push This to stack
	push hl

	; Put the value of BLOB_FRAME in BC
	MEMBER_GET_W BLOB_FRAME
	ld h, b
	ld l, c

	; Increment to next frame and load to BC
	ld de, ANIMATION_FRAME_SIZE
	add hl, de
	ld b, h
	ld c, l

	; Pop This and store new animation Frame
	pop hl
	ld de, BLOB_FRAME
	call Kernel_MemberSetW

	; Load the Duration of the new frame
	ld h, b
	ld l, c
	ld a, [hl]
	and a

	; If the duration isn't zero we don't need to pick a new frame
	ret nz

	MEMBER_GET_W ANIMATION_FRAME_NEXT

.lock

	jr .lock

	ret

.inc_interval
	pop hl
	ld de, BLOB_INTERVAL
	add hl, de

	inc [hl]

	ret

Blob_Init::
; Setup a Blob process
; hl <~ Address of new Blob

	; Allocate our process
	ld de, BLOB_SIZE + PROCESS_SIZE
	call Process_Alloc

	; Put the address of Blob process address in HL and push to stack
	ld hl, Process_Top
	call Kernel_PeekW
	ld h, b
	ld l, c
	push hl

	; Set the Method for the Blob process to Blob_DrawProcess
	ld bc, Blob_DrawProcess
	call Kernel_PokeW

	; Load in the SPRITE_SHEET
	MEMCPY _VRAM, BLOB_SHEET, BLOB_SHEET_SIZE

	; Get the address of the new Blob and leave it in HL
	pop hl
	ld bc, PROCESS_SIZE
	add hl, bc

	ret

Blob_DrawProcess:
; Draw a Blob
; de ~> address of Blob
 	; Set Size
	call Process_GetThisData
	ld d, h
	ld e, l

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
	call Kernel_MemberSetB

	jr .yield

.yield
	call Blob_NewDraw

	YIELD Blob_DrawProcess
