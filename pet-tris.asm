; Copyright (c) 2022 Andreas Signer <asigner@gmail.com>
;
; This file is part of cbmasm.
;
; cbmasm is free software: you can redistribute it and/or
; modify it under the terms of the GNU General Public License as
; published by the Free Software Foundation, either version 3 of the
; License, or (at your option) any later version.
;
; cbmasm is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with cbmasm.  If not, see <http://www.gnu.org/licenses/>.
;

    .platform "pet"
    .cpu "6502"

    .include "macros.i"


; ********************************************************************
; *** Constants
; ********************************************************************

scr_w   .equ    40
vram    .equ    $8000

vram_playfield      .equ    vram +  2 * scr_w +  3
vram_stats_score    .equ    vram + 12 * scr_w + 15
vram_stats_lines    .equ    vram + 12 * scr_w + 23
vram_stats_next     .equ    vram + 12 * scr_w + 32
vram_stats_t_i      .equ    vram + 17 * scr_w + 18
vram_stats_t_z      .equ    vram + 19 * scr_w + 18
vram_stats_t_s      .equ    vram + 21 * scr_w + 18
vram_stats_t_t      .equ    vram + 17 * scr_w + 25
vram_stats_t_j      .equ    vram + 19 * scr_w + 25
vram_stats_t_l      .equ    vram + 17 * scr_w + 32
vram_stats_t_o      .equ    vram + 19 * scr_w + 32


; Zeropage addresses used to pass params
word1    .equ    $b8
word2    .equ    $ba


; Playfield consts
pf_w    .equ    10
pf_h    .equ    22


; ********************************************************************
; *** ENTRY POINT
; ********************************************************************

    .include "startup.i"

    jsr init_scores
    jsr init_screen


    jsr print_scores
    jsr draw_playfield


    rts

    lda #$53
    sta $8000
    sta $8001
    sta $8002
    jsr draw_playfield
    rts

; ********************************************************************
; *** Init
; ********************************************************************

init_scores:
    rts
    ldx #(9*2)    ; 9x16 bit    
    lda #0
_l  sta score,x
    dex
    bpl _l
    rts

init_screen:
    set16i word1, main_screen
    set16i word2, vram

_next
    ldy #0
    lda (word1),y
    beq _run
    ; Not a run, just store byte in 
    sta (word2),y    
    
    inc16 word1
    inc16 word2

    jmp _end

_run
    iny
    lda (word1),y
    clc
    adc #1
    sta _len
    iny
    lda (word1),y

    ldy _len
_l  sta (word2),y
    dey
    bne _l
    sta (word2),y ; also store the 0th byte

    ; Increment vram pointer by adding _len
    clc
    lda word2
    adc _len
    sta word2
    lda word2+1
    adc #0
    sta word2+1

    ; increment source pointer
    add16i word1, 3

_end 
    ; check whether we're at the end of vram
    lda #<(vram+1000)
    cmp word2
    bne _next
    lda #>(vram+1000)
    cmp word2+1
    bne _next
    rts
_len .reserve 1

; ********************************************************************
; *** Screen updates
; ********************************************************************

print_scores:
    set16m word1, score
    set16i word2, vram_stats_score
    jsr print_uint16

    set16m word1, lines
    set16i word2, vram_stats_lines
    jsr print_uint16

    set16m word1, stats
    set16i word2, vram_stats_t_i
    ldy #4  ; 3 digits
    jsr print_uint16_lp1

    set16m word1, stats+2
    set16i word2, vram_stats_t_z
    ldy #4  ; 3 digits
    jsr print_uint16_lp1

    set16m word1, stats+4
    set16i word2, vram_stats_t_s
    ldy #4  ; 3 digits
    jsr print_uint16_lp1

    set16m word1, stats+6
    set16i word2, vram_stats_t_t
    ldy #4  ; 3 digits
    jsr print_uint16_lp1

    set16m word1, stats+8
    set16i word2, vram_stats_t_j
    ldy #4  ; 3 digits
    jsr print_uint16_lp1

    set16m word1, stats+10
    set16i word2, vram_stats_t_l
    ldy #4  ; 3 digits
    jsr print_uint16_lp1

    set16m word1, stats+12
    set16i word2, vram_stats_t_o
    ldy #4  ; 3 digits
    jmp print_uint16_lp1


; ********************************************************************
; *** Playfield routines
; ********************************************************************

draw_playfield:
    set16i word1, playfield
    set16i word2, vram_playfield

    ldx #pf_h
_l1
    ldy #pf_w-1
_l2 lda (word1),y
    sta (word2),y
    dey
    bpl _l2

    lda word2
    clc
    adc #scr_w
    sta word2
    lda word2+1
    adc #0
    sta word2+1

    dex
    bne _l1

    rts

clear_playfield:
    ; Source address to word1
    lda #<playfield
    sta word1
    lda #>playfield
    sta word1+1

    ;lda #scr('A')
    ldy #pf_w*pf_h-1
_l  sta (word1),y
    dey
    bpl _l
    rts

; ********************************************************************
; *** Tetromino routines
; ********************************************************************

rotate_cur_left:
    rts

rotate_cur_right:
    rts

buf_to_cur:

rotate_buf:
    .reserve 16

; ********************************************************************
; *** Other routines
; ********************************************************************

    .include "random.asm"



; ====================================================================
; ==
; == Print 16bit uint (inspired by https://www.beebwiki.mdfs.net/Number_output_in_6502_machine_code)
; ==
; == Input: word1: The number to print
; ==        word2: The screen address to print it to
; ==        [ jumping to xxx_lp1: Y: (number of digits)*2-2, eg 8 for 5 digits ]
; ==
; == Invalidates A, X, Y
; ====================================================================

print_uint16:
    ldy #8      ; Offset to powers of ten
print_uint16_lp1
    lda #0
    sta _pad    ; start with padding
    sta _pos    ; screen offset 0
_next
    ldx #$ff
    sec         ; start with -1
_l  lda word1+0 ; subtract current tens
    sbc _tens+0, y
    sta word1+0 
    lda word1+1
    sbc _tens+1, y
    sta word1+1
    inx
    bcs _l
    lda word1+0 ; add the current tens back in
    adc _tens+0, y
    sta word1+0
    lda word1+1
    adc _tens+1, y
    sta word1+1
    txa
    bne _digit  ; Not zero, print it
    lda _pad
    bne _digit      ; No padding, print digit
    tya
    cmp #0              ; is it the last digit?
    bne _notlastdigit   ; no, continue padding with ' '
    lda #scr('0')       ; otherwise, print '0'
    bne _print          
_notlastdigit
    lda #scr(' ')   ; padding: print ' '
    bne _print  
_digit
    ora #scr('0')   ; add "0"
    sta _pad        ; no padding anymore after first digit
_print
    sty _save
    ldy _pos
    sta (word2),y
    inc _pos
    ldy _save
_2  dey
    dey
    bpl _next   ; loop for next digit
    rts
_pad .reserve 1
_pos .reserve 1
_save .reserve 1
_tens    
    .word 1
    .word 10
    .word 100
    .word 1000
    .word 10000


; ********************************************************************
; *** Variables
; ********************************************************************

score:  .reserve 2
lines:  .reserve 2
stats:  .reserve 7*2    ; Same order as in "tetriminos" list


playfield:
    .reserve pf_w*pf_h , scr('A')

cur_tetrimino_x:
    .reserve 1

cur_tetrimino_y:
    .reserve 1

cur_tetrimino:
    .reserve 1+1+6  ; 2 bytes for size, and max 6 bytes for data

; ********************************************************************
; *** Static data
; ********************************************************************

tetriminos:
    .word  tetrimino_i, tetrimino_z, tetrimino_s, tetrimino_t, tetrimino_j, tetrimino_l, tetrimino_o


tetrimino_i:
    .byte 4,1
    .byte 0,0,0,0
    .byte 1,1,1,1
    .byte 0,0,0,0
    .byte 0,0,0,0

tetrimino_z:
    .byte 3,2
    .byte 0,0,0,0
    .byte 1,1,0,0
    .byte 0,1,1,0
    .byte 0,0,0,0

tetrimino_s:
    .byte 3,2
    .byte 0,0,0,0
    .byte 0,1,1,0
    .byte 1,1,0,0
    .byte 0,0,0,0

tetrimino_t:
    .byte 3,2
    .byte 0,0,0,0
    .byte 0,1,0,0
    .byte 1,1,1,0
    .byte 0,0,0,0

tetrimino_j:
    .byte 3,2
    .byte 0,0,0,0
    .byte 1,0,0,0
    .byte 1,1,1,0
    .byte 0,0,0,0

tetrimino_l:
    .byte 3,2
    .byte 0,0,0,0
    .byte 0,0,1,0
    .byte 1,1,1,0
    .byte 0,0,0,0

tetrimino_o:
    .byte 2,2
    .byte 0,0,0,0
    .byte 0,1,1,0
    .byte 0,1,1,0
    .byte 0,0,0,0


main_screen:
    .byte $00, $51, $20, $67, $00, $09, $20, $65, $e1, $00, $02, $a0, $7b, $00, $02, $a0, $61, $00, $0b, $a0, $61, $60, $00, $04, $20, $67, $00, $09, $20, $65, $e1, $61, $20, $e1, $61, $a0, $00, $03, $20, $e1, $61, $00, $09, $20, $60, $00, $04, $20, $67, $00, $09, $20, $65, $e1, $00, $02, $a0, $7e, $00, $02, $a0, $61, $20, $e1, $61, $e2, $ec, $7e, $ec, $7f, $7c, $ec, $e1, $e2, $00, $06, $20, $67, $00, $09, $20, $65, $e1, $61, $00, $02, $20, $a0, $00, $03, $20, $e1, $61, $20, $61, $20, $fc, $ff, $20, $61, $e1, $62, $00, $06, $20, $67, $00, $09, $20, $65, $e1, $61, $00, $02, $20, $00, $02, $a0, $61, $20, $e1, $61, $20, $61, $20, $61, $e1, $6c, $fc, $20, $e1, $00, $06, $20, $67, $00, $09, $20, $65, $00, $13, $62, $fe, $00, $06, $20, $67, $00, $09, $20, $65, $00, $1b, $20, $67, $00, $09, $20, $65, $55, $00, $04, $40, $49, $20, $55, $00, $04, $40, $49, $20, $55, $00, $03, $40, $49, $00, $05, $20, $67, $00, $09, $20, $65, $5d, $13, $03, $0f, $12, $05, $5d, $20, $5d, $0c, $09, $0e, $05, $13, $5d, $20, $5d, $0e, $05, $18, $14, $5d, $00, $05, $20, $67, $00, $09, $20, $65, $6b, $00, $04, $40, $73, $20, $6b, $00, $04, $40, $73, $20, $6b, $00, $03, $40, $73, $00, $05, $20, $67, $00, $09, $20, $65, $5d, $00, $04, $20, $5d, $20, $5d, $00, $04, $20, $5d, $20, $5d, $00, $03, $20, $5d, $00, $03, $20, $00, $01, $60, $67, $00, $09, $20, $65, $4a, $00, $04, $40, $4b, $20, $4a, $00, $04, $40, $4b, $20, $4a, $00, $03, $40, $4b, $00, $03, $20, $00, $01, $60, $67, $00, $09, $20, $65, $55, $00, $04, $40, $49, $00, $06, $20, $00, $05, $60, $00, $01, $20, $00, $05, $60, $67, $00, $09, $20, $65, $5d, $13, $14, $01, $14, $13, $5d, $00, $07, $20, $00, $04, $60, $00, $01, $20, $00, $03, $60, $20, $60, $67, $00, $09, $20, $65, $6b, $00, $04, $40, $71, $72, $00, $05, $40, $72, $00, $05, $40, $49, $00, $02, $60, $20, $00, $01, $60, $67, $00, $09, $20, $65, $5d, $00, $01, $62, $00, $03, $20, $5d, $7c, $fc, $00, $03, $20, $5d, $6c, $ec, $00, $03, $20, $5d, $00, $05, $60, $67, $00, $09, $20, $65, $5d, $00, $05, $20, $5d, $00, $05, $20, $5d, $60, $20, $00, $03, $60, $5d, $00, $05, $60, $67, $00, $09, $20, $65, $5d, $6c, $fc, $00, $03, $20, $5d, $76, $62, $00, $03, $20, $5d, $6c, $fe, $00, $03, $20, $5d, $00, $04, $60, $20, $67, $00, $09, $20, $65, $5d, $00, $05, $20, $5d, $00, $05, $20, $5d, $60, $20, $00, $03, $60, $5d, $00, $01, $60, $20, $00, $02, $60, $67, $00, $09, $20, $65, $5d, $e1, $61, $00, $03, $20, $5d, $00, $05, $60, $5d, $60, $20, $00, $03, $60, $5d, $00, $05, $60, $67, $00, $09, $20, $65, $4a, $00, $05, $40, $71, $00, $05, $40, $71, $00, $05, $40, $4b, $00, $03, $60, $00, $01, $20, $67, $00, $09, $20, $65, $28, $03, $29, $20, $32, $30, $00, $01, $32, $20, $01, $0e, $04, $12, $05, $01, $13, $20, $13, $09, $07, $0e, $05, $12, $00, $05, $20, $00, $09, $63, $00, $1a, $20
