; from https://gist.github.com/bhickey/0de228c02cc60b5965582d2d946d8c38,
; based on http://www.retroprogramming.com/2017/07/xorshift-pseudorandom-numbers-in-z80.html
init_random:
        lda $d012   ; Initialize rnd with current rasterline
        bne _l      ; but make sure we don't use 0.
        lda #1
_l      sta rndval

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
