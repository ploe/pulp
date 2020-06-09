INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "oam.inc"

SECTION "Object Attribute Memory WRAM Data", WRAM0[$C000]
; Oam_Buffer needs to be aligned with $XX00 as the built-in DMA reads
; from there to $XX9F
Oam_Buffer:: ds OAM_OBJECT_SIZE * OAM_LIMIT
Oam_Top:: dw
Active_Sprite_Bank:: db
Sprite_Buffer_0:: ds SPRITE_BUFFER_SIZE
Sprite_Buffer_1:: ds SPRITE_BUFFER_SIZE
Sprite_Buffer_2:: ds SPRITE_BUFFER_SIZE
Oam_Blit_SP:: dw

SECTION "Object Attribute Memory VRAM Data", VRAM[_VRAM]
Sprite_Bank_0:: ds SPRITE_BANK_SIZE
Sprite_Bank_1:: ds SPRITE_BANK_SIZE
Sprite_Bank_2:: ds SPRITE_BANK_SIZE

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
	dw Sprite_Bank_2
Sprite_Banks_End:
SPRITE_BANKS_SIZE EQU Sprite_Banks_End - Sprite_Banks

Sprite_Buffers:
	dw Sprite_Buffer_0
	dw Sprite_Buffer_1
	dw Sprite_Buffer_2
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


GOTO_SET_OAM_BUFFER: MACRO
; Loads SPRITE_METHOD_SET_OAM and jumps to it
	MEMBER_PEEK_WORD (SPRITE_METHOD_SET_OAM)
	ld h, d
	ld l, e
	jp hl

	ENDM

Sprite_Animate::
; General purpose routine for animating Sprites
; Updates the Interval, Frame and Reel and jumps to SPRITE_METHOD_SET_OAM
; bc ~> Sprite
	MEMBER_ADDRESS (SPRITE_INTERVAL)
	dec [hl]
	jr z, .nextFrame

	GOTO_SET_OAM_BUFFER

.nextFrame
; When the Interval has elapsed we load increment the frame.

	; If we get this far mark the Sprite as updated
	MEMBER_ADDRESS (SPRITE_STATUS)
	set SPRITE_FLAG_UPDATED, [hl]

	; Put next Frame in DE
	MEMBER_PEEK_WORD (SPRITE_FRAME)
	ld hl, (FRAME_SIZE)
	add hl, de
	ld d, h
	ld e, l

	; If Interval is REEL_SENTINEL we jump to the next reel
	ld hl, FRAME_INTERVAL
	add hl, de
	ld a, [hl]
	and a
	jr z, .jumpReel

	; Set Frame
	MEMBER_POKE_WORD (SPRITE_FRAME)

	; Set Interval
	MEMBER_POKE_BYTE (SPRITE_INTERVAL)

	GOTO_SET_OAM_BUFFER

.jumpReel
; When we've passed the last Frame we jump to a new Reel.

	; Get the Next Reel and set DE to it
	ld hl, FRAME_NEXT_REEL
	add hl, de
	ld e, [hl]
	inc hl
	ld d, [hl]

	; Get Interval
	ld hl, FRAME_INTERVAL
	add hl, de
	ld a, [hl]

	; Set Frame
	MEMBER_POKE_WORD (SPRITE_FRAME)

	; Set Interval
	MEMBER_POKE_BYTE (SPRITE_INTERVAL)

	GOTO_SET_OAM_BUFFER

Sprite_Set_Oam_Buffer_2x2::
; Amend the Oam Buffer's Offset

	MEMBER_PEEK_BYTE (SPRITE_X)

	MEMBER_PEEK_WORD (SPRITE_OAM_BUFFER)
	ld hl, SPRITE_X
	add hl, de

	; Load X into Sprite 0
	ld [hl], a

	; Load X into Sprite 1
	ld de, OAM_OBJECT_SIZE
	add hl, de
	ld [hl], a

	; Increment X by 8
	add a, 8

	; Load X into Sprite 2
	ld de, OAM_OBJECT_SIZE
	add hl, de
	ld [hl], a

	; Load X into Sprite 3
	ld de, OAM_OBJECT_SIZE
	add hl, de
	ld [hl], a

	; Get X offset
	MEMBER_PEEK_BYTE (SPRITE_Y)

	MEMBER_PEEK_WORD (SPRITE_OAM_BUFFER)
	ld hl, SPRITE_Y
	add hl, de

	; Load Y into Sprite 0
	ld [hl], a

	; Load Y into Sprite 1
	add a, 8
	ld de, OAM_OBJECT_SIZE
	add hl, de
	ld [hl], a

	; Load Y into Sprite 2
	sub a, 8
	ld de, OAM_OBJECT_SIZE
	add hl, de
	ld [hl], a

	; Load Y into Sprite 3
	add a, 8
	ld de, OAM_OBJECT_SIZE
	add hl, de
	ld [hl], a

	jp Sprite_UpdateBank

Sprite_UpdateBank::
; ret if Sprite does not need updated

	; Don't update VRAM if Sprite not updated
	MEMBER_ADDRESS (SPRITE_STATUS)
	bit SPRITE_FLAG_UPDATED, [hl]
	jr nz, .ifBankRefresh

	ret

.ifBankRefresh
; ret if the Sprite Bank isn't on a REFRESH step

	MEMBER_PEEK_WORD (SPRITE_BANK)
	ld hl, SPRITE_BUFFER_FLAGS
	add hl, de
	bit SPRITE_BUFFER_FLAG_REFRESH, [hl]
	jr nz, .updateAttributes

	ret

.updateAttributes
; Update the Oam Buffer's Attributes

	; Preserve Sprite
	push bc

	; Put Sprite Flags in D
	MEMBER_PEEK_WORD (SPRITE_FRAME)
	ld hl, FRAME_SPRITE_FLAGS
	add hl, de
	ld d, [hl]
	MEMBER_ADDRESS (SPRITE_FLAGS)
	ld [hl], d

	; Preserve the Sprite Attributes
	MEMBER_PEEK_BYTE (SPRITE_TILE)
	ld e, a
	push de

	; Get the Sprite Buffer and put it in BC
	MEMBER_PEEK_WORD (SPRITE_OAM_BUFFER)
	ld b, d
	ld c, e

	; Write the Sprite Attributes to the Sprite Buffer
	pop de
	MEMBER_POKE_WORD (SPRITE_ATTRIBUTES)

	; Refresh Sprite
	pop bc

	; Put Tile Src in DE
	MEMBER_PEEK_WORD (SPRITE_FRAME)
	ld hl, FRAME_TILE_SRC
	add hl, de
	ld e, [hl]
	inc hl
	ld d, [hl]

	; Set Animation Tile Src
	MEMBER_POKE_WORD (SPRITE_TILE_SRC)

.copySprite
; Set up to copy the Sprite to the buffer

	; Preserve Sprite
	push bc

	; Get Tile Dst and preserve it
	MEMBER_PEEK_WORD (SPRITE_TILE_DST)
	push de

	; Get and preserve Total Bytes
	MEMBER_PEEK_WORD (SPRITE_TOTAL_BYTES)
	push de

	; Get the Tile Src
	MEMBER_PEEK_WORD (SPRITE_TILE_SRC)

	; Refresh Total Bytes
	pop bc

	; Refresh Tile Dst
	pop hl

.nextByte
	; Put source in to destination
	ld a, [de]
	ld [hl], a

	; Set  up for the nextByte
	inc hl
	inc de
	dec bc

	; If we have zero bytes left to copy we exit
	ld a, c
	or b
	jr nz, .nextByte

	; Refresh This
	pop bc

	; Sprite no longer needs to update
	MEMBER_ADDRESS (SPRITE_STATUS)
	res SPRITE_FLAG_UPDATED, [hl]

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
; e ~> Size
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
; e ~> Size
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
	GET_BUFFER Sprite_Buffer_2, .setBuffer2

	; If there's no room in either bank, we crash the application
	jp Kernel_Panic

.setBuffer0
	SET_BUFFER Sprite_Buffer_0, 0

	ret

.setBuffer1
	SET_BUFFER Sprite_Buffer_1, SPRITE_BANK_TOTAL

	ret

.setBuffer2
	SET_BUFFER Sprite_Buffer_2, (SPRITE_BANK_TOTAL * 2)


	ret
