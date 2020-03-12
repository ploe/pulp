INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "process.inc"

SECTION "Kernel WRAM Data", WRAM0
Kernel_ConsoleVersion:: db
Kernel_WaitingForVblank: db
Meh: db

SECTION "Kernel ROM0", ROM0

SUBW: MACRO
	; Subtract words subtrahend from minuend
	; \1 -> minuend
	; \2 -> subtrahend
	; result -> hl
	ld hl, \1
	ld bc, \2
	call Kernel_SubW

	ENDM

Kernel_SubW::
	; Subtract words subtrahend from minuend
	; bc -> subtrahend
	; hl -> minuend
	; result -> hl

	; Subtract word in BC from HL
	ld a, l
	sub a, c
	ld l, a
	ld a, h
	sbc a, b
	ld h, a

	ret

Kernel_PeekW::
	; Gets the value from source and pushes it to the stack
	; destination <~ hl
	; value ~> bc
	; next ~> hl

	ld b, [hl]
	inc hl
	ld c, [hl]
	inc hl

	ret

Kernel_PokeW::
	; Sets destination to value and push the next address to the stack
	; destination <~ hl
	; value <~ bc
	; next -> hl
	ld [hl], b
	inc hl
	ld [hl], c
	inc hl

	ret

Kernel_MemCpy::
; copies num number of bytes from source to destination
; bc num
; de source
; hl destination
.next_byte
	; fetch what we have in source and copy it into destination
	ld a, [de]
	ld [hli], a
	inc de
	dec bc

	; loop until num is 0
	ld a, b
	or c
	jr nz, .next_byte

	ret

Kernel_MemSet::
; for amount of bytes in size at destination set them to the value of value
; hl destination
; d value
; bc size
.next_byte
	; fetch what we have in value and set it in destination
	ld a, d
	ld [hli], a
	dec bc

	; loop until size is 0
	ld a, b
	or c
	jr nz, .next_byte

	ret

Sound_Init::
	; turn off the sound
	xor a
	ld [rNR52], a

	ret

; Struct for Sprite
RSRESET
SPRITE_START RB 0
SPRITE_Y RB 1
SPRITE_X RB 1
SPRITE_TILE RB 1
SPRITE_FLAGS RB 1
SPRITE_SIZE RB 0

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

Blob_Init:
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

	pop hl
	ld bc, PROCESS_SIZE + BLOB_SPRITE + SPRITE_START
	add hl, bc
	ld b, 16
	ld c, 100
	call Kernel_PokeW

	MEMCPY _VRAM, BLOB_SHEET, BLOB_SHEET_SIZE

	ret

Blob_DrawProcess::
	; de ~> address of Blob
 	; Set Size
	ld bc, SPRITE_SIZE

	; Set Destination
	ld hl, OAM_BUFFER

	; Fire Memcpy to put the data in the OAM Buffer
	call Kernel_MemCpy

	call Display_DmaTransfer

	YIELD Blob_MoveProcess

Blob_MoveProcess::
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

DISPLAY_T EQU 16
DISPLAY_L EQU 0
DISPLAY_R EQU 144
DISPLAY_B EQU 160

Blob_UpdateProcess::
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

Kernel_Init::
; entrypoint passes to Kernel_Init to set the system up for use

	; first value in register a is the sort of Game Boy we're running on
	ld [Kernel_ConsoleVersion], a

	; wipe RAM
	MEMSET _RAM, 0, $E000-$C000

	call Process_Init

	; set-up each of the hardware subsystems
	call Display_Init
	call Sound_Init

	call Blob_Init

	call Display_Start

	jp Kernel_Main

Kernel_Main::
; main heartbeat of the program, waits for the vblank interrupt and kicks off
; the method
.wait
	halt

	; was it a v-blank interrupt?
	ld a, [Kernel_WaitingForVblank]
	and a
	jr nz, .wait

	; set v-blank to wait again
	ld a, 1
	ld [Kernel_WaitingForVblank], a

	; Update the state of the game by calling the Pipeline functions
	call Process_PipelineDraw
	call Process_PipelineMove
	call Process_PipelineUpdate

	; and around we go again...
	jp Kernel_Main

SECTION "Kernel V-Blank Interrupt", ROM0[$40]
	; stop waiting for v-blank
	xor a
	ld [Kernel_WaitingForVblank], a

	reti
