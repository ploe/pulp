INCLUDE "hardware.inc"

INCLUDE "kernel.inc"

SECTION "Kernel WRAM Data", WRAM0
Kernel_ConsoleVersion:: db
Kernel_WaitingForVblank: db


Process_Top: dw
;Process_This: dw

SECTION "Kernel ROM0", ROM0

RSRESET
Process_Code RW 1
; Process_Pid
; Process_Bank RB 1
Process_Next RW 1
PROCESS_SIZE RB 0

Process_Space EQU $E000

SUBW: MACRO
	; Subtract words subtrahend from minuend
	; \1 -> minuend
	; \2 -> subtrahend
	; result -> hl
	ld hl, \1
	ld bc, \2
	call Kernel_SubW

	ENDM

Kernel_SubW::
	; Subtract words subtrahend from minuend
	; bc -> subtrahend
	; hl -> minuend
	; result -> hl

	; Subtract word in BC from HL
	ld a, l
	sub a, c
	ld l, a
	ld a, h
	sbc a, b
	ld h, a

	ret

Kernel_PeekW::
	; Gets the value from source and pushes it to the stack
	; destination <~ hl
	; value ~> bc
	; next ~> hl

	ld b, [hl]
	inc hl
	ld c, [hl]
	inc hl

	ret

Process_Alloc::
	; cache Size in DE
	ld d, h
	ld e, l

	; Put the value of Top in HL and push to the stack
	ld hl, Process_Top
	call Kernel_PeekW
	push bc
	ld h, b
	ld l, c

	; grab Size in BC
	ld b, d
	ld c, e

	; Put new Top in BC
	call Kernel_SubW
	ld b, h
	ld c, l

	; set Top to new Top
	ld hl, Process_Top
	call Kernel_PokeW

	; Get the address of Next in the new Top
	ld h, b
	ld l, c
	ld bc, Process_Next
	add hl, bc

	; Load the old Top in to the new Top's next
	pop bc
	call Kernel_PokeW

	ret

Kernel_PokeW::
	; Sets destination to value and push the next address to the stack
	; destination <~ hl
	; value <~ bc
	; next -> hl
	ld [hl], b
	inc hl
	ld [hl], c
	inc hl

	ret

Kernel_MemCpy::
; copies num number of bytes from source to destination
; bc num
; de source
; hl destination
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
; for amount of bytes in size at destination set them to the value of value
; hl destination
; d value
; bc size
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
	; turn off the sound
	xor a
	ld [rNR52], a

	ret

Kernel_Init::
; entrypoint passes to Kernel_Init to set the system up for use

	; first value in register a is the sort of Game Boy we're running on
	ld [Kernel_ConsoleVersion], a

	; wipe RAM
	MEMSET _RAM, 0, $E000-$C000

	; Set the Top to the start of ProcessSpace
	ld hl, Process_Top
	ld bc, Process_Space
	call Kernel_PokeW

	ld hl, 10
	call Process_Alloc

	ld hl, 15
	call Process_Alloc

	; set-up each of the hardware subsystems
	call Display_Init
	call Sound_Init

	jp Kernel_Main

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
