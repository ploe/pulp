INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "actor.inc"

SECTION "Actor WRAM Data", WRAM0

Actor_Top:: dw
Actor_This:: dw

SECTION "Actor ROM0", ROM0

Actor_Init::
; Set the Top to the start of ACTOR_SPACE

	ld bc, ACTOR_SPACE
	POKE_WORD (Actor_Top)

	ret

Actor_PipelineDraw::
; Iterate over the Actors and call their Draw Methods
Actor_PipelineMove::
; Iterate over the Actors and call their Move Methods
Actor_PipelineUpdate::
; Iterate over the Actors and call their Update methods

	; Get the first Actor address, and push it to the stack
	PEEK_WORD (Actor_Top)
	push bc

Actor_Pipeline_Next:
; Run the next Actor in the Pipeline

	; Set Actor_This to the Actor we're about to execute
	POKE_WORD (Actor_This)

	; Get the address of Method
	ld h, b
	ld l, c

	; Get the value of Method in HL and jump to it
	INDEX_PEEK_WORD (ACTOR_METHOD)
	ld h, b
	ld l, c
	jp hl
Actor_Pipeline_Yield::
	; Write the new Method callback in BC to ACTOR_METHOD

	pop hl
	MEMBER_POKE_WORD (ACTOR_METHOD)

	; Get the address of the next Actor and put it in BC and push to stack
	MEMBER_PEEK_WORD (ACTOR_NEXT)
	push bc

	; Check to see if Next is the end of ACTOR_SPACE
	; BC is already set for the Actor_Do_Again
	ld hl, ACTOR_SPACE
	call Kernel_SubWord
	ld a, h
	or l
	jp nz, Actor_Pipeline_Next

	; If it is, we drop it and return the loop
	pop bc

	ret

Actor_Alloc::
; DE <~ Size
; Put the value of Top in HL and push to the stack

	; Get the old Top and push it to the stack
	PEEK_WORD (Actor_Top)
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
	POKE_WORD (Actor_Top)

	; Load the old Top in to the new Top's next
	ld h, b
	ld l, c
	pop bc
	MEMBER_POKE_WORD (ACTOR_NEXT)

	ret
