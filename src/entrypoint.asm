SECTION "Header", ROM0[$100]
; Gameboy starts reading ROM code from address $100
	di ; disable interrupts
	call Kernel_Init ; we init everything
	jp Kernel_Main ; then we yield control over to the kernel

; rgbfix populates the ROM headers, at these addresses
; so we ensure they're blank
REPT $150 - $104
	db 0
ENDR
