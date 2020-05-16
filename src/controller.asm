INCLUDE "hardware.inc"

SECTION "Controller WRAM Data", WRAM0
Controller_Keys_Changed:: db
Controller_Keys_Held:: db

SECTION "Controller Code", ROM0

CONTROLLER_P1_KEYS EQU %00001111

Controller_Update::

	; Set Output Port on Controller to P15 (A, B, Select, Start)
	ld a, P1F_5
	ld [rP1], a

	; Load P15 into A, twice, as state can bounce
	ld a, [rP1]
	ld a, [rP1]

	; Store P15 in E
	cpl
	and CONTROLLER_P1_KEYS
	swap a
	ld e, a

	; Set Output Port to P14 (Right, Left, Up, Down)
	ld a, P1F_4
	ld [rP1], a

	; Load P14 in A, six times, as state can bounce
	ld a, [rP1]
	ld a, [rP1]
	ld a, [rP1]
	ld a, [rP1]
	ld a, [rP1]
	ld a, [rP1]

	; Merge P15 and P14 in A
	cpl
	and CONTROLLER_P1_KEYS
	or e

	; Get and store as Controller_Keys_Changed
	ld e, a
	ld a, [Controller_Keys_Held]
	cpl
	and e
	ld [Controller_Keys_Changed], a

	; Store merged keys as Controller_Keys_Held
	ld a, e
	ld [Controller_Keys_Held], a

	ret
