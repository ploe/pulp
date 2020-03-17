; hardware.inc
INCLUDE "hardware.inc"

; project libs
INCLUDE "display.inc"
INCLUDE "kernel.inc"
INCLUDE "process.inc"

SECTION "Blob Code", ROM0

; Enum for BLOB_CLIP
RSRESET
BLOB_CLIP_DOWN RW 1
BLOB_CLIP_LEFT RW 0
BLOB_CLIP_RIGHT RW 1
BLOB_CLIP_UP RW 1

; Struct for Blob
RSRESET
BLOB_SPRITE RB SPRITE_SIZE
BLOB_VECTORS RB 1
;BLOB_ANIMATION RW 1
;BLOB_FRAME RB 1
;BLOB_INTERVAL RB 1
BLOB_SIZE RB 0

; Flags for BLOB_VECTORS
BLOB_VECTOR_Y EQU %00000010
BLOB_VECTOR_X EQU %00000001

BLOB_W EQU 8
BLOB_H EQU 8

BLOB_SHEET:
INCBIN "blob.2bpp"
BLOB_SHEET_END:
BLOB_SHEET_SIZE EQU BLOB_SHEET_END-BLOB_SHEET

Blob_Init::
	; Spawn our blob process
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

	; Set the Blob Spite Y and X
	pop hl
	ld bc, PROCESS_SIZE + BLOB_SPRITE + SPRITE_START
	add hl, bc
	ld b, 16
	ld c, 100
	call Kernel_PokeW

	MEMCPY _VRAM, BLOB_SHEET, BLOB_SHEET_SIZE

	ret

Blob_DrawProcess:
	; de ~> address of Blob
 	; Set Size
	ld bc, SPRITE_SIZE

	; Set Destination
	ld hl, Oam_Request_Buffer

	; Fire Memcpy to put the data in the OAM Buffer
	call Kernel_MemCpy

	call Oam_Request

	call Display_DmaTransfer

	YIELD Blob_MoveProcess

Blob_MoveProcess:
	; de ~> address of blob
	push de

	; Put the address of BLOB_VECTORS in HL
	ld h, d
	ld l, e
	ld bc, BLOB_VECTORS
	add hl, bc

	; If BLOB_VECTOR_Y ? increment_y : decrement_y
	ld a, [hl]
	cp BLOB_VECTOR_Y
	pop hl
	push hl
	ld a, [hl]
	jr nz, .increment_y
	jr .decrement_y

.increment_y
	inc a
	jr .yield

.decrement_y
	dec a
	jr .yield

.yield
	ld [hl], a
	pop de
	YIELD Blob_UpdateProcess

Blob_UpdateProcess:
	; de ~> address of Blob

	; Switch BLOB_Y and push HL to stack
	ld h, d
	ld l, e
	push hl
	ld a, [hl]

	; Put address of BLOB_VECTORS in HL
	ld bc, BLOB_VECTORS
	add hl, bc

	; case DISPLAY_T
	cp DISPLAY_T
	jr z, .eq_display_t

	; case DISPLAY_H
	cp DISPLAY_B - BLOB_H
	jr z, .eq_display_b

	jr .skip_clip

.eq_display_t
	; Unset BLOB_VECTOR_Y in BLOB_VECTORS
	xor a
	ld [hl], a

	; Face downwards
	ld a, BLOB_CLIP_DOWN
	jr .set_clip

.eq_display_b
	; Put BLOB_VECTOR_Y in BLOB_VECTORS
	ld a, BLOB_VECTOR_Y
	ld [hl], a

	; Face upwards
	ld a, BLOB_CLIP_UP
	jr .set_clip

.set_clip
	; Set Blob Tile to Clip
	pop hl
	ld bc, SPRITE_TILE
	add hl, bc
	ld [hl], a
	jr .yield

.skip_clip
	pop hl
	jr .yield

.yield
	YIELD Blob_DrawProcess
