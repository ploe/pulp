INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "process.inc"

SECTION "Process WRAM Data", WRAM0

Process_Top:: dw

SECTION "Process ROM0", ROM0

Process_Init::
	; Set the Top to the start of ProcessSpace
	ld hl, Process_Top
	ld bc, PROCESS_SPACE
	call Kernel_PokeW

	ret

Process_Do::
	; get the first Process address
	ld hl, Process_Top
	call Kernel_PeekW

	; Get the start of the Data
	ld h, b
	ld l, c
	ld de, PROCESS_SIZE
	add hl, de
	ld d, h
	ld e, l

	; Get Code, the first element of the PROCESS struct
	ld h, b
	ld l, c

	; get the Code and put leave in BC
	call Kernel_PeekW

	ld hl, Process_Do_Ret
	push hl

	; Put Code in HL and jump to it
	ld h, b
	ld l, c
	jp hl
Process_Do_Ret:
	ret

Process_Alloc::
	; DE <~ Size
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
	ld bc, PROCESS_NEXT
	add hl, bc

	; Load the old Top in to the new Top's next
	pop bc
	call Kernel_PokeW

	ret
