MAIN_SOURCE = petris.asm
SOURCES = ${MAIN_SOURCE} random.asm screens.asm
PROGRAM = petris.prg
TAP = petris.tap
SYMTAB = petris.sym

.PHONY: all clean

all: ${PROGRAM}

clean:
	$(RM) ${PROGRAM} ${TAP} screens.asm pe_screen_extractor screen_to_unicode

run: ${PROGRAM}
	xpet >/dev/null -model 2001 ${PROGRAM}

screens.asm: pe_screen_extractor screens.pe
	./pe_screen_extractor -in=screens.pe -out=screens.asm -screens=main_screen,title_logo,title_controls,title_hiscores -dump_pe=SCREENS_DUMP

pe_screen_extractor: tools/pe_screen_extractor.go
	go build tools/pe_screen_extractor.go

${PROGRAM}: ${SOURCES}
	cbmasm -I include:. -labels ${SYMTAB} ${MAIN_SOURCE} ${PROGRAM}

${TAP}: ${PROGRAM}
	prg2tap -r -n "PETRIS" ${PROGRAM} ${TAP}
