	IF !DEF(_PULP_KERNEL_INC)
_PULP_KERNEL_INC SET 1

; Constants
CONSOLE_DMG EQU $01
CONSOLE_MGB EQU $FF
CONSOLE_CGB EQU $11

; Macros
MEMCPY: MACRO
	; copies num number of bytes from source to destination
	; sets up the registers and calls Kernel_MemCpy

	push af
	push bc
	push de
	push hl

	ld hl, \1 ; destination
	ld bc, \2 ; source
	ld de, \3 ; num

	call Kernel_MemCpy

	pop hl
	pop de
	pop bc
	pop af

	ENDM

MEMSET: MACRO
	; for amount of bytes in size at destination set them to the value of value
	; calls Kernel_MemSet
	push af
	push de
	push hl

	ld hl, \1 ; destination
	ld b, \2	; value
	ld de, \3 ; size

	call Kernel_MemSet

	pop hl
	pop de
	pop af

	ENDM

NEW_PEEK_WORD: MACRO
; Get Value in Address
; \1 ~> Address
; de <~ Value

	; Load address
	ld hl, \1

	; Get Value
	ld e, [hl]
	inc hl
	ld d, [hl]

	ENDM

NEW_POKE_WORD: MACRO
; Put Value in Address
; \1 ~> Address
; de ~> Value

	; Load address
	ld hl, \1

	; Load Value in to Data->Member
	ld [hl], e
	inc hl
	ld [hl], d

	ENDM

; MEMBER macros preserve the address in BC

MEMBER_ADDRESS: MACRO
; bc <~> Data
; \1 ~> Member
; hl <~ Data->Member address
	ld hl, \1
	add hl, bc

	ENDM

NEW_MEMBER_PEEK_BYTE: MACRO
; Get the Value in Data->Member and returns Data in HL
; bc <~> Data
; \1 ~> Member
; a  <~ Value


	; Add Member offset to Data address
	ld hl, \1
	add hl, bc

	; Load Value in to Data->Member
	ld a, [hl]

	ENDM

NEW_MEMBER_PEEK_WORD: MACRO
; Get the Value in Data->Member and returns Data in HL
; bc <~> Data
; \1 ~> Member
; de <~ Value

	; Add Member offset to Data address
	ld hl, \1
	add hl, bc

	; Get Value from Data->Member
	ld e, [hl]
	inc hl
	ld d, [hl]

	ENDM

NEW_MEMBER_POKE_BYTE: MACRO
; Sets Data->Member to Value and returns Data in HL
; bc <~> Data
; a  ~> Value
; \1 ~> Member

	; Add Member offset to Data address
	ld hl, \1
	add hl, bc

	; Load Value in to Data->Member
	ld [hl], a


	ENDM

NEW_MEMBER_POKE_WORD: MACRO
; Sets Data->Member to Value and returns Data in HL
; bc <~> Data
; de ~> Value
; \1 ~> Member

	; Add Member offset to Data address
	ld hl, \1
	add hl, bc

	; Load Value in to Data->Member
	ld [hl], e
	inc hl
	ld [hl], d

	ENDM

NEW_MEMBER_BIT: MACRO
; [bit|res|set] the Bit at Data->Member
; bc <~> Data
; \1 ~> bit | res | set
; \2 ~> Member
; \3 ~> Bit

	; Set HL to Data->Member address
	ld hl, \2
	add hl, bc

	; Do the appropriate bit-centric op on Data->Member[Bit]
	\1 \3, [hl]


	ENDM

SUB_WORD: MACRO
; Subtract words subtrahend from minuend
; hl ~> subtrahend
; de ~> minuend
; de <~ result

	; Subtract word in BC from HL
	ld a, e
	sub a, l
	ld e, a

	ld a, d
	sbc a, h
	ld d, a


	ENDM

ENDC
