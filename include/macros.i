; Copyright (c) 2022 Andreas Signer <asigner@gmail.com>
;
; This file is part of petris.
;
; petris is free software: you can redistribute it and/or
; modify it under the terms of the GNU General Public License as
; published by the Free Software Foundation, either version 3 of the
; License, or (at your option) any later version.
;
; petris is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with petris.  If not, see <http://www.gnu.org/licenses/>.

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

add16m  .macro addr1, addr2
        clc
        lda addr1
        adc addr2
        sta addr1
        lda addr1+1
        adc addr2+1
        sta addr1+1
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

lsl16m  .macro addr
        asl addr
        rol addr+1
        .endm

lsr16m  .macro addr
        lsr addr+1
        ror addr
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
