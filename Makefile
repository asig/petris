MAIN_SOURCE = petris.asm
SOURCES = ${MAIN_SOURCE} random.asm screens.asm
PROGRAM = petris.prg
SYMTAB = petris.sym

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


all: ${PROGRAM}

clean:
	$(RM) ${PROGRAM}

run: ${PROGRAM}
	xpet >/dev/null -model 2001 ${PROGRAM}

${PROGRAM}: ${SOURCES}
	cbmasm -listing  -labels ${SYMTAB} ${MAIN_SOURCE} ${PROGRAM}
