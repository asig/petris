MAIN_SOURCE = petris.asm
SOURCES = ${MAIN_SOURCE} random.asm
INCLUDES = include/macros.i include/startup.i
GENERATED_SOURCES = screens.asm include/build_info.i
PROGRAM = petris.prg
TAP = petris.tap
SYMTAB = petris.sym

.PHONY: all clean

all: ${PROGRAM} ${TAP}

clean:
	$(RM) ${PROGRAM} ${TAP} ${GENERATED_SOURCES} ${SYMTAB} pe_screen_extractor screen_to_unicode

run: ${PROGRAM}
	xpet >/dev/null -model 2001 ${PROGRAM}

screens.asm: pe_screen_extractor screens.pe
	./pe_screen_extractor -in=screens.pe -out=screens.asm -screens=main_screen,title_logo,title_controls,title_hiscores

include/build_info.i: ${SOURCES} ${INCLUDES} screens.pe
	@echo 'build_timestamp	.equ "'$$(date -u --iso-8601=s |  tr [:upper:] [:lower:])'"' > include/build_info.i

pe_screen_extractor: tools/pe_screen_extractor.go
	go build tools/pe_screen_extractor.go

${PROGRAM}: ${SOURCES} ${GENERATED_SOURCES} ${INCLUDES}
	cbmasm -I include:. -labels ${SYMTAB} ${MAIN_SOURCE} ${PROGRAM}

${TAP}: ${PROGRAM}
	prg2tap -r -n "PETRIS" ${PROGRAM} ${TAP}
