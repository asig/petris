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
word1   .equ    $54 ; $b8
word2   .equ    $56 ; $ba
byte1   .equ    $58
byte2   .equ    $59


; Playfield consts
pf_w    .equ    10
pf_h    .equ    22


; ********************************************************************
; *** ENTRY POINT
; ********************************************************************

	.include "startup.i"

	jsr init_random
	jsr init_scores_and_next_tetromino
	jsr init_playfield
	jsr init_screen


	jsr print_scores
	jsr print_stats
	jsr print_next_tetromino
	jsr draw_playfield

	jsr new_tetromino

	jsr rotate_cur_left
	ldx #3
	ldy #4    
	jsr draw_cur_tetromino

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

init_scores_and_next_tetromino:
	; Clear all the scores and stats
	ldx #(9*2)-1    ; 9x16 bit    
	lda #0
_l  sta score,x
	dex
	bpl _l

	; init next tetromino
	jsr random
	and #7
	cmp #7
	bne _l2
	and #%110
_l2 sta next_tetromino
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
	jmp print_uint16

print_stats:
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

print_next_tetromino:
	lda next_tetromino
	asl
	tax
	lda tetromino_preview,x
	sta vram_stats_next
	lda tetromino_preview+1,x
	sta vram_stats_next+1
	rts


draw_cur_tetromino_set  .macro
	lda (word2),y
	beq _l
	sta (word1), y
_l  iny
	.endm

; Draws the current tetromino (cur_tetromino) on screen
; Input:
;   X: x-coord (within playfield)
;   Y: y-coord (within playfield)
draw_cur_tetromino:
	; compute screen address
	set16i word1, vram_playfield-scr_w  ; Compensate y for center being at (1,1)
	
	; add col offset
	dex     ; Compensate x for center being at (1,1)
	txa
	clc
	adc word1
	sta word1
	lda #0
	adc word1+1
	sta word1+1

	tya
	jsr mul40

	; add row offset
	txa
	clc
	adc word1
	sta word1
	tya
	adc word1+1
	sta word1+1

	set16i word2, cur_tetromino

	ldx #4  ; 4 rows
_l  ldy #0
	draw_cur_tetromino_set
	draw_cur_tetromino_set
	draw_cur_tetromino_set
	draw_cur_tetromino_set
	add16i word1, scr_w
	add16i word2, 4
	dex
	bne _l

	rts


; ********************************************************************
; *** Playfield routines
; ********************************************************************

init_playfield:
	; first, fill whole playfield with $ff

	; Source address to word1
	set16i word1, playfield

	ldx #pf_h+4 ; rows to go
_rl
	lda #$ff
	ldy #pf_w+4-1   ; col index
_cl
	sta (word1),y
	dey
	bpl _cl

	add16i word1, pf_w+4
	dex
	bne _rl

	; now, clear the inner part
	jmp clear_playfield

draw_playfield:
	set16i word1, playfield+2*(pf_w+2+2)+2  ; skip 1st 2 rows, skip 2 cols (sentinels)
	set16i word2, vram_playfield

	ldx #pf_h
_l1
	ldy #pf_w-1
_l2 lda (word1),y
	bne _l3
	lda #scr(' ')
_l3 sta (word2),y
	dey
	bpl _l2

	add16i word1, pf_w+4
	add16i word2, scr_w

	dex
	bne _l1

	rts

clear_playfield:
	; Source address to word1
	set16i word1, playfield+2*(pf_w+2+2)+2  ; skip 1st 2 rows, skip 2 cols (sentinels)

	ldx #pf_h
_rl
	lda #0
	ldy #pf_w-1
_cl    
	sta (word1),y
	dey
	bpl _cl

	add16i word1, pf_w+4
	dex
	bne _rl
	rts

; ********************************************************************
; *** Tetromino routines
; ********************************************************************

; Copy "next_tetromino" to cur_tetromino, and select new next tetromino
; Update stats and next_tetromino
new_tetromino:
	lda next_tetromino
	asl

	; Copy tetromino:
	; ...copy source address to word1
	tax
	lda tetrominos,x
	sta word1
	lda tetrominos+1,x
	sta word1+1

	; ...copy dest address to word2
	set16i word2, cur_tetromino

	; ...finally copy 18 bytes
	ldy #4*4+2
	jsr copy_mem

	; Update stats
	clc
	inc stats,x
	bcc _nooverflow
	inc stats+1,x
_nooverflow

	; Pick a new tetromino
	jsr random
_l  cmp #7
	bcc _done ; less than 7 -> we're good
	sbc #7     
	jmp _l
_done
	sta next_tetromino
	jsr print_stats
	jmp print_next_tetromino
	

rotate_cur_left:
	lda cur_tetromino+0
	sta rotate_buf+3
	lda cur_tetromino+1
	sta rotate_buf+7
	lda cur_tetromino+2
	sta rotate_buf+11
	lda cur_tetromino+3
	sta rotate_buf+15

	lda cur_tetromino+4
	sta rotate_buf+2
	lda cur_tetromino+5
	sta rotate_buf+6
	lda cur_tetromino+6
	sta rotate_buf+10
	lda cur_tetromino+7
	sta rotate_buf+14

	lda cur_tetromino+8
	sta rotate_buf+1
	lda cur_tetromino+9
	sta rotate_buf+5
	lda cur_tetromino+10
	sta rotate_buf+9
	lda cur_tetromino+11
	sta rotate_buf+13

	lda cur_tetromino+12
	sta rotate_buf+0
	lda cur_tetromino+13
	sta rotate_buf+4
	lda cur_tetromino+14
	sta rotate_buf+8
	lda cur_tetromino+15
	sta rotate_buf+12

	set16i word1, rotate_buf
	set16i word2, cur_tetromino
	ldy #16
	jmp copy_mem

rotate_cur_right:
	lda cur_tetromino+0
	sta rotate_buf+12
	lda cur_tetromino+1
	sta rotate_buf+8
	lda cur_tetromino+2
	sta rotate_buf+4
	lda cur_tetromino+3
	sta rotate_buf+0

	lda cur_tetromino+4
	sta rotate_buf+13
	lda cur_tetromino+5
	sta rotate_buf+9
	lda cur_tetromino+6
	sta rotate_buf+5
	lda cur_tetromino+7
	sta rotate_buf+1

	lda cur_tetromino+8
	sta rotate_buf+14
	lda cur_tetromino+9
	sta rotate_buf+10
	lda cur_tetromino+10
	sta rotate_buf+6
	lda cur_tetromino+11
	sta rotate_buf+2

	lda cur_tetromino+12
	sta rotate_buf+15
	lda cur_tetromino+13
	sta rotate_buf+11
	lda cur_tetromino+14
	sta rotate_buf+7
	lda cur_tetromino+15
	sta rotate_buf+3

	set16i word1, rotate_buf
	set16i word2, cur_tetromino
	ldy #16
	jmp copy_mem



rotate_buf:
	.reserve 16

; ********************************************************************
; *** Other routines
; ********************************************************************

	.include "random.asm"


; Multiply accumulator by 40
; Input:
;   A: to by multiplied
; Output:
;   X: LSB of A*40
;   Y: MSB of A*40
mul40:
	asl
	tax
	lda _multab+1,x
	tay
	lda _multab,x
	tax
	rts
_multab .word 0,40,80,120,160,200,240,280,320,360,400,440,480,520,560,600,640,680,720,760,800,840,880,920,960

; ====================================================================
; ==
; == copy non-overlapping memory block
; ==
; == Input: word1: source
; ==        word2: dest
; ==        Y: # of bytes to copy (must be > 0)
; ==
; == Output: -
; ==
; == Invalidates A, Y
; ====================================================================
copy_mem:
	dey
_l  lda (word1),y
	sta (word2),y
	dey
	bne _l
	lda (word1),y
	sta (word2),y
	rts

; ====================================================================
; ==
; == Print 16bit uint (inspired by https://www.beebwiki.mdfs.net/Number_output_in_6502_machine_code)
; ==
; == Input: word1: The number to print
; ==        word2: The screen address to print it to
; ==        [ jumping to xxx_lp1: Y: (number of digits)*2-2, eg 8 for 5 digits ]
; ==
; == Output: -
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

; Scores 
score:  .reserve 2
lines:  .reserve 2
stats:  .reserve 7*2    ; Same order as in "tetrominos" list

playfield:
	.reserve (pf_w+2+2)*(pf_h+2+2) , scr('A')

cur_tetromino_x:    .reserve 1
cur_tetromino_y:    .reserve 1
cur_tetromino:      .reserve 4*4    ; 16 bytes for data
next_tetromino:     .reserve 1

; ********************************************************************
; *** Static data
; ********************************************************************

tetromino_preview: ; 2-byte tetromino previews in screen codes
	.byte $62,$62 ; "I" tetromino
	.byte $7C,$FC ; "Z" tetromino
	.byte $6C,$EC ; "S" tetromino
	.byte $6C,$FC ; "T" tetromino
	.byte $76,$62 ; "J" tetromino
	.byte $6C,$FE ; "L" tetromino
	.byte $E1,$61 ; "O" tetromino

tetrominos:
	.word  tetromino_i, tetromino_z, tetromino_s, tetromino_t, tetromino_j, tetromino_l, tetromino_o

tetromino_i:
	;.byte 4,1
	.byte $00,$00,$00,$00
	.byte $a0,$a0,$a0,$a0
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00

tetromino_z:
	;.byte 3,2
	.byte $00,$00,$00,$00
	.byte $66,$66,$00,$00
	.byte $00,$66,$66,$00
	.byte $00,$00,$00,$00

tetromino_s:
	;.byte 3,2
	.byte $00,$00,$00,$00
	.byte $00,$e6,$e6,$00
	.byte $e6,$e6,$00,$00
	.byte $00,$00,$00,$00

tetromino_t:
	;.byte 3,2
	.byte $00,$00,$00,$00
	.byte $00,$66,$00,$00
	.byte $66,$66,$66,$00
	.byte $00,$00,$00,$00

tetromino_j:
	;.byte 3,2
	.byte $00,$00,$00,$00
	.byte $e6,$00,$00,$00
	.byte $e6,$e6,$e6,$00
	.byte $00,$00,$00,$00

tetromino_l:
	;.byte 3,2
	.byte $00,$00,$00,$00
	.byte $00,$00,$66,$00
	.byte $66,$66,$66,$00
	.byte $00,$00,$00,$00

tetromino_o:
	;.byte 2,2
	.byte $00,$00,$00,$00
	.byte $00,$e6,$e6,$00
	.byte $00,$e6,$e6,$00
	.byte $00,$00,$00,$00


title_screen:
	.byte $00, $5d, $20, $17, $05, $0c, $03, $0f, $0d, $05, $20, $14, $0f, $00, $40, $20, $e1, $00, $02, $a0, $7b, $00, $02, $a0, $61, $00, $0b, $a0, $61, $00, $11, $20, $e1, $61, $20, $e1, $61, $a0, $00, $03, $20, $e1, $61, $00, $1b, $20, $e1, $00, $02, $a0, $7e, $00, $02, $a0, $61, $20, $e1, $61, $e2, $ec, $7e, $ec, $7f, $7c, $ec, $e1, $e2, $00, $12, $20, $e1, $61, $00, $02, $20, $a0, $00, $03, $20, $e1, $61, $20, $61, $20, $fc, $ff, $20, $61, $e1, $62, $00, $12, $20, $e1, $61, $00, $02, $20, $00, $02, $a0, $61, $20, $e1, $61, $20, $61, $20, $61, $e1, $6c, $fc, $20, $e1, $00, $12, $20, $00, $13, $62, $fe, $00, $67, $20, $03, $0f, $0e, $14, $12, $0f, $0c, $13, $00, $ff, $20, $00, $56, $20, $00, $02, $2a, $20, $10, $12, $05, $00, $01, $13, $20, $01, $0e, $19, $20, $0b, $05, $19, $20, $14, $0f, $20, $13, $14, $01, $12, $14, $20, $00, $02, $2a, $00, $5c, $20, $28, $03, $29, $20, $32, $30, $00, $01, $32, $20, $01, $0e, $04, $12, $05, $01, $13, $20, $13, $09, $07, $0e, $05, $12, $00, $08, $20
main_screen:
	.byte $00, $51, $20, $67, $00, $09, $20, $65, $e1, $00, $02, $a0, $7b, $00, $02, $a0, $61, $00, $0b, $a0, $61, $60, $00, $04, $20, $67, $00, $09, $20, $65, $e1, $61, $20, $e1, $61, $a0, $00, $03, $20, $e1, $61, $00, $09, $20, $60, $00, $04, $20, $67, $00, $09, $20, $65, $e1, $00, $02, $a0, $7e, $00, $02, $a0, $61, $20, $e1, $61, $e2, $ec, $7e, $ec, $7f, $7c, $ec, $e1, $e2, $00, $06, $20, $67, $00, $09, $20, $65, $e1, $61, $00, $02, $20, $a0, $00, $03, $20, $e1, $61, $20, $61, $20, $fc, $ff, $20, $61, $e1, $62, $00, $06, $20, $67, $00, $09, $20, $65, $e1, $61, $00, $02, $20, $00, $02, $a0, $61, $20, $e1, $61, $20, $61, $20, $61, $e1, $6c, $fc, $20, $e1, $00, $06, $20, $67, $00, $09, $20, $65, $00, $13, $62, $fe, $00, $06, $20, $67, $00, $09, $20, $65, $00, $1b, $20, $67, $00, $09, $20, $65, $55, $00, $04, $40, $49, $20, $55, $00, $04, $40, $49, $20, $55, $00, $03, $40, $49, $00, $05, $20, $67, $00, $09, $20, $65, $5d, $13, $03, $0f, $12, $05, $5d, $20, $5d, $0c, $09, $0e, $05, $13, $5d, $20, $5d, $0e, $05, $18, $14, $5d, $00, $05, $20, $67, $00, $09, $20, $65, $6b, $00, $04, $40, $73, $20, $6b, $00, $04, $40, $73, $20, $6b, $00, $03, $40, $73, $00, $05, $20, $67, $00, $09, $20, $65, $5d, $00, $04, $20, $5d, $20, $5d, $00, $04, $20, $5d, $20, $5d, $00, $03, $20, $5d, $00, $03, $20, $00, $01, $60, $67, $00, $09, $20, $65, $4a, $00, $04, $40, $4b, $20, $4a, $00, $04, $40, $4b, $20, $4a, $00, $03, $40, $4b, $00, $03, $20, $00, $01, $60, $67, $00, $09, $20, $65, $55, $00, $04, $40, $49, $00, $06, $20, $00, $05, $60, $00, $01, $20, $00, $05, $60, $67, $00, $09, $20, $65, $5d, $13, $14, $01, $14, $13, $5d, $00, $07, $20, $00, $04, $60, $00, $01, $20, $00, $03, $60, $20, $60, $67, $00, $09, $20, $65, $6b, $00, $04, $40, $71, $72, $00, $05, $40, $72, $00, $05, $40, $49, $00, $02, $60, $20, $00, $01, $60, $67, $00, $09, $20, $65, $5d, $00, $01, $62, $00, $03, $20, $5d, $7c, $fc, $00, $03, $20, $5d, $6c, $ec, $00, $03, $20, $5d, $00, $05, $60, $67, $00, $09, $20, $65, $5d, $00, $05, $20, $5d, $00, $05, $20, $5d, $60, $20, $00, $03, $60, $5d, $00, $05, $60, $67, $00, $09, $20, $65, $5d, $6c, $fc, $00, $03, $20, $5d, $76, $62, $00, $03, $20, $5d, $6c, $fe, $00, $03, $20, $5d, $00, $04, $60, $20, $67, $00, $09, $20, $65, $5d, $00, $05, $20, $5d, $00, $05, $20, $5d, $60, $20, $00, $03, $60, $5d, $00, $01, $60, $20, $00, $02, $60, $67, $00, $09, $20, $65, $5d, $e1, $61, $00, $03, $20, $5d, $00, $05, $60, $5d, $60, $20, $00, $03, $60, $5d, $00, $05, $60, $67, $00, $09, $20, $65, $4a, $00, $05, $40, $71, $00, $05, $40, $71, $00, $05, $40, $4b, $00, $03, $60, $00, $01, $20, $67, $00, $09, $20, $65, $28, $03, $29, $20, $32, $30, $00, $01, $32, $20, $01, $0e, $04, $12, $05, $01, $13, $20, $13, $09, $07, $0e, $05, $12, $00, $05, $20, $00, $09, $63, $00, $1a, $20
