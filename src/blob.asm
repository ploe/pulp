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
	ld de, SPRITE_TILE
	call Kernel_MemberSetW

	jr .yield

.yield
	YIELD Blob_DrawProcess
