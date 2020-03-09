project = stix

# all: gfx asm link fix
all: png fix

%.o: ./src/%.asm
	rgbasm -i ./include/ -o $@ $<

%.2bpp: ./png/%.png
	rgbgfx -hu -o $@ $<

clean:
	rm -v *.o *.2bpp

fix: $(project).gb
	rgbfix -v -p 0 -m 0x10 -n 0x06 -r 0x03 $(project).gb

png: blob.2bpp hero.2bpp

$(project).gb: display.o entrypoint.o kernel.o process.o
	rgblink -n $(project).sym -o $(project).gb $^
