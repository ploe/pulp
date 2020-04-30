INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "oam.inc"

DYNAMIC_TILE_BANK_TOTAL EQU 14
DYNAMIC_TILE_BANK_SIZE EQU (TILE_SIZE * DYNAMIC_TILE_BANK_TOTAL)

RSRESET
DYNAMIC_TILE_BUFFER_TOP RB 1
DYNAMIC_TILE_BUFFER_DATA RB DYNAMIC_TILE_BANK_SIZE
DYNAMIC_TILE_BUFFER_SIZE RB 0

SECTION "Object Attribute Memory WRAM Data", WRAM0[$C000]
; Oam_Sprite_Buffer needs to be aligned with $XX00 as the built-in DMA reads
; from there to $XX9F
Oam_Sprite_Buffer:: ds SPRITE_SIZE * OAM_LIMIT
Oam_Sprite_Top:: dw
Active_Dynamic_Tile_Bank:: db
Dynamic_Tile_Buffer_0:: ds DYNAMIC_TILE_BUFFER_SIZE
Dynamic_Tile_Buffer_1:: ds DYNAMIC_TILE_BUFFER_SIZE
Oam_Blit_SP:: dw

SECTION "Object Attribute Memory VRAM Data", VRAM[_VRAM]
Dynamic_Tile_Bank_0:: ds DYNAMIC_TILE_BANK_SIZE
Dynamic_Tile_Bank_1:: ds DYNAMIC_TILE_BANK_SIZE

SECTION "Object Attribute Memory Code", ROM0

WORD_SIZE EQU 2

GET_ACTIVE_BANK: MACRO
; Get the next Active Bank and store it in DE

	; Get the current Active bank offset
	ld hl, Active_Dynamic_Tile_Bank
	ld d, 0
	ld e, [hl]

	; Put the Active Bank Address in HL
	ld hl, \1
	add hl, de

	; If the address is 0 we reset the bank
	ld e, [hl]
	inc hl
	ld d, [hl]

	ENDM

Dynamic_Tile_Banks:
	dw Dynamic_Tile_Bank_0
	dw Dynamic_Tile_Bank_1
Dynamic_Tile_Banks_End:
DYNAMIC_TILE_BANKS_SIZE EQU Dynamic_Tile_Banks_End - Dynamic_Tile_Banks

Dynamic_Tile_Buffers:
	dw (Dynamic_Tile_Buffer_0 + DYNAMIC_TILE_BUFFER_DATA)
	dw (Dynamic_Tile_Buffer_1 + DYNAMIC_TILE_BUFFER_DATA)
Dynamic_Tile_Buffers_End:
DYNAMIC_TILE_BUFFERS_SIZE EQU Dynamic_Tile_Buffers_End - Dynamic_Tile_Buffers


Oam_Blit_Setup::
; Puts the VRAM bank and buffers in the correct registers for Oam_Blit_Tiles
; hl <~ Active Source
; de <~ Active Dest

	; Get the Active Source and preserve
	GET_ACTIVE_BANK Dynamic_Tile_Buffers
	push de

	; Get the Active Destination and leave in DE
	GET_ACTIVE_BANK Dynamic_Tile_Banks

	; Increment the Active Bank
	ld hl, Active_Dynamic_Tile_Bank
	ld a, [hl]
	add a, WORD_SIZE

	; If we're greater or equal to Banks Size we need to reset it
	cp a, DYNAMIC_TILE_BANKS_SIZE
	jr c, .return

	; Reset Active Bank
	xor a

.return
	; Store new Active Bank
	ld [hl], a

	; Put Active Source in HL
	pop hl

	ret

Oam_Blit_Tiles::
; hl ~> Active Source
; de ~> Active Dest
	; Store SP
	ld [Oam_Blit_SP], sp

	; Put the Active Source in SP
	ld sp, hl

	; Put the Active Dest in HL
	ld h, d
	ld l, e

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

GET_BUFFER: MACRO
; \1 ~> Dynamic Tile Buffer
; \2 ~> Label
; d <~ Current offset
; a <~ Next offset
	ld a, [\1 + DYNAMIC_TILE_BUFFER_TOP]

	; Preserve Bank 0 offset in D
	ld d, a

	; If offset will fit in Bank 0, we respond
	add a, e
	cp a, DYNAMIC_TILE_BANK_TOTAL + 1

	; If not, we see if there's any space in Bank 2
	jr c, \2

	ENDM

SET_BUFFER: MACRO
; \1 ~> Dynamic Tile Buffer
; \2 ~> Dynamic Tile Offset
;	d  ~> Current offset
; a  ~> Next offset
; a  <~ Current offset
; hl <~ Dynamic Tile Buffer offset
	ld [\1 + DYNAMIC_TILE_BUFFER_TOP], a

	; Return Dynamic_Tile_Buffer_0_Top
	ld a, d

	; Then the offset of where we want to write to
	ld d, 0
	ld e, a
	ld hl, Tile_Sizes
	add hl, de
	ld e, [hl]

	; Get the start address of the buffer
	ld hl, (\1 + DYNAMIC_TILE_BUFFER_DATA)
	add hl, de
	ld d, h
	ld e, l

	; Add the offset to the Tile so we have the correct one
	add a, \2

	ENDM

Oam_Dynamic_Tile_Request::

; e  ~> Size
; a  <~ Dynamic_Tile_Buffer_0_Top Offset
; hl <~ Dynamic_Tile_Bank offset

.getBank0
	GET_BUFFER Dynamic_Tile_Buffer_0, .setBuffer0
	GET_BUFFER Dynamic_Tile_Buffer_1, .setBuffer1

	; If there's no room in either bank, we crash the application
	jp Kernel_Panic

.setBuffer0
	SET_BUFFER Dynamic_Tile_Buffer_0, 0

	ret

.setBuffer1
	SET_BUFFER Dynamic_Tile_Buffer_1, DYNAMIC_TILE_BANK_TOTAL

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
