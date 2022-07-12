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

DEBUG	.equ 1

	.platform "pet"
	.cpu "6502"

	.include "macros.i"


; ********************************************************************
; *** Constants and memory addresses
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

via	.equ $E840
via_portb	.equ via

curkey	.equ $203

; Zeropage addresses used to pass params
word1   .equ    $54 ; $b8
word2   .equ    $56 ; $ba
byte1   .equ    $58
byte2   .equ    $59

; Playfield consts
pf_w    .equ    10
pf_h    .equ    22

; Key codes
key_left	.equ 48 ; 'A' key
key_right	.equ 47	; 'D' key
key_down	.equ 44	; 'S' key
key_rotate	.equ 27	; Return key
key_pause	.equ 52	; 'P' key
key_quit	.equ 4	; Run/stop key

; Default initial fall delay
inital_fall_delay	.equ	30

; ********************************************************************
; *** ENTRY POINT
; ********************************************************************

	.include "startup.i"

	jsr init_random
	jmp main_game
	rts


; ********************************************************************
; *** MAIN GAME LOOP
; ********************************************************************
last_key	.reserve 1
main_game:
	jsr init_scores_and_next_tetromino
	jsr init_playfield
	jsr init_screen
	jsr new_tetromino
	lda #inital_fall_delay
	sta cur_fall_delay
	sta cur_fall_cnt

	lda #$ff
	sta last_key

_loop
	jsr wait_vbl

	lda curkey
	cmp last_key
	beq _cont	; Same key still pressed
	sta last_key
	cmp #$ff
	beq _cont	; No key pressed

	; Key pressed: Handle it!
	cmp #key_left
	bne _c1
	jsr handle_left
	jmp _cont
_c1	cmp #key_right
	bne _c2
	jsr handle_right
	jmp _cont
_c2	cmp #key_down
	bne _c3
	jsr handle_down
_c3	cmp #key_rotate
	bne _c4
	jsr handle_rotate
	jmp _cont
_c4	cmp #key_pause
	bne _c5
	jsr handle_pause
	jmp _cont
_c5	cmp #key_quit
	bne _c6
	jsr handle_quit
	bcc _cont
	; TODO jump title

_c6
_cont
	.ifdef DEBUG
	; print out key
	lda last_key
	sta word1
	lda #0
	sta word1+1
	set16i word2, vram
	ldy #4  ; 3 digits
	jsr print_uint16_lp1
	.endif

	; Update scores and stats
	jsr print_scores
	jsr print_stats
	jsr print_next_tetromino

	jsr set_tetromino_in_pf
	jsr draw_playfield
	jsr remove_tetromino_from_pf

	.ifdef DEBUG
	; print out tetromino pos
	lda cur_tetromino_x
	sta word1
	lda #0
	sta word1+1
	set16i word2, vram+scr_w
	ldy #4  ; 3 digits
	jsr print_uint16_lp1

	lda cur_tetromino_y
	sta word1
	lda #0
	sta word1+1
	set16i word2, vram+scr_w + 4
	ldy #4  ; 3 digits
	jsr print_uint16_lp1
	.endif 

	jmp _loop

;	jsr print_scores
;	jsr print_stats
;	jsr print_next_tetromino
;
;	jsr set_tetromino_in_pf
;	jsr draw_playfield
;	jsr remove_tetromino_from_pf
;
;	rts


handle_left:
	dec cur_tetromino_x
	jsr test_tetromino_fits
	bcs _nofit
	rts
_nofit
	inc cur_tetromino_x
	rts

handle_right:
	inc cur_tetromino_x
	jsr test_tetromino_fits
	bcs _nofit
	rts
_nofit
	dec cur_tetromino_x
	rts

handle_down:
	rts

handle_rotate:
	rts

handle_pause:
	rts

handle_quit:
	; Set C flag to signal "quit"
	sec
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
; at (cur_tetromino_x, cur_tetromino_y)
; Input: -
draw_cur_tetromino:
	; compute screen address
	set16i word1, vram_playfield

	; add col offset
	lda cur_tetromino_x
	clc
	adc word1
	sta word1
	lda #0
	adc word1+1
	sta word1+1

	; add row offset
	lda cur_tetromino_y
	jsr mul40
	txa
	clc
	adc word1
	sta word1
	tya
	adc word1+1
	sta word1+1

	.ifdef DEBUG
	set16m tmp, word1
	.endif

	sub16i word1, scr_w+1	; compensate for origin being at (1,1)

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

	.ifdef DEBUG
	set16m word1, tmp
	ldy #0
	lda #$53
	sta (word1),y
	.endif

	rts



set_tetromino_in_pf_elem  .macro
	lda (word2),y
	beq _l
	sta (word1), y
_l  iny
	.endm

	.ifdef DEBUG
tmp .reserve 2
	.endif

; Sets the current tetromino (cur_tetromino) in the playfield
; at (cur_tetromino_x, cur_tetromino_y). No checks are performed
; whether it fits.
; Input: -
set_tetromino_in_pf:
	; compute pf address
	set16i word1, playfield+2*(pf_w+4)+2	; 2-byte sentinels around the whole playfield
	
	; add col offset
	lda cur_tetromino_x
	clc
	adc word1
	sta word1
	lda #0
	adc word1+1
	sta word1+1

	; add row offset
	lda cur_tetromino_y
	jsr mulPlayfieldW
	txa
	clc
	adc word1
	sta word1
	tya
	adc word1+1
	sta word1+1

	sub16i word1, (pf_w+4)+1	; compensate for origin being at (1,1)
	set16i word2, cur_tetromino

	ldx #4  ; 4 rows
_l  ldy #0
	set_tetromino_in_pf_elem
	set_tetromino_in_pf_elem
	set_tetromino_in_pf_elem
	set_tetromino_in_pf_elem
	add16i word1, pf_w+4
	add16i word2, 4
	dex
	bne _l

	rts

remove_tetromino_from_pf_elem  .macro
	lda (word2),y
	beq _l
	lda #0
	sta (word1), y
_l  iny
	.endm


; Removes the current tetromino (cur_tetromino) from the playfield
; at (cur_tetromino_x, cur_tetromino_y). No checks are performed
; whether it fits.
; Input: -
remove_tetromino_from_pf:
	; compute pf address
	set16i word1, playfield+2*(pf_w+4)+2	; 2-byte sentinels around the whole playfield
	
	; add col offset
	lda cur_tetromino_x
	clc
	adc word1
	sta word1
	lda #0
	adc word1+1
	sta word1+1

	; add row offset
	lda cur_tetromino_y
	jsr mulPlayfieldW
	txa
	clc
	adc word1
	sta word1
	tya
	adc word1+1
	sta word1+1

	sub16i word1, (pf_w+4)+1	; compensate for origin being at (1,1)
	set16i word2, cur_tetromino

	ldx #4  ; 4 rows
_l  ldy #0
	remove_tetromino_from_pf_elem
	remove_tetromino_from_pf_elem
	remove_tetromino_from_pf_elem
	remove_tetromino_from_pf_elem
	add16i word1, pf_w+4
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
	set16i word1, playfield+2*(pf_w+4)+2  ; skip 1st 2 rows, skip 2 cols (sentinels)
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

test_tetromino_fits_pixel  .macro
	lda (word2),y
	and (word1),y
	beq _l
	; Tetromino pixel set AND playfield pixel set -> no fit
	sec
	rts
_l  iny
	.endm

; Tests if the current tetromino (cur_tetromino) fits into the playfield
; at (cur_tetromino_x, cur_tetromino_y)
; Input: (coords in cur_tetromino_x, cur_tetromino_y)
; Output:
;   C-Flag set: Tetromino does not fit
;   C-Flag cleared: Tetromino fits
test_tetromino_fits:
	; compute pf address
	set16i word1, playfield+2*(pf_w+4)+2	; 2-byte sentinels around the whole playfield
	
	; add col offset
	lda cur_tetromino_x
	clc
	adc word1
	sta word1
	lda #0
	adc word1+1
	sta word1+1

	; add row offset
	lda cur_tetromino_y
	jsr mulPlayfieldW
	txa
	clc
	adc word1
	sta word1
	tya
	adc word1+1
	sta word1+1

	sub16i word1, (pf_w+4)+1	; compensate for origin being at (1,1)
	set16i word2, cur_tetromino

	ldx #4  ; 4 rows
_l  ldy #0
	test_tetromino_fits_pixel
	test_tetromino_fits_pixel
	test_tetromino_fits_pixel
	test_tetromino_fits_pixel
	add16i word1, pf_w+4
	add16i word2, 4
	dex
	bne _l
	
	; Still here? So it fits!
	clc
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

	; ...finally copy 16 bytes
	ldy #4*4
	jsr copy_mem

	; Update stats
	clc
	inc stats,x
	bcc _nooverflow
	inc stats+1,x
_nooverflow

	; set position
	lda #(pf_w-3)/2
	sta cur_tetromino_x
	lda #0
	sta cur_tetromino_y

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
	ldy #4*4
	jmp copy_mem

;rotate_cur_right:
;	lda cur_tetromino+0
;	sta rotate_buf+12
;	lda cur_tetromino+1
;	sta rotate_buf+8
;	lda cur_tetromino+2
;	sta rotate_buf+4
;	lda cur_tetromino+3
;	sta rotate_buf+0
;
;	lda cur_tetromino+4
;	sta rotate_buf+13
;	lda cur_tetromino+5
;	sta rotate_buf+9
;	lda cur_tetromino+6
;	sta rotate_buf+5
;	lda cur_tetromino+7
;	sta rotate_buf+1
;
;	lda cur_tetromino+8
;	sta rotate_buf+14
;	lda cur_tetromino+9
;	sta rotate_buf+10
;	lda cur_tetromino+10
;	sta rotate_buf+6
;	lda cur_tetromino+11
;	sta rotate_buf+2
;
;	lda cur_tetromino+12
;	sta rotate_buf+15
;	lda cur_tetromino+13
;	sta rotate_buf+11
;	lda cur_tetromino+14
;	sta rotate_buf+7
;	lda cur_tetromino+15
;	sta rotate_buf+3
;
;	set16i word1, rotate_buf
;	set16i word2, cur_tetromino
;	ldy #4*4
;	jmp copy_mem
;


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

; Multiply accumulator by playfield width including sentinel
; Input:
;   A: to by multiplied (0 <= A < pf_h+4)
; Output:
;   X: LSB of A*(pf_w+2+2)
;   Y: MSB of A*(pf_w+2+2)
mulPlayfieldW:
	asl
	tax
	lda _multab+1,x
	tay
	lda _multab,x
	tax
	rts
_multab 
	.word  0 * (pf_w+2+2)
	.word  1 * (pf_w+2+2)
	.word  2 * (pf_w+2+2)
	.word  3 * (pf_w+2+2)
	.word  4 * (pf_w+2+2)
	.word  5 * (pf_w+2+2)
	.word  6 * (pf_w+2+2)
	.word  7 * (pf_w+2+2)
	.word  8 * (pf_w+2+2)
	.word  9 * (pf_w+2+2)
	.word 10 * (pf_w+2+2)
	.word 11 * (pf_w+2+2)
	.word 12 * (pf_w+2+2)
	.word 13 * (pf_w+2+2)
	.word 14 * (pf_w+2+2)
	.word 15 * (pf_w+2+2)
	.word 16 * (pf_w+2+2)
	.word 17 * (pf_w+2+2)
	.word 18 * (pf_w+2+2)
	.word 19 * (pf_w+2+2)
	.word 20 * (pf_w+2+2)
	.word 21 * (pf_w+2+2)
	.word 22 * (pf_w+2+2)
	.word 23 * (pf_w+2+2)
	.word 24 * (pf_w+2+2)
	.word 25 * (pf_w+2+2)

; Wait for vertical blanking
; --------------------------
; Input: -
; Output: -
; Invalidates: A
wait_vbl:
_l	lda via_portb
	and #$20
	bne _l
	rts

; Copy non-overlapping memory block
; ---------------------------------
; Input: 
;   word1: source
;   word2: dest
;   Y: # of bytes to copy (must be > 0)
; Output: -
; Invalidates: A, Y
copy_mem:
	dey
_l  lda (word1),y
	sta (word2),y
	dey
	bne _l
	lda (word1),y
	sta (word2),y
	rts

; Print 16bit uint (inspired by https://www.beebwiki.mdfs.net/Number_output_in_6502_machine_code)
; ----------------
; Input:
;   word1: The number to print
;   word2: The screen address to print it to
;   [ jumping to xxx_lp1: Y: (number of digits)*2-2, eg 8 for 5 digits ]
; Output: -
; Invalidates: A, X, Y
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

cur_fall_delay:		.reserve 1	; Current delay per line
cur_fall_cnt:		.reserve 1	; fall count down; when 0, the tetromino falls down 1 line
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


	.include "screens.asm"
