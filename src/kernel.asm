INCLUDE "hardware.inc"

INCLUDE "kernel.inc"

SECTION "Kernel WRAM Data", WRAM0

Kernel_ConsoleVersion:: ds 1
Kernel_WaitingForVblank: ds 1
Kernel_Method: ds 2


SECTION "Kernel ROM0", ROM0

Kernel_MemCpy::
; copies num number of bytes from source to destination
; bc num
; de source
; hl destination
.next_byte\@
	; fetch what we have in source and copy it into destination
	ld a, [de]
	ld [hli], a
	inc de
	dec bc

	; loop until num is 0
	ld a, b
	or c
	jr nz, .next_byte\@

	ret

Kernel_MemSet::
; for amount of bytes in size at destination set them to the value of value
; hl destination
; d value
; bc size
.next_byte\@
	; fetch what we have in value and set it in destination
	ld a, d
	ld [hli], a
	dec bc

	; loop until size is 0
	ld a, b
	or c
	jr nz, .next_byte\@

	ret

Sound_Init::
	; turn off the sound
	xor a
	ld [rNR52], a

	ret

Kernel_Init::
; entrypoint passes to Kernel_Start to set the system up for use

	; first value in register a is the sort of Game Boy we're running on
	ld [Kernel_ConsoleVersion], a

	; wipe RAM
	MEMSET _RAM, 0, $DFFF-$C000

	; set-up each of the hardware subsystems
	call Display_Init
	call Sound_Init

Kernel_Main::
; main heartbeat of the program, waits for the vblank interrupt and kicks off
; the method
.wait
	halt

	; was it a v-blank interrupt?
	ld a, [Kernel_WaitingForVblank]
	and a
	jr nz, .wait

	; set v-blank to wait again
	ld a, 1
	ld [Kernel_WaitingForVblank], a

	; call Kernel_Method

	; and around we go again...
	jp Kernel_Main

SECTION "Kernel V-Blank Interrupt", ROM0[$40]
	; stop waiting for v-blank
	xor a
	ld [Kernel_WaitingForVblank], a

	reti
