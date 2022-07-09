SOURCES = pet-tris.asm

PROGRAM = pet-tris

# CC = cc65
# AS = ca65
# LD = ld65

# CFLAGS = -O -t $(TARGET)
# LDFLAGS = -t $(TARGET)
# ASFLAGS = -t $(TARGET)
# LIBS = $(TARGET).lib

# OBJS = $(SOURCES:.c=.o) $(SOURCES_ASM:.s=.o)

.SUFFIXES:
.PHONY: all clean
.PRECIOUS: %.s


all: pet-tris.prg

clean:
	$(RM) pet-tris.prg

run: pet-tris.prg
	xpet -model 2001 pet-tris.prg

pet-tris.prg: pet-tris.asm
	cbmasm -listing pet-tris.asm pet-tris.prg
