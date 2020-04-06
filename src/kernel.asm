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

Kernel_Init::
; Entrypoint passes to Kernel_Init to set the system up for use

	; first value in register a is the sort of Game Boy we're running on
	ld [Kernel_ConsoleVersion], a

	; wipe RAM
	MEMSET _RAM, 0, $E000-$C000

	; set-up each of the hardware subsystems
	call Display_Init
	call Sound_Init

	BLOB_SPAWN $11, $15, %00000000, BLOB_REEL_RIGHT
	;BLOB_SPAWN $33, $33, %00000001, BLOB_REEL_UP
	;BLOB_SPAWN $55, $55, %00000011, BLOB_REEL_LEFT
	;BLOB_SPAWN $77, $77, %00000010, BLOB_REEL_DOWN
	;BLOB_SPAWN $11, $88, %00000000, BLOB_REEL_DOWN
	;BLOB_SPAWN $33, $66, %00000001, BLOB_REEL_DOWN
	;BLOB_SPAWN $55, $40, %00000011, BLOB_REEL_DOWN
	;BLOB_SPAWN $77, $22, %00000010, BLOB_REEL_DOWN

	;BLOB_SPAWN $22, $22, %00000010, BLOB_REEL_UP
	;BLOB_SPAWN $44, $44, %00000001, BLOB_REEL_UP
	;BLOB_SPAWN $66, $66, %00000011, BLOB_REEL_UP
	;BLOB_SPAWN $88, $88, %00000001, BLOB_REEL_UP
	;BLOB_SPAWN $22, $77, %00000010, BLOB_REEL_UP
	;BLOB_SPAWN $44, $55, %00000001, BLOB_REEL_UP
	;BLOB_SPAWN $66, $33, %00000001, BLOB_REEL_UP
	;BLOB_SPAWN $88, $11, %00000000, BLOB_REEL_UP

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

	call Display_DmaTransfer
	call Oam_Reset

	; Update the state of the game by calling the Pipeline functions
	PIPELINE_METHOD SIGNAL_UPDATE
	PIPELINE_METHOD SIGNAL_ANIMATE
	PIPELINE_METHOD SIGNAL_VRAM_SETUP

	; and around we go again...
	jr .halt

SECTION "Kernel V-Blank Interrupt", ROM0[$40]
	; stop waiting for v-blank
	xor a
	ld [Kernel_WaitingForVblank], a

	reti
