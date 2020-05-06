INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "oam.inc"

SECTION "Object Attribute Memory WRAM Data", WRAM0[$C000]
; Oam_Buffer needs to be aligned with $XX00 as the built-in DMA reads
; from there to $XX9F
Oam_Buffer:: ds SPRITE_OAM_OBJECT_SIZE * OAM_LIMIT
Oam_Top:: dw
Active_Sprite_Bank:: db
Sprite_Buffer_0:: ds SPRITE_BUFFER_SIZE
Sprite_Buffer_1:: ds SPRITE_BUFFER_SIZE
Oam_Blit_SP:: dw

SECTION "Object Attribute Memory VRAM Data", VRAM[_VRAM]
Sprite_Bank_0:: ds SPRITE_BANK_SIZE
Sprite_Bank_1:: ds SPRITE_BANK_SIZE

SECTION "Object Attribute Memory Code", ROM0

WORD_SIZE EQU 2

GET_ACTIVE_BANK: MACRO
; Get the next Active Bank and store it in DE

	; Get the current Active bank offset
	ld hl, Active_Sprite_Bank
	ld d, 0
	ld e, [hl]

	; Put the Active Bank Address in HL
	ld hl, \1
	add hl, de

	; Put Buffer Address in HL
	ld e, [hl]
	inc hl
	ld d, [hl]

	ENDM

Sprite_Banks:
	dw Sprite_Bank_0
	dw Sprite_Bank_1
Sprite_Banks_End:
SPRITE_BANKS_SIZE EQU Sprite_Banks_End - Sprite_Banks

Sprite_Buffers:
	dw Sprite_Buffer_0
	dw Sprite_Buffer_1
Sprite_Buffers_End:
SPRITE_BUFFERS_SIZE EQU Sprite_Buffers_End - Sprite_Buffers

Oam_Next_Sprite_Bank::
	; Increment the Active Bank
	ld a, [Active_Sprite_Bank]
	add a, WORD_SIZE

	; If we're greater or equal to Banks Size we need to reset it
	cp a, SPRITE_BANKS_SIZE
	jr c, .return

	; Reset Active Bank
	xor a

.return
	; Unset the Refresh bit on the previous Buffer
	GET_ACTIVE_BANK Sprite_Buffers
	ld hl, SPRITE_BUFFER_FLAGS
	add hl, de
	res SPRITE_BUFFER_FLAG_REFRESH, [hl]

	; Store new Active Bank
	ld [Active_Sprite_Bank], a

	; Set the REFRESH bit on the next Buffer
	GET_ACTIVE_BANK Sprite_Buffers
	ld hl, SPRITE_BUFFER_FLAGS
	add hl, de
	set SPRITE_BUFFER_FLAG_REFRESH, [hl]


	ret

Oam_Blit_Setup::
; Puts the VRAM bank and buffers in the correct registers for Oam_Blit_Tiles
; hl <~ Active Source
; de <~ Active Dest

	; Get the Active Source and preserve
	GET_ACTIVE_BANK Sprite_Buffers
	ld hl, SPRITE_BUFFER_DATA
	add hl, de
	push hl

	; Get the Active Destination and leave in DE
	GET_ACTIVE_BANK Sprite_Banks

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
REPT SPRITE_BANK_SIZE / 2
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
; Set Sprite_Top to the start of the Oam_Buffer
	ld de, Oam_Buffer
	POKE_WORD (Oam_Top)

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
; \1 ~> Sprite Buffer
; \2 ~> Label
; bc <~> Sprite
; d <~ Current offset
; a <~ Next offset
	ld a, [\1 + SPRITE_BUFFER_TOP]

	; Preserve Bank 0 offset in D
	ld d, a

	; If offset will fit in Bank 0, we respond
	add a, e
	cp a, SPRITE_BANK_TOTAL + 1

	; If not, we see if there's any space in Bank 2
	jr c, \2

	ENDM

SET_BUFFER: MACRO
; \1 ~> Sprite Buffer
; \2 ~> Sprite Offset
;	d  ~> Current offset
; a  ~> Next offset
; bc <~> Sprite
	ld [\1 + SPRITE_BUFFER_TOP], a

	; Return Sprite_Buffer_0_Top
	ld a, d

	; Then the offset of where we want to write to
	ld d, 0
	ld e, a
	ld hl, Tile_Sizes
	add hl, de
	ld e, [hl]

	; Get the start address of the Tile Dst buffer
	ld hl, (\1 + SPRITE_BUFFER_DATA)
	add hl, de
	ld d, h
	ld e, l
	MEMBER_POKE_WORD (SPRITE_TILE_DST)

	; Add the offset to the Tile so we have the correct one
	add a, \2
	MEMBER_POKE_BYTE (SPRITE_TILE)

	; Store the Sprite Buffer the Sprite is using
	ld de, \1
	MEMBER_POKE_WORD (SPRITE_BANK)


	ENDM

Sprite_Request::
; e  ~> Size
; a  <~ Sprite_Buffer_0_Top Offset
; hl <~ Sprite_Bank offset

.getBank0
	GET_BUFFER Sprite_Buffer_0, .setBuffer0
	GET_BUFFER Sprite_Buffer_1, .setBuffer1

	; If there's no room in either bank, we crash the application
	jp Kernel_Panic

.setBuffer0
	SET_BUFFER Sprite_Buffer_0, 0

	ret

.setBuffer1
	SET_BUFFER Sprite_Buffer_1, SPRITE_BANK_TOTAL

	ret

Oam_Request::
; Request Sprites from Sprite_Buffer
; hl ~> Size
; de <~ Sprite_Top

	; Preserve Size
	push hl

	; Put Oam_Top in HL
	PEEK_WORD (Oam_Top)

	; Refresh Size, preserve Oam Buffer and add Oam_Top for new Top
	pop hl
	push de
	add hl, de

	; Store new Oam_Top
	ld d, h
	ld e, l
	POKE_WORD (Oam_Top)

	; Return the Oam Buffer
	pop de

	ret
