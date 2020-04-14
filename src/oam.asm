INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "oam.inc"


DYNAMIC_TILE_BANK_SIZE EQU (TILE_SIZE * 12)

SECTION "Object Attribute Memory WRAM Data", WRAM0[$C000]
; Oam_Sprite_Buffer needs to be aligned with $XX00 as the built-in DMA reads
; from there to $XX9F
Oam_Sprite_Buffer:: ds SPRITE_SIZE * OAM_LIMIT
Oam_Sprite_Top:: dw
Dynamic_Tile_Buffer_0:: ds DYNAMIC_TILE_BANK_SIZE
Dynamic_Tile_Buffer_0_Top:: db
Dynamic_Tile_Buffer_1:: ds DYNAMIC_TILE_BANK_SIZE
Dynamic_Tile_Buffer_1_Top:: db
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

	ret

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
