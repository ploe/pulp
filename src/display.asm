; hardware.inc
INCLUDE "hardware.inc"

; project libs
INCLUDE "kernel.inc"

SECTION "Display Data", WRAM0[$C000]
; OAM_BUFFER needs to be aligned with $XX00 as the  built-in DMA reads from
; there to $XX9F
OAM_BUFFER: ds 4 * 40

SECTION "Display Code", ROM0

HERO_SHEET:
INCBIN "hero.2bpp"
HERO_SHEET_END:
HERO_SHEET_SIZE EQU HERO_SHEET_END-HERO_SHEET

BGP_DEFAULT EQU %11100100
OBP0_DEFAULT EQU %11010000

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
  MEMSET _VRAM, 0, $9FFF-$8000
  MEMSET _OAMRAM, 0, $FE9F-$FE00

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

  ; copy HERO_SHEET in to tiles
  MEMCPY _VRAM, HERO_SHEET, HERO_SHEET_SIZE

  ret

DMA_DELAY EQU $28

Display_DmaTransfer:
; this is the routine that transfers from OAM_BUFFER to the OAM in VRAM
  ; trigger DMA transfer
	ld a, HIGH(OAM_BUFFER)
	ld [rDMA], a

  ;
	ld a, DMA_DELAY

.wait
  ; loop until the DMA transfer has finished, takes
	dec a ; 1 cycle
	jr nz, .wait ; 4 cycles

	ret

Display_DmaTransferEnd:
