INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "process.inc"

INCLUDE "display.inc"
INCLUDE "blob.inc" ; shouldn't really be here

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

Kernel_MemberGetW::
; Gets value from Data->Member to Value
; hl <~> Data address
; de ~> Member offset
; bc  <~ Value
; Preserve Data address
	push hl

	; Add Member offset to Data address
	add hl, de

	; Get Value from Data->Member
	ld b, [hl]
	inc hl
	ld c, [hl]

	; Reset HL to what it started as
	pop hl

	ret

Kernel_MemberGetB::
; Gets value from Data->Member to Value
; hl <~> Data address
; de ~> Member offset
; a  <~ Value
	; Preserve Data address
	push hl

	; Add Member offset to Data address
	add hl, de

	; Load Value in to Data->Member
	ld a, [hl]

	; Reset HL to what it started as
	pop hl

	ret

Kernel_MemberSetW::
; Sets Data->Member to Value and returns Data in HL
; hl <~> Data address
; de ~> Member offset
; bc ~> Value

	; Preserve Data address
	push hl

	; Add Member offset to Data address
	add hl, de

	; Load Value in to Data->Member
	ld [hl], b
	inc hl
	ld [hl], c

	; Reset HL to what it started as
	pop hl

	ret

Kernel_MemberSetB::
; Sets Data->Member to Value and returns Data in HL
; hl <~> Data address
; de ~> Member offset
; a  ~> Value

	; Preserve Data address
	push hl

	; Add Member offset to Data address
	add hl, de

	; Load Value in to Data->Member
	ld [hl], a

	; Reset HL to what it started as
	pop hl

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

	BLOB_SPAWN $11, $11, BLOB_CLIP_DOWN, %00000000, Blob_DownAnimation
	;BLOB_SPAWN $33, $33, BLOB_CLIP_DOWN, %00000000
	;BLOB_SPAWN $55, $55, BLOB_CLIP_DOWN, %00000000
	;BLOB_SPAWN $77, $77, BLOB_CLIP_DOWN, %00000000
	;BLOB_SPAWN $11, $88, BLOB_CLIP_DOWN, %00000000
	;BLOB_SPAWN $33, $66, BLOB_CLIP_DOWN, %00000000
	;BLOB_SPAWN $55, $44, BLOB_CLIP_DOWN, %00000000
	;BLOB_SPAWN $77, $22, BLOB_CLIP_DOWN, %00000000

	;BLOB_SPAWN $22, $22, BLOB_CLIP_UP, %00000001
	;BLOB_SPAWN $44, $44, BLOB_CLIP_UP, %00000001
	;BLOB_SPAWN $66, $66, BLOB_CLIP_UP, %00000001
	;BLOB_SPAWN $88, $88, BLOB_CLIP_UP, %00000001
	;BLOB_SPAWN $22, $77, BLOB_CLIP_UP, %00000001
	;BLOB_SPAWN $44, $55, BLOB_CLIP_UP, %00000001
	;BLOB_SPAWN $66, $33, BLOB_CLIP_UP, %00000001
	;BLOB_SPAWN $88, $11, BLOB_CLIP_UP, %00000001

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

	call Display_DmaTransfer
	call Oam_Reset

	; Update the state of the game by calling the Pipeline functions
	call Process_PipelineMove
	call Process_PipelineUpdate
	call Process_PipelineDraw

	; and around we go again...
	jp Kernel_Main

SECTION "Kernel V-Blank Interrupt", ROM0[$40]
	; stop waiting for v-blank
	xor a
	ld [Kernel_WaitingForVblank], a

	reti
