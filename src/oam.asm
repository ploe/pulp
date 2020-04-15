INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "oam.inc"

DYNAMIC_TILE_BANK_TOTAL EQU 13
DYNAMIC_TILE_BANK_SIZE EQU (TILE_SIZE * DYNAMIC_TILE_BANK_TOTAL)

SECTION "Object Attribute Memory WRAM Data", WRAM0[$C000]
; Oam_Sprite_Buffer needs to be aligned with $XX00 as the built-in DMA reads
; from there to $XX9F
Oam_Sprite_Buffer:: ds SPRITE_SIZE * OAM_LIMIT
Oam_Sprite_Top:: dw
Dynamic_Tile_Buffer_0_Top:: db
Dynamic_Tile_Buffer_1_Top:: db
Dynamic_Tile_Buffer_0:: ds DYNAMIC_TILE_BANK_SIZE
Dynamic_Tile_Buffer_1:: ds DYNAMIC_TILE_BANK_SIZE
Oam_Blit_SP:: dw

SECTION "Object Attribute Memory VRAM Data", VRAM[_VRAM]
Dynamic_Tile_Bank_0:: ds DYNAMIC_TILE_BANK_SIZE
Dynamic_Tile_Bank_1:: ds DYNAMIC_TILE_BANK_SIZE

SECTION "Object Attribute Memory Code", ROM0

Oam_Blit_Tiles::
	; Store SP
	ld [Oam_Blit_SP], sp

	; Put the Tile Buffer in SP
	ld hl, Dynamic_Tile_Buffer_0
	ld sp, hl

	; Put the start of _VRAM in HL
	ld hl, Dynamic_Tile_Bank_0

	; Popslide Tile Buffer into VRAM
REPT DYNAMIC_TILE_BANK_SIZE / 2
	pop de
	ld a, e
	ld [hli], a
	ld a, d
	ld [hli], a
ENDR

	; Restore SP
	ld sp, Oam_Blit_SP
	pop hl
	ld sp, hl

	ret

Oam_Reset::
; Set Oam_Sprite_Top to the start of the Oam_Sprite_Buffer
	ld de, Oam_Sprite_Buffer
	POKE_WORD (Oam_Sprite_Top)

	xor a
	ld [Dynamic_Tile_Buffer_0_Top], a
	ld [Dynamic_Tile_Buffer_1_Top], a

	ret

Tile_Sizes::
	db 0
	db 16
	db 32
	db 48
	db 64
	db 80
	db 96
	db 112
	db 128
	db 144
	db 160
	db 176
	db 192
	db 208
	db 224
	db 240

Oam_Dynamic_Tile_Request::

; e  ~> Size
; a  <~ Dynamic_Tile_Buffer_0_Top Offset
; hl <~ Dynamic_Tile_Bank offset

.getBank0
	; Put Bank 0 offset in A
	ld a, [Dynamic_Tile_Buffer_0_Top]

	; Preserve Bank 0 offset in D
	ld d, a

	; If offset will fit in Bank 0, we respond
	add a, e
	cp a, DYNAMIC_TILE_BANK_TOTAL + 1

	; If so return the buffer address and the offset
	;jr nc, .getBank1
	jr nc, .panic

	jr .setBank0

.setBank0
	; Put updated value in the last Top we looked up
	ld [Dynamic_Tile_Buffer_0_Top], a

	; Return Dynamic_Tile_Buffer_0_Top
	ld a, d

	; The address of the offset and where to write it
	ld d, 0
	ld e, a

	ld hl, Tile_Sizes
	add hl, de

	ld e, [hl]

	; Get the start address of the buffer
	ld hl, Dynamic_Tile_Buffer_0
	add hl, de
	ld d, h
	ld e, l

	ret

.getBank1
	; Put Bank 1 offset in A
	ld hl, Dynamic_Tile_Buffer_1_Top
	ld a, [hl]

	; Preserve Bank 0 offset in D
	ld d, a

	; If offset will fit in Bank 1, we respond
	add a, e
	cp a, DYNAMIC_TILE_BANK_TOTAL + 1

	jr c, .setBank1

	jr .panic

.setBank1
	ret

.panic
	; If there's no room in either bank, we crash the application
	jp Kernel_Panic


Oam_Sprite_Request::
; Request Sprites from Oam_Sprite_Buffer
; hl ~> Size
; de <~ Oam_Sprite_Top

	; Preserve Size
	push hl

	; Put Oam_Sprite_Top in HL
	PEEK_WORD (Oam_Sprite_Top)

	; Refresh Size, preserve Sprite Buffer and add Oam_Sprite_Top for new Top
	pop hl
	push de
	add hl, de

	; Store new Oam_Sprite_Top
	ld d, h
	ld e, l
	POKE_WORD (Oam_Sprite_Top)

	; Return the Sprite Buffer
	pop de

	ret
