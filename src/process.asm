INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "process.inc"

SECTION "Process WRAM Data", WRAM0

Process_Top:: dw
Process_This:: dw

SECTION "Process ROM0", ROM0

Process_Init::
; Set the Top to the start of PROCESS_SPACE

	ld bc, PROCESS_SPACE
	POKE_WORD (Process_Top)

	ret

Process_GetThisData::
; Get the start of the Data for the current Process
; hl <~ PROCESS_DATA

	PEEK_WORD (Process_This)
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
	PEEK_WORD (Process_Top)
	push bc

Process_Pipeline_Next:
; Run the next Process in the Pipeline

	; Set Process_This to the Process we're about to execute
	POKE_WORD (Process_This)

	; Get the address of Method
	ld h, b
	ld l, c

	; Get the value of Method in HL and jump to it
	MEMBER_PEEK_WORD (PROCESS_METHOD)
	ld h, b
	ld l, c
	jp hl
Process_Pipeline_Yield::
	; Write the new Method callback in BC to PROCESS_METHOD

	pop hl
	MEMBER_POKE_WORD (PROCESS_METHOD)

	; Get the address of the next Process and put it in BC and push to stack
	MEMBER_PEEK_WORD (PROCESS_NEXT)
	push bc

	; Check to see if Next is the end of PROCESS_SPACE
	; BC is already set for the Process_Do_Again
	ld hl, PROCESS_SPACE
	call Kernel_SubWord
	ld a, h
	or l
	jp nz, Process_Pipeline_Next

	; If it is, we drop it and return the loop
	pop bc

	ret

Process_Alloc::
; DE <~ Size
; Put the value of Top in HL and push to the stack

	; Get the old Top and push it to the stack
	PEEK_WORD (Process_Top)
	push bc
	ld h, b
	ld l, c

	; Put Size in BC
	ld b, d
	ld c, e

	; Put new Top in BC
	call Kernel_SubWord
	ld b, h
	ld c, l

	; Set Top to the new Top
	POKE_WORD (Process_Top)

	; Load the old Top in to the new Top's next
	ld h, b
	ld l, c
	pop bc
	MEMBER_POKE_WORD (PROCESS_NEXT)

	ret
