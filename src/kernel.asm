INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "process.inc"

SECTION "Kernel WRAM Data", WRAM0
Kernel_ConsoleVersion:: db
Kernel_WaitingForVblank: db

SECTION "Kernel ROM0", ROM0

SUBW: MACRO
; Subtract words subtrahend from minuend
; \1 ~> minuend
; \2 ~> subtrahend
; hl <~ result

	ld hl, \1
	ld bc, \2
	call Kernel_SubW

	ENDM

Kernel_SubW::
; Subtract words subtrahend from minuend
; bc ~> subtrahend
; hl ~> minuend
; hl <~ result

	; Subtract word in BC from HL
	ld a, l
	sub a, c
	ld l, a
	ld a, h
	sbc a, b
	ld h, a

	ret

Kernel_PeekW::
; Gets the word value from source
; hl ~> source
; bc <~ value

	ld b, [hl]
	inc hl
	ld c, [hl]

	ret

Kernel_PokeW::
; Sets destination to value
; destination <~ hl
; value <~ bc

	ld [hl], b
	inc hl
	ld [hl], c

	ret

Kernel_MemCpy::
; Copies num number of bytes from source to destination
; bc ~> num
; de ~> source
; hl ~> destination

.next_byte
	; fetch what we have in source and copy it into destination
	ld a, [de]
	ld [hli], a
	inc de
	dec bc

	; loop until num is 0
	ld a, b
	or c
	jr nz, .next_byte

	ret

Kernel_MemSet::
; For amount of bytes in size at destination set them to the value of value
; hl ~> destination
; d  ~> value
; bc ~> size

.next_byte
	; fetch what we have in value and set it in destination
	ld a, d
	ld [hli], a
	dec bc

	; loop until size is 0
	ld a, b
	or c
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

	call Process_Init

	; set-up each of the hardware subsystems
	call Display_Init
	call Sound_Init

	call Blob_Init

	call Display_Start

	jp Kernel_Main

Kernel_Main::
; The main heartbeat of the program, waits for the vblank interrupt and kicks
; off each method
.wait
	halt

	; was it a v-blank interrupt?
	ld a, [Kernel_WaitingForVblank]
	and a
	jr nz, .wait

	; set v-blank to wait again
	ld a, 1
	ld [Kernel_WaitingForVblank], a

	; Update the state of the game by calling the Pipeline functions
	call Process_PipelineDraw
	call Process_PipelineMove
	call Process_PipelineUpdate

	; and around we go again...
	jp Kernel_Main

SECTION "Kernel V-Blank Interrupt", ROM0[$40]
	; stop waiting for v-blank
	xor a
	ld [Kernel_WaitingForVblank], a

	reti
