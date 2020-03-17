; hardware.inc
INCLUDE "hardware.inc"

; project libs
INCLUDE "display.inc"
INCLUDE "kernel.inc"

SECTION "Display HRAM Data", HRAM[$FF80]
; the built-in DMA transfer locks up ROM, and so needs putting in HRAM
Display_DmaTransfer::

SECTION "Display WRAM Data", WRAM0[$C000]
; Oam_Sprite_Buffer needs to be aligned with $XX00 as the	built-in DMA reads from
; there to $XX9F
Oam_Sprite_Buffer:: ds SPRITE_SIZE * OAM_LIMIT
Oam_Request_Buffer:: ds OAM_REQUEST_SIZE
Oam_Top:: dw

SECTION "Display Code", ROM0

HERO_SHEET:
INCBIN "hero.2bpp"
HERO_SHEET_END:
HERO_SHEET_SIZE EQU HERO_SHEET_END-HERO_SHEET

; Constants
BGP_DEFAULT EQU %11100100
OBP0_DEFAULT EQU %11010000

Oam_Reset::
	ld hl, Oam_Top
	ld bc, Oam_Sprite_Buffer
	call Kernel_PokeW

	ret

Oam_Request::
	; load DE with the address of Request_Buffer
	ld de, Oam_Request_Buffer

	; load HL with value of OAM Top and push it to the stack
	ld hl, Oam_Top
	call Kernel_PeekW
	ld h, b
	ld l, c
	;push hl

	; Has to be the size of the Sprite
	ld bc, SPRITE_SIZE

	; Move the requested Sprite in to the Oam_Sprite_Buffer
	call Kernel_MemCpy

	ret

; Methods
Display_Init::
.wait
	; wait until V-Blank period to turn off the LCDC
	ld a, [rLY]
	cp 144
	jr c, .wait

	; turn off the LCDC
	xor a
	ld [rLCDC], a

	; wipe VRAM and Sprite Attribute Table
	MEMSET _VRAM, 0, $A000-$8000
	MEMSET _OAMRAM, 0, $FEA0-$FE00

	call Oam_Reset

	; set BGP (background palette)
	ld a, BGP_DEFAULT
	ld [rBGP], a

	; set OBP0 (object palette 0)
	ld a, OBP0_DEFAULT
	ld [rOBP0], a

	; set Scroll X and Scroll Y
	xor a
	ld [rSCX], a
	ld [rSCY], a

	; Put the Display_DmaTransfer routine in to HRAM
	MEMCPY Display_DmaTransfer, Display_DmaTransferStart, Display_DmaTransferEnd - Display_DmaTransferStart

	; copy HERO_SHEET in to tiles
	;MEMCPY _VRAM, HERO_SHEET, HERO_SHEET_SIZE

	ret

Display_Start::
	; Turn on LCD, OBJ layer and BG later
	ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON
	ld [rLCDC], a

	; Enable v-blank interrupt
	ld a, IEF_VBLANK
	ld [rIE], a

	; Enable interrupts
	ei

	ret

DMA_DELAY EQU $28

Display_DmaTransferStart:
; this is the routine that transfers from Oam_Sprite_Buffer to the OAM in VRAM
	; trigger DMA transfer
	ld a, HIGH(Oam_Sprite_Buffer)
	ld [rDMA], a

	;
	ld a, DMA_DELAY

.wait
	; loop until the DMA transfer has finished, takes
	dec a ; 1 cycle
	jr nz, .wait ; 4 cycles

	ret

Display_DmaTransferEnd:
