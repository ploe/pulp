	IF !DEF(_PULP_ACTOR_INC)
_PULP_ACTOR_INC SET 1

; ACTOR struct
RSRESET
ACTOR_TYPE RW 1
ACTOR_NEXT RW 1
ACTOR_DATA RB 0
ACTOR_SIZE RB 0

; SIGNAL enum
RSRESET
SIGNAL_UPDATE RW 1
SIGNAL_ANIMATE RW 1
SIGNAL_VRAM_SETUP RW 1
SIGNAL_VRAM_WRITE RW 1
SIGNAL_SIZE RB 0

ACTOR_SPACE_START EQU $E000

ACTOR_GET_THIS: MACRO
; Get the Data for the current Actor
; hl <~ This
	PEEK_WORD (Actor_This)
	ld h, b
	ld l, c

	ENDM

NEW_ACTOR_GET_THIS: MACRO
; Get the Data for the current Actor
; hl <~ This
	PEEK_WORD (Actor_This)
	
	ENDM

PIPELINE_METHOD: MACRO
; \1 ~> Actor_Pipeline_Signal
	ld bc, \1
	call Actor_Pipeline_Begin

	ENDM

YIELD: MACRO
	jp Actor_Pipeline_Next
	ENDM

ENDC
