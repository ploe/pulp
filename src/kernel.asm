INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "actor.inc"

INCLUDE "display.inc"
INCLUDE "blob.inc" ; shouldn't really be here

SECTION "Kernel WRAM Data", WRAM0
Kernel_ConsoleVersion:: db
Kernel_WaitingForVblank: db

SECTION "Kernel ROM0", ROM0

Kernel_MemCpy::
; Copies num number of bytes from source to destination
; bc ~> num
; de ~> source
; hl ~> destination

.next_byte
	; fetch what we have in source and copy it into destination
	ld a, [bc]
	ld [hli], a
	inc bc
	dec de

	; loop until num is 0
	ld a, e
	or d
	jr nz, .next_byte

	ret

Kernel_MemSet::
; For amount of bytes in size at destination set them to the value of value
; hl ~> destination
; d  ~> value
; bc ~> size

.next_byte
	; fetch what we have in value and set it in destination
	ld a, b
	ld [hli], a
	dec de

	; loop until size is 0
	ld a, e
	or d
	jr nz, .next_byte

	ret

Sound_Init::
; Setup the Sound (disables it)
	xor a
	ld [rNR52], a

	ret

Kernel_Panic::
;
	jp Kernel_Panic

Kernel_Init::
; Entrypoint passes to Kernel_Init to set the system up for use

	; first value in register a is the sort of Game Boy we're running on
	ld [Kernel_ConsoleVersion], a

	; wipe RAM
	MEMSET _RAM, 0, $E000-$C000

	; set-up each of the hardware subsystems
	call Display_Init
	call Sound_Init

	call Oam_Reset
	call Blob_II_Spawn_All

	call Display_Start

	jp Kernel_Main

Kernel_Main::
; The main heartbeat of the program, waits for the vblank interrupt and kicks
; off each method
.halt
	halt

	; was it a v-blank interrupt?
	ld a, [Kernel_WaitingForVblank]
	and a
	jr nz, .halt

	; set v-blank to wait again
	ld a, 1
	ld [Kernel_WaitingForVblank], a

	call Oam_Blit_Tiles
	call Display_DmaTransfer
	call Oam_Next_Dynamic_Tile_Bank

	; Update the state of the game by calling the Pipeline functions
	PIPELINE_METHOD SIGNAL_UPDATE
	PIPELINE_METHOD SIGNAL_ANIMATE
	;PIPELINE_METHOD SIGNAL_VRAM_SETUP

	call Oam_Blit_Setup

	; and around we go again...
	jr .halt

SECTION "Kernel V-Blank Interrupt", ROM0[$40]
	; stop waiting for v-blank
	xor a
	ld [Kernel_WaitingForVblank], a

	reti
