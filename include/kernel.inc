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

MEMBER_SET_W: MACRO
; Sets Data->Member to Value and returns Data in HL
; hl ~> Data
; \1 ~> Member
; \2 ~> Value

	ld de, \1
	ld bc, \2
	call Kernel_MemberSetW

	ENDM


ENDC
