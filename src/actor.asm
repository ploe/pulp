INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "actor.inc"

SECTION "Actor WRAM Data", WRAM0

Actor_Top:: dw
Actor_This:: dw
Actor_Signal:: dw

SECTION "Actor ROM0", ROM0

Actor_Broadcast::
	push bc
	PEEK_WORD (Actor_Top)
	POKE_WORD (Actor_This)
	ld h, b
	ld l, c


Actor_Pipeline_Next:

	; Add the Signal to the type to get to correct callback
	MEMBER_PEEK_WORD (ACTOR_TYPE)
	ld h, b
	ld l, c
	pop de
	add hl, de

	; Put the callback in BC
	ld c, [hl]
	inc hl
	ld b, [hl]

	; If the callback is not set, jump to yield
	ld a, c
	or b
	jr z, .yield

	; Otherwise call the callback
	ld h, b
	ld l, c

	jp hl

.yield
Actor_Pipeline_Yield::
	; Get the address of the next Actor and put it in BC and push to stack
	;ACTOR_GET_THIS

	; If Next is not zero, then we do iterate again
	;MEMBER_PEEK_WORD (ACTOR_NEXT)
	;POKE_WORD (Actor_This)

	;ld a, c
	;or b
	;jp nz, Actor_Pipeline_Next

	ret

Actor_Spawn::
; DE <~ Size
; Put the value of Top in HL and push to the stack

	; Get the old Top and push it to the stack
	PEEK_WORD (Actor_Top)
	push bc

	; If the Top is empty
	ld a, c
	or b
	jr nz, .continue

	; then start at ACTOR_SPACE_START
	ld bc, ACTOR_SPACE_START

.continue
	; Put Top in HL
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

	; Put new Top in HL
	ld h, b
	ld l, c

	; Set all the data to 0
	ld c, 0
	call Kernel_MemSet

	; Set NEXT to the old Top
	pop bc
	MEMBER_POKE_WORD (ACTOR_NEXT)

	ret
