	IF !DEF(KERNEL_INC)
KERNEL_INC SET 1

; Constants
CONSOLE_DMG EQU $01
CONSOLE_MGB EQU $FF
CONSOLE_CGB EQU $11

; Macros
MEMCPY: MACRO
	; copies num number of bytes from source to destination
	; sets up the registers and calls Kernel_MemCpy
	push bc
	push de
	push hl

	ld hl, \1 ; destination
	ld de, \2 ; source
	ld bc, \3 ; num

	call Kernel_MemCpy

	pop hl
	pop de
	pop bc

	ENDM

MEMSET: MACRO
	; for amount of bytes in size at destination set them to the value of value
	; calls Kernel_MemSet
	push bc
	push de
	push hl

	ld hl, \1 ; destination
	ld d, \2	; value
	ld bc, \3 ; size

	call Kernel_MemSet

	pop hl
	pop de
	pop bc

	ENDM

MEMBER_SUCK_BYTE: MACRO
; Get the Value in Data->Member, called before with MEMBER_SPIT_BYTE
; hl ~> Data
; \1 ~> Member

	; Preserve data address
	push hl

	; Add Member offset to Data address
	ld de, \1
	add hl, de

	; Load Value from Data->Member
	ld a, [hl]

	ENDM

MEMBER_SPIT_BYTE: MACRO
; Set the value in Data->Member, called after with MEMBER_SUCK_BYTE
; hl ~> Data->Member
; a  ~> Value
; hl <~ Data

	; Load Value in to Data->Member
	ld [hl], a

	; Reset HL to what it started as
	pop hl

	ENDM

MEMBER_PEEK_BYTE: MACRO
; Get the Value in Data->Member and returns Data in HL
; hl <~> Data
; \1 ~> Member

	; Preserve Data address
	push hl

	; Add Member offset to Data address
	ld de, \1
	add hl, de

	; Load Value in to Data->Member
	ld a, [hl]

	; Reset HL to what it started as
	pop hl

	ENDM

MEMBER_PEEK_WORD: MACRO
; Get the Value in Data->Member and returns Data in HL
; hl <~> Data
; \1 ~> Member

	; Preserve Data address
	push hl

	; Add Member offset to Data address
	ld de, \1
	add hl, de

	; Get Value from Data->Member
	ld c, [hl]
	inc hl
	ld b, [hl]

	; Reset HL to what it started as
	pop hl

	ENDM

MEMBER_POKE_BYTE: MACRO
; Sets Data->Member to Value and returns Data in HL
; hl <~> Data
; \1 ~> Member

	; Preserve Data address
	push hl

	; Add Member offset to Data address
	ld de, \1
	add hl, de

	; Load Value in to Data->Member
	ld [hl], a

	; Reset HL to what it started as
	pop hl

	ENDM

MEMBER_POKE_WORD: MACRO
; Sets Data->Member to Value and returns Data in HL
; hl <~> Data
; bc ~> Data
; \1 ~> Member

	; Preserve Data address
	push hl

	; Add Member offset to Data address
	ld de, \1
	add hl, de

	; Load Value in to Data->Member
	ld [hl], c
	inc hl
	ld [hl], b

	; Reset HL to what it started as
	pop hl

	ENDM

MEMBER_BIT: MACRO
; [bit|res|set] the Bit at Data->Member
; hl <~> Data
; \1 ~> bit | res | set
; \2 ~> Member
; \3 ~> Bit

	; Preserve Data address
	push hl

	; Set HL to Data->Member address
	ld de, \2
	add hl, de

	; Do the appropriate bit-centric op on Data->Member[Bit]
	\1 \3, [hl]

	; Reset HL to Data address
	pop hl

	ENDM

ENDC
