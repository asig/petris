set16i  .macro addr, val
        lda #<(val)
        sta addr
        lda #>(val)
        sta addr+1
        .endm

set16m  .macro dest, src
        lda src
        sta dest
        lda src+1
        sta dest+1
        .endm

inc16   .macro addr
        inc addr
        bne _l
        inc addr+1
_l
        .endm

dec16   .macro addr
		lda addr
		bne _l
		dec addr+1
_l		dec addr
		.endm

add16i  .macro addr, val
        clc
        lda addr
        adc #<(val)
        sta addr
        lda addr+1
        adc #>(val)
        sta addr+1
        .endm

sub16i  .macro addr, val
        sec
        lda addr
        sbc #<(val)
        sta addr
        lda addr+1
        sbc #>(val)
        sta addr+1
        .endm

pushx	.macro
	txa
	pha
	.endm

popx	.macro
	pla
	tax
	.endm
	
push16m	.macro addr
	lda addr
	pha
	lda addr+1
	pha
	.endm

pop16m	.macro addr
	pla
	sta addr+1
	pla
	sta addr
	.endm
