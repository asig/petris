MAIN_SOURCE = petris.asm
SOURCES = ${MAIN_SOURCE} random.asm screens.asm
PROGRAM = petris.prg
SYMTAB = petris.sym

.PHONY: all clean

all: ${PROGRAM}

clean:
	$(RM) ${PROGRAM} screens.asm pe_screen_extractor

run: ${PROGRAM}
	xpet >/dev/null -model 2001 ${PROGRAM}

screens.asm: pe_screen_extractor screens.pe
	./pe_screen_extractor -in=screens.pe -out=screens.asm -screens=main_screen,title_screen,hiscores_screen

pe_screen_extractor: pe_screen_extractor.go
	go build pe_screen_extractor.go

${PROGRAM}: ${SOURCES}
	cbmasm -listing  -labels ${SYMTAB} ${MAIN_SOURCE} ${PROGRAM}
