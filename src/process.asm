INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "process.inc"

SECTION "Process WRAM Data", WRAM0

Process_Top:: dw

SECTION "Process ROM0", ROM0

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
	ld bc, Process_Next
	add hl, bc

	; Load the old Top in to the new Top's next
	pop bc
	call Kernel_PokeW

	ret
