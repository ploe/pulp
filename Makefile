project = pulp

# all: gfx asm link fix
all: png fix

%.o: ./src/%.asm
	rgbasm -i ./include/ -o $@ $<

%.2bpp: ./png/%.png
	rgbgfx -hu -o $@ $<

clean:
	rm -v *.o *.2bpp $(project).gb $(project).sav $(project).sym

fix: $(project).gb
	rgbfix -j -l 0x33 -m 0x1B -n 0 -p 0xFF -r 0x03 -v $(project).gb

png: blob.2bpp hero.2bpp

$(project).gb: blob.o display.o entrypoint.o kernel.o actor.o
	rgblink -n $(project).sym -o $(project).gb $^
