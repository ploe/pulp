INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "process.inc"

SECTION "Process WRAM Data", WRAM0

Process_Top:: dw
Process_This:: dw

SECTION "Process ROM0", ROM0

Process_Init::
; Set the Top to the start of PROCESS_SPACE

	ld hl, Process_Top
	ld bc, PROCESS_SPACE
	call Kernel_PokeW

	ret

Process_GetThisData::
; Get the start of the Data for the current Process
; hl <~ PROCESS_DATA

	ld hl, Process_This
	call Kernel_PeekW
	ld h, b
	ld l, c

	ld bc, PROCESS_DATA
	add hl, bc

	ret

Process_PipelineDraw::
; Iterate over the Processes and call their Draw Methods
Process_PipelineMove::
; Iterate over the Processes and call their Move Methods
Process_PipelineUpdate::
; Iterate over the Processes and call their Update methods

	; Get the first Process address, and push it to the stack
	ld hl, Process_Top
	call Kernel_PeekW
	push bc

Process_Pipeline_Next:
; Run the next Process in the Pipeline

	; Set Process_This to the Process we're about to execute
	ld hl, Process_This
	call Kernel_PokeW

	; Get the address of Method, the first element of the PROCESS struct
	ld h, b
	ld l, c

	; Get the value of Method in HL and jump to it
	call Kernel_PeekW
	ld h, b
	ld l, c
	jp hl
Process_Pipeline_Yield::
	; Write the new Method callback in BC to PROCESS_METHOD

	pop hl
	push hl
	call Kernel_PokeW

	; Get the address of the next Process and put it in BC and push to stack
	pop hl
	ld bc, PROCESS_NEXT
	add hl, bc
	call Kernel_PeekW
	push bc

	; Check to see if Next is the end of PROCESS_SPACE
	; BC is already set for the Process_Do_Again
	ld hl, PROCESS_SPACE
	call Kernel_SubW
	ld a, h
	or l
	jp nz, Process_Pipeline_Next

	; If it is, we drop it and return the loop
	pop bc

	ret

Process_Alloc::
; DE <~ Size
; Put the value of Top in HL and push to the stack

	ld hl, Process_Top
	call Kernel_PeekW
	push bc
	ld h, b
	ld l, c

	; Put Size in BC
	ld b, d
	ld c, e

	; Put new Top in BC
	call Kernel_SubW
	ld b, h
	ld c, l

	; Set Top to the new Top
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
