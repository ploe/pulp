INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "oam.inc"


SECTION "Object Attribute Memory WRAM Data", WRAM0[$C000]
; Oam_Sprite_Buffer needs to be aligned with $XX00 as the built-in DMA reads
; from there to $XX9F
Oam_Sprite_Buffer:: ds SPRITE_SIZE * OAM_LIMIT
Oam_Sprite_Top:: dw
Oam_Tile_Top:: dw

SECTION "Object Attribute Memory Code", ROM0

Oam_Reset::
; Set Oam_Sprite_Top to the start of the Oam_Sprite_Buffer
	ld bc, Oam_Sprite_Buffer
	POKE_WORD (Oam_Sprite_Top)

	ld bc, _VRAM
	POKE_WORD (Oam_Tile_Top)

	ret

Oam_Sprite_Request::
; Request Sprites from Oam_Sprite_Buffer
; de ~> Size
; bc <~ Oam_Sprite_Top

	; Put Oam_Sprite_Top in HL and push to stack
	PEEK_WORD (Oam_Sprite_Top)
	push bc
	ld h, b
	ld l, c

	; Get new Oam_Sprite_Top
	add hl, de

	; Load the new Oam_Sprite_Top
	ld b, h
	ld c, l
	POKE_WORD (Oam_Sprite_Top)

	; Return the Sprite buffer
	pop bc

	ret
