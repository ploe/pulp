; hardware.inc
INCLUDE "hardware.inc"

; project libs
INCLUDE "actor.inc"
INCLUDE "controller.inc"
INCLUDE "display.inc"
INCLUDE "kernel.inc"
INCLUDE "oam.inc"

SECTION "Daisy Code", ROM0

; Public interface for Blob
RSRESET
DAISY_ACTOR RB ACTOR_SIZE
DAISY_SPRITE RB SPRITE_SIZE
BLOB_SIZE RB 0

Daisy_Spritesheet:
INCBIN "daisy.2bpp"
Daisy_Spritesheet_End:
BLOB_SHEET_SIZE EQU BLOB_SHEET_END-BLOB_SHEET

Daisy_Animate:

	YIELD
