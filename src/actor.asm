INCLUDE "hardware.inc"

INCLUDE "kernel.inc"
INCLUDE "actor.inc"

SECTION "Actor WRAM Data", WRAM0

Actor_Top:: dw
Actor_This:: dw
Actor_Pipeline_Signal:: dw

SECTION "Actor ROM0", ROM0

Actor_Pipeline_Begin::
; Call the Pipeline Method on each Actor from the Top
; bc <~> Method signal
; hl ~> This

	; Set Actor_Pipeline_Signal
	push bc
	POKE_WORD (Actor_Pipeline_Signal)

	; Set This to Top and put in HL
	PEEK_WORD (Actor_Top)
	POKE_WORD (Actor_This)
	ld h, b
	ld l, c

	; Put Actor_Pipeline_Signal in BC
	pop bc

	jp Actor_Pipeline_CallMethod

Actor_Pipeline_Next::
; Get the next Actor to call the Pipeline method on
; bc <~ Actor_Pipeline_Signal
; hl <~ This->Next

	ACTOR_GET_THIS

	; If we're at the end of the Actors, we break
	MEMBER_PEEK_WORD (ACTOR_NEXT)
	ld a, c
	or b
	ret z

	; Make it the new This
	POKE_WORD (Actor_This)
	push bc

	; Put Actor_Pipeline_Signal in BC
	PEEK_WORD (Actor_Pipeline_Signal)

	; Put this in HL
	pop hl

	jp Actor_Pipeline_CallMethod

Actor_Pipeline_CallMethod:
; hl ~> This
; bc ~> Actor_Pipeline_Signal
	; Preserve Actor_Pipeline_Signal
	push bc

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

	; If the callback is not set, let's do the next Actor
	ld a, c
	or b
	jp z, Actor_Pipeline_Next

	; Otherwise call the callback
	ld h, b
	ld l, c

	jp hl

NEW_Actor_Spawn::
; bc ~> Size
; bc <~ Data address
; Put the value of Top in HL and push to the stack

	; Get the old Top and push it to the stack
	NEW_PEEK_WORD (Actor_Top)
	push de

	; If the Top is empty
	ld a, e
	or d
	jr nz, .continue

	; then start at ACTOR_SPACE_START
	ld de, ACTOR_SPACE_START

.continue
	; Put Size in HL
	ld h, b
	ld l, c

	; Put new Top in DE
	SUB_WORD

	; Set Top to the new Top
	NEW_POKE_WORD (Actor_Top)

	; Load the old Top in to the new Top's next
	ld b, d
	ld c, e
	pop de
	NEW_MEMBER_POKE_WORD (ACTOR_NEXT)

	ret
