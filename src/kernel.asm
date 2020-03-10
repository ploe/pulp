INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "process.inc"

SECTION "Kernel WRAM Data", WRAM0
Kernel_ConsoleVersion:: db
Kernel_WaitingForVblank: db

SECTION "Kernel ROM0", ROM0

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

RSRESET
BLOB_X RB 1
BLOB_Y RB 1
BLOB_ANIMATION RW 1
BLOB_CLIP RB 1
BLOB_FRAME RB 1
BLOB_INTERVAL RB 1
BLOB_SIZE RB 0

BLOB_SHEET:
INCBIN "blob.2bpp"
BLOB_SHEET_END:
BLOB_SHEET_SIZE EQU BLOB_SHEET_END-BLOB_SHEET

Blob_Init:
		; Spawn our blob process
		ld de, BLOB_SIZE + PROCESS_SIZE
		call Process_Alloc

		; Put the address of Blob process address in HL
		ld hl, Process_Top
		call Kernel_PeekW
		ld h, b
		ld l, c

		; Set the Method for the Blob process to Blob_DrawProcess
		ld bc, Blob_DrawProcess
		call Kernel_PokeW

		ld de, BLOB_SIZE + PROCESS_SIZE
		call Process_Alloc

		; Put the address of Blob process address in HL
		ld hl, Process_Top
		call Kernel_PeekW
		ld h, b
		ld l, c

		; Set the Method for the Blob process to Blob_DrawProcess
		ld bc, Blob_DrawProcess
		call Kernel_PokeW

		ld de, BLOB_SIZE + PROCESS_SIZE
		call Process_Alloc

		; Put the address of Blob process address in HL
		ld hl, Process_Top
		call Kernel_PeekW
		ld h, b
		ld l, c

		; Set the Method for the Blob process to Blob_DrawProcess
		ld bc, Blob_DrawProcess
		call Kernel_PokeW

		MEMCPY _VRAM, BLOB_SHEET, BLOB_SHEET_SIZE

		ret

Blob_DrawProcess::
	; de ~> address of blob
	ld h, d
	ld l, e
	inc [hl]
	YIELD Blob_DrawProcessDec

Blob_DrawProcessDec::
	ld h, d
	ld l, e
	dec [hl]
	YIELD Blob_DrawProcess

Kernel_Init::
; entrypoint passes to Kernel_Init to set the system up for use

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

	call Process_Do

	; and around we go again...
	jp Kernel_Main

SECTION "Kernel V-Blank Interrupt", ROM0[$40]
	; stop waiting for v-blank
	xor a
	ld [Kernel_WaitingForVblank], a

	reti
