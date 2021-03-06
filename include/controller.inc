	IF !DEF(_PULP_CONTROLLER_INC)
_PULP_CONTROLLER_INC SET 1

; Buttons
CONTROLLER_A EQU 0
CONTROLLER_B EQU 1
CONTROLLER_SELECT EQU 2
CONTROLLER_START EQU 3

; DPAD
CONTROLLER_RIGHT EQU 4
CONTROLLER_LEFT EQU 5
CONTROLLER_UP EQU 6
CONTROLLER_DOWN EQU 7

CONTROLLER_KEY_CHANGED: MACRO
; If specific key was just pressed
; \1 ~> Key
; \2 ~> Label

	; Check to see if Key was just pressed down
	ld hl, Controller_Keys_Changed
	bit \1, [hl]
	jr nz, \2

	ENDM

CONTROLLER_KEY_HELD: MACRO
; If specific key is being pressed

	; Check to see if Key was just pressed down
	ld hl, Controller_Keys_Held
	bit \1, [hl]
	jr nz, \2

	ENDM

ENDC
