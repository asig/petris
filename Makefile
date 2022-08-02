MAIN_SOURCE = petris.asm
SOURCES = ${MAIN_SOURCE} random.asm
GENERATED_SOURCES = screens.asm build_info.i
PROGRAM = petris.prg
TAP = petris.tap
SYMTAB = petris.sym

.PHONY: all clean

all: ${PROGRAM} ${TAP}

clean:
	$(RM) ${PROGRAM} ${TAP} ${GENERATED_SOURCES} pe_screen_extractor screen_to_unicode

run: ${PROGRAM}
	xpet >/dev/null -model 2001 ${PROGRAM}

screens.asm: pe_screen_extractor screens.pe
	./pe_screen_extractor -in=screens.pe -out=screens.asm -screens=main_screen,title_logo,title_controls,title_hiscores -dump_pe=SCREENS_DUMP

build_info.i: ${SOURCES} screens.pe
	@echo 'build_timestamp	.equ "'$$(date -u --iso-8601=s |  tr [:upper:] [:lower:])'"' > build_info.i

pe_screen_extractor: tools/pe_screen_extractor.go
	go build tools/pe_screen_extractor.go

${PROGRAM}: ${SOURCES} ${GENERATED_SOURCES}
	cbmasm -I include:. -labels ${SYMTAB} ${MAIN_SOURCE} ${PROGRAM}

${TAP}: ${PROGRAM}
	prg2tap -r -n "PETRIS" ${PROGRAM} ${TAP}
