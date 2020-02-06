INCLUDE "hardware.inc"

INCLUDE "kernel.inc"

SECTION "Kernel WRAM Data", WRAM0
Kernel_ConsoleVersion:: db
Kernel_WaitingForVblank: db
Kernel_Method: dw
Kernel_ProcessTop: dw
Kernel_ProcessThis: dw
Kernel_ProcessCursor: dw
Kernel_ProcessSpace:

SECTION "Kernel ROM0", ROM0

RSRESET
Process_Code RW 1
; Process_Pid
; Process_Bank RB 1
Process_Next RW 1
Process_Data RB 0
PROCESS_SIZE RB 0

SPAWN: MACRO
	; this = cursor
	; this->next = top
	; cursor += size
	; init(this)

	; put the value of Cursor
	ld hl, Kernel_ProcessCursor
	ld b, [hl]
	inc hl
	ld c, [hl]
	ld l, c
	ld h, b

	ld bc, 10 ; example size

	; C += L
	ld a, c
	add a, l
	ld c, a

	; B += H with the Carry Flag
	ld a, b
	adc a, h
	ld b, a

	; cursor += size
	ld hl, Kernel_ProcessCursor
	ld [hl], b
	inc hl
	ld [hl], c

	ENDM

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
; entrypoint passes to Kernel_Init to set the system up for use

	; first value in register a is the sort of Game Boy we're running on
	ld [Kernel_ConsoleVersion], a

	; wipe RAM
	MEMSET _RAM, 0, $DFFF-$C000

	; Set the Cursor to the start of ProcessSpace
	ld hl, Kernel_ProcessCursor
	ld bc, Kernel_ProcessSpace
	ld [hl], b
	inc hl
	ld [hl], c

	; Put the value of Cursor in BC
	ld hl, Kernel_ProcessCursor
	ld b,	[hl]
	inc hl
	ld c, [hl]

	; Put the value of BC (cursor) in Kernel_ProcessThis
	ld hl, Kernel_ProcessThis
	ld [hl], b
	inc hl
	ld [hl], c


	SPAWN
	SPAWN
	;SPAWN
	;SPAWN
	;SPAWN
	;SPAWN
	;SPAWN

	; set-up each of the hardware subsystems
	call Display_Init
	call Sound_Init

	;ret

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
