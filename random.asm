; from https://gist.github.com/bhickey/0de228c02cc60b5965582d2d946d8c38,
; based on http://www.retroprogramming.com/2017/07/xorshift-pseudorandom-numbers-in-z80.html

; ====================================================================
; ==
; == Initialize RNG
; ==
; == Input: -
; == Output: -
; == Invalidates: A
; ====================================================================

	.if PLATFORM = "pet"
rnd_src	.equ $202	; jiffy clock LSB
	.else ; Just assume that it's C64 or C128
rnd_src	.equ $d012	; current raster line
	.endif

init_random:
        ldx rnd_src ; Initialize rnd from current source of randomness
        bne _l      ; but make sure we don't use 0.
        inx
_l      stx rndval

; ====================================================================
; ==
; == Get the next random number
; ==
; == Input: -
; == Output: A: random number
; == Invalidates A
; ====================================================================

random:
        lda rndval
        asl a
        eor rndval
        sta rndval
        lsr a
        eor rndval
        sta rndval
        asl a
        asl a
        eor rndval
        sta rndval
        rts
rndval: .reserve 1
