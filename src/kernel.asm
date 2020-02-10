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

Kernel_SubW::
	pop de ; SP
	pop bc ; subtrahend
	pop hl ; minuend

	; Subtract word in BC from HL
	ld a, l
	sub a, c
	ld l, a
	ld a, h
	sbc a, b
	ld h, a

	; push return value to stack
	push hl

	; return
	push de
	ret

Kernel_PeekW::
	; Gets the value from source and pushes it to the stack
	pop de ; SP
	pop hl ; source

	ld b, [hl]
	inc hl
	ld c, [hl]

	push bc

	push de
	ret

Process_Alloc::
	; push a pointer to Top to the stack
	ld hl, Process_Top
	push hl ; Top address for PokeW

	; push the value in Top to the stack
	call Kernel_PeekW

	; reorganise the stack so the values are in the right order
	pop hl ; Top value
	pop de ; SP
	pop bc ; Size

	push de
	push hl
	push bc

	; push new Top to stack
	call Kernel_SubW
	pop bc

	; push Top address to stack
	ld hl, Process_Top
	push hl

	; push new Top value to stack
	push bc

	; set Top to new Top and ignore return value
	call Kernel_PokeW
	pop hl ; discard the return value

	ret

Kernel_PokeW::
	; Sets destination to value and push the next address to the stack
	pop de ; SP
	pop bc ; value
	pop hl ; destination

	ld [hl], b
	inc hl
	ld [hl], c
	inc hl

	push hl

	push de
	ret


	;ENDM

	; push new Top to stack, twice

	; set Code to init method and push pointer to Next member to stack
;	push de
;	call Kernel_PokeW
;	pop hl
;	pop de
;	push hl

	; push address of Process_Top to stack
;	ld hl, Process_Top
;	push hl

	; Set Next member to current Top
;	push de
;	call Kernel_PokeW
;	inc sp	; discard value most recent on stack
;	pop de

	; Get the new Top and set it
;	push de
;	call Kernel_PokeW
;	inc sp
;	pop de

;	ENDM

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
	push hl
	ld hl, Process_Space
	push hl
	call Kernel_PokeW
	pop hl ; discard hl
	;ld [hl], b
	;inc hl
	;ld [hl], c

	ld hl, 10
	push hl
	call Process_Alloc

	ld hl, 15
	push hl
	call Process_Alloc

	;SPAWN $8888, 1
	;SPAWN $1313, 10
	;SPAWN $F035, 15
	;SPAWN
	;SPAWN
	;SPAWN

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
