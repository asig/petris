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

;DEBUG	.equ 1

	.platform "pet"
	.cpu "6502"

	.include "macros.i"


; ********************************************************************
; *** Constants and memory addresses
; ********************************************************************

scr_w   .equ    40
vram    .equ    $8000
                                   
vram_playfield      .equ    vram +  1 * scr_w +  2
vram_stats_score    .equ    vram + 14 * scr_w + 14
vram_stats_lines    .equ    vram + 14 * scr_w + 21
vram_stats_level	.equ	vram + 14 * scr_w + 28
vram_stats_next     .equ    vram + 14 * scr_w + 35
vram_stats_t_i      .equ    vram + 19 * scr_w + 16
vram_stats_t_j      .equ    vram + 19 * scr_w + 22
vram_stats_t_s      .equ    vram + 19 * scr_w + 28
vram_stats_t_o      .equ    vram + 19 * scr_w + 34
vram_stats_t_t      .equ    vram + 21 * scr_w + 16
vram_stats_t_l      .equ    vram + 21 * scr_w + 22
vram_stats_t_z      .equ    vram + 21 * scr_w + 28

via	.equ $E840
via_portb	.equ via

keyboard_decode_table	.equ	$e75c	
curkey				.equ $203	; Currently pressed key
keyboard_buf_size	.equ $20d	; No. of characters in keyboard buffer

; ROM routines
print	.equ	$ca27	;  print $0-terminated string (string's low byte in A, high byte in Y)

; Zeropage addresses used to pass params, or as temporary variables
word1   .equ    $54
word2   .equ    $56
word3	.equ	$58
byte1   .equ    $5a
byte2   .equ    $5b

; Playfield consts
pf_w    .equ    10
pf_h    .equ    22

; Key codes using generic names for easier redefinition if necessary
key_left	.equ 48 ; 'A' key
key_right	.equ 47	; 'D' key
key_down	.equ 40	; 'S' key
key_fall	.equ 6	; Space key
key_rotate	.equ 27	; Return key
key_pause	.equ 52	; 'P' key
key_quit	.equ 4	; Run/stop key

; Scan codes for hiscore input handling
scancode_delete	.equ 65
scancode_return	.equ 27

; Default initial fall delay
inital_fall_delay	.equ	40

; Maximal name length in hiscores
max_hs_name_len	.equ 11

; After how many lines a new level start
default_lines_to_next_level	.equ 10

; Maximal level that can be reached
max_level	.equ	20

; ********************************************************************
; *** ENTRY POINT
; ********************************************************************

	.include "startup.i"
	
	; fix scroll text overlap
	set16i word1, scroller
	set16i word2, scroller_overlap
	ldy #scr_w
	jsr copy_mem

	jsr init_random
_l	jsr title
	lda quit_flag
	bne _quit
	jsr main_game
	jmp _l
_quit
	; Make sure the keyboard buffer is empty
	lda #0
	sta keyboard_buf_size
	
	lda #<byebye
	ldy #>byebye
	jmp print

byebye	.byte 147, "thanks for playing petris!",13,0

; ********************************************************************
; *** TITLE SCREEN
; ********************************************************************
title_mode		.reserve 1	; 0 == controls, !=0 == hiscores
title_cycle_cnt	.equ byte2
title
	jsr prepare_hiscores

	set16i word1, title_logo
	set16i word2, vram
	set16i word3, 8*scr_w
	jsr decrunch

	lda #0
	sta title_mode
	sta title_cycle_cnt
	set16i scroll_pos, scroller_prefix
	set16i word1, title_controls
	set16i word2, vram+8*scr_w
	set16i word3, 16*scr_w
	jsr decrunch

	jsr wait_no_key

_l	jsr wait_vbl
	inc title_cycle_cnt

	lda title_cycle_cnt
	and #$f
	bne _no_scroll
	jsr title_do_scroll
_no_scroll
	lda title_cycle_cnt
	bne _no_flip_mode
	jsr title_flip_mode
_no_flip_mode
	lda curkey
	cmp #$ff
	beq _l
	cmp #key_quit
	beq _quit_to_basic
	jmp title_begin_game
_quit_to_basic
	; run/stop pressed, return to basic after asking	
	jsr handle_quit
	jsr prepare_hiscores ; quit handler overwrites screen buffer, so we need to re-prepare the hiscores screen
	lda quit_flag
	beq _l
	rts

prepare_hiscores:
	; prepare hiscores screen in screen_buf
	set16i word1, title_hiscores
	set16i word2, screen_buf
	set16i word3, 16*scr_w
	jsr decrunch

	set16i word3, hiscores
	set16i word2, screen_buf+5*scr_w+9

	ldx #10
_hs_loop
	txa
	pha

	; print score
	ldy #0
	lda (word3),y
	sta word1
	iny
	lda (word3),y
	sta word1+1
	jsr print_uint16

	; print score
	ldy #2
	lda (word3),y
	sta word1
	iny
	lda (word3),y
	sta word1+1
	add16i word2, 6
	jsr print_uint16

	; print level
	ldy #4
	lda (word3),y
	sta word1
	lda #0
	sta word1+1
	add16i word2, 6
	ldy #4  ; 3 digits
	jsr print_uint16_lp1

	; print name
	ldy #5
	sub16i word2, 1	; == +4 - 5
_l2	lda (word3),y
	sta (word2),y
	iny
	cpy #max_hs_name_len+5
	bne _l2
	
	add16i word3, hiscore_record_size
	add16i word2, 24 + 5	; move to next line on screen, compensate for -5 above
	pla
	tax
	dex
	beq _hs_done
	jmp _hs_loop
_hs_done
	rts

title_flip_mode:
	lda title_mode
	eor #$ff
	sta title_mode
	bne _show_hiscores
	; show hiscores
	set16i word1, title_controls
	set16i word2, vram+8*scr_w
	set16i word3, 16*scr_w
	jmp decrunch	
_show_hiscores
	set16i word1, screen_buf
	set16i word2, vram+8*scr_w
	; copy 16 lines == 640 bytes
	ldy #0
	jsr	copy_mem
	inc word1+1
	inc word2+1
	ldy #0
	jsr	copy_mem
	inc word1+1
	inc word2+1
	ldy #128
	jmp	copy_mem

title_do_scroll
	set16m word1, scroll_pos
	set16i word2, vram+24*scr_w
	ldy #40
	jsr copy_mem
	inc16 scroll_pos
	lda scroll_pos
	cmp #<scroller_overlap
	beq _maybe_end
	rts
_maybe_end
	lda scroll_pos+1
	cmp #>scroller_overlap
	beq _scroll_end_reached
	rts
_scroll_end_reached
	set16i scroll_pos, scroller
	rts

title_begin_game
	jsr wait_no_key
	lda #0
	sta quit_flag
	rts

scroll_pos	.reserve 2
scroller_prefix	.reserve scr_w, scr(' ')
scroller	.byte scr("welcome to yet another version of tetris, this time for our beloved commodore pet :-) press any key to start the game, or <run/stop> to exit to basic. enjoy!            ")
scroller_len	.equ * - scroller
scroller_overlap .reserve 40

; ********************************************************************
; *** MAIN GAME LOOP
; ********************************************************************
last_key	.reserve 1
is_harddrop	.byte 1
main_game:
	lda #0
	sta quit_flag
	sta is_harddrop
	lda #default_lines_to_next_level
	sta lines_to_next_level
	jsr init_scores_and_next_tetromino
	jsr init_playfield

	; Show game screen
	set16i word1, main_screen
	set16i word2, vram
	set16i word3, 1000
	jsr decrunch

	jsr print_level
	jsr print_scores
	jsr print_lines

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
	ldx #0
_kl	lda _handlers,x
	beq _cont
	cmp last_key
	bne _next
	lda _handlers+1,x
	sta _jsr+1
	lda _handlers+2,x
	sta _jsr+2
_jsr	jsr $ffff
	jmp _cont
_next
	inx
	inx
	inx
	jmp _kl

_handlers	
	.byte key_left, <handle_left, >handle_left
	.byte key_right, <handle_right, >handle_right 
	.byte key_down, <handle_down, >handle_down 
	.byte key_rotate, <handle_rotate, >handle_rotate 
	.byte key_pause, <handle_pause, >handle_pause 
	.byte key_fall, <handle_fall, >handle_fall 
	.byte key_quit, <handle_quit, >handle_quit
	.byte 0

_cont
	lda quit_flag
	beq _c2
	rts

_c2
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

	jsr test_tetromino_fits
	bcc _game_not_over
	jmp game_over
_game_not_over

	dec cur_fall_cnt
	bne _fall_cont
	; Reset fall counter
	lda cur_fall_delay
	sta cur_fall_cnt

	; Move to next line, if possible
	inc cur_tetromino_y
	jsr test_tetromino_fits
	bcc _fall_cont	; Fits, move on.

	; Stone does not fit one row below: add it to the playfield, start a new stone
	dec cur_tetromino_y
	jsr set_tetromino_in_pf
	jsr check_harddrop
	jsr check_lines
	jsr new_tetromino
	jmp _loop

_fall_cont
	jsr set_tetromino_in_pf
	jsr draw_playfield
	jsr remove_tetromino_from_pf

	.ifdef DEBUG
	; print out fall cnt
	lda cur_fall_cnt
	sta word1
	lda #0
	sta word1+1
	set16i word2, vram+scr_w-3
	ldy #4  ; 3 digits
	jsr print_uint16_lp1

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

lines_removed:	.reserve 1
lines_to_go:	.reserve 1
; Find and remove complete lines, update scores, update screen
check_lines:
	lda #0
	sta lines_removed
	; start at the bottom-most line
	set16i word1, playfield + (pf_h+1)*(pf_w+4) + 2 - 1	; "-1" to compensate Y going from 1 to pf_w
	lda #pf_h
	sta lines_to_go
_scanline
	ldy #pf_w
	lda (word1),y
	dey
_l	and (word1),y
	dey
	bne _l
	cmp #0
	bne _clearline

	; Move up one line
_prevline
	sub16i word1, (pf_w+4)
	dec lines_to_go
	bne _scanline

	; We reached the top.
	; Update lines scores
	lda lines_removed
	beq _no_lines_removed
	asl	; multiply by 2
	tax	; X contains now the index+2 of the score to add
	; multiply score by level
	lda score_increments-2,x
	sta word1
	lda score_increments-1,x
	sta word1+1
	lda level
	sta word2
	lda #0
	sta word2+1
	jsr mul16
	clc
	lda score
	adc word1
	sta score
	lda score+1
	adc word2
	sta score+1
	jsr print_scores

_no_lines_removed
	rts

_clearline
	dec lines_to_next_level
	bne _no_next_level
	push16m word1
	jsr next_level
	pop16m word1
	lda #default_lines_to_next_level
	sta lines_to_next_level
_no_next_level
	inc lines_removed
	inc lines

	; blink the line a few times

	; First, save and clear the current line
	set16i word2, pf_line_buf
	ldy #pf_w
_cploop
	lda (word1),y
	sta (word2),y
	dey
	bne _cploop

	set16i word3, pf_line_empty
	ldx #9
_blinkloop
	; wait a little
	txa
	pha
	ldx #5
_wl	jsr wait_vbl
	dex
	bne _wl
	pla
	tax

	; copy empty or content to line
	ldy #pf_w
_l1
	lda (word3),y
	sta (word1),y
	dey
	bne _l1	
	pushx
	push16m word1
	push16m word2
	jsr draw_playfield
	jsr print_lines
	pop16m word2
	pop16m word1
	popx
	
	; switch what needs to bo copied
	lda word2
	ldy word3
	sta word3
	sty word2
	lda word2+1
	ldy word3+1
	sta word3+1
	sty word2+1

	dex
	bne _blinkloop

	; Move all above lines down
	ldx lines_to_go
	inx	; copy 1 sentinel line in so that we don't have to clear the top line

	push16m word1
	sec
	lda word1
	sbc #(pf_w+4)
	sta word2
	lda word1+1
	sbc #0
	sta word2+1

_move	
	ldy #pf_w
_l2	lda (word2),y
	sta (word1),y
	dey
	bne _l2

	set16m word1, word2
	sub16i word2, pf_w+4

	dex
	bne _move

	jsr draw_playfield	; Draw playfield
	pop16m word1
	jmp _scanline		; see if we need to clear more lines

next_level:
	lda level
	cmp #max_level
	beq _no_level_change
	inc level
	lda cur_fall_delay
	cmp #10	; minimal fall delay
	bcc _no_delay_change
	sec
	sbc #7
	sta cur_fall_delay
_no_delay_change
	jsr print_level
_no_level_change
	rts	

check_harddrop:
	lda is_harddrop
	bne _cont
	rts
_cont
	; add 1 point times level
	clc
	lda score
	adc level
	sta score
	lda score+1
	adc #0
	sta score+1
	jsr print_scores
	rts

; Show game over
game_over_line1	.byte scr("   ### game over! ###   ")
game_over_line_len	.equ * - game_over_line1
game_over_line3 .byte scr("you didn't make it into ")
game_over_line4 .byte scr("the hall of fame :-(    ")
game_over_line6 .byte scr("press a key to continue.")
game_over_box_x	.equ	(40-game_over_line_len-4)/2
game_over_box_y	.equ	8
game_over_address	.equ vram + (game_over_box_y+1)*scr_w+game_over_box_x+2

game_over_hs_line3	.byte scr("well done! enter your   ")
game_over_hs_line4	.byte scr("name: ...........       ")
game_over_hs_textpos	.equ game_over_address + 3*scr_w+6

game_over:
	; check whether the user made it into the hiscores table
	ldx #0
	set16i word1, hiscores
_compare_hiscore_row
	ldy #1
	lda (word1),y
	cmp score+1
	beq _score_hibyte_equal
	bcs _next_row	; current hibyte is > score
	bcc _row_found	; hibyte is < score
_score_hibyte_equal
	; hi-byte is equal, compare low byte
	ldy #0
	lda (word1),y
	cmp score
	beq _score_lowbyte_equal
	bcs _next_row	; current lowbyte is > score
	bcc _row_found	; lowbyte is < score
_score_lowbyte_equal
	; score is equal to hiscore entry, compare lines
	ldy #3
	lda (word1),y
	cmp lines+1
	beq _lines_hibyte_equal
	bcs _next_row	; current hibyte is > lines
	bcc _row_found	; hibyte is < levels
_lines_hibyte_equal
	; hi-byte is equal, compare low byte
	ldy #2
	lda (word1),y
	cmp lines
	beq _lines_lowbyte_equal
	bcs _next_row	; current lowbyte is > lines
	bcc _row_found	; lowbyte is < lines
_lines_lowbyte_equal
	; score and lines are equal, move on to next row
_next_row
	inx
	cpx #10
	bne _is_hiscore
	jmp no_hiscore
_is_hiscore
	; move on to next hiscore entry
	add16i word1, hiscore_record_size
	jmp _compare_hiscore_row
_row_found
	; row to insert is at word1, rank is X+1
	; save address to insert, and copy everything else down
	set16m word3, word1
	set16m word2, word1
	add16i word2, hiscore_record_size
	; compute how many bytes to copy
	lda #0
	clc
_compute_copy_size
	inx
	cpx #10
	beq _compute_copy_size_done
	adc #hiscore_record_size
	jmp _compute_copy_size
_compute_copy_size_done
	cmp #0
	beq _copy_done
	; finally, copy stuff
	tay
	jsr copy_mem
_copy_done
	; save score,  lines, and level at hiscore pos, and fill name with ' '
	lda score
	ldy #0
	sta (word3),y
	lda score+1
	iny
	sta (word3),y
	lda lines
	iny
	sta (word3),y
	lda lines+1
	iny
	sta (word3),y
	lda level
	iny
	sta (word3),y
	lda #scr(' ')
_hs_insert_loop
	iny
	cpy #hiscore_record_size
	beq _hs_insert_done
	sta (word3),y
	jmp _hs_insert_loop
_hs_insert_done

	; update insert pos to point to the actual name
	add16i word3, 5

	; Show game over screen...
	set16i word1, vram + game_over_box_y*scr_w+game_over_box_x
	ldx #8
	ldy #game_over_line_len + 4
	jsr draw_box

	; print text lines
	set16i word1, game_over_line1
	set16i word2, game_over_address
	ldy #game_over_line_len
	jsr copy_mem

	set16i word1, game_over_hs_line3
	set16i word2, game_over_address+2*scr_w
	ldy #game_over_line_len
	jsr copy_mem

	set16i word1, game_over_hs_line4
	set16i word2, game_over_address+3*scr_w
	ldy #game_over_line_len
	jsr copy_mem

	; ...let user enter their name
	set16i word1, game_over_hs_textpos
	ldy #0
	lda #0
	sta last_key
_enter_hs_loop
	; draw "cursor"
	jsr _determine_cursor_type
	ora #%10000000
	sta (word1),y
	lda curkey
	cmp last_key
	beq _enter_hs_loop	
	sta last_key

	cmp #$ff
	beq _enter_hs_loop	; No key pressed
	cmp #scancode_delete
	bne _c2
	; delete pressed
	jsr _determine_cursor_type
	sta (word1),y	; delete "cursor"
	cpy #0	; already at the beginning?
	beq _enter_hs_loop	; yes
	dey	; otherwise, go one back
	lda #scr('.')
	sta (word1),y	; erase screen
	lda #scr(' ')
	sta (word3),y	; and overwrite hiscores
	jmp _enter_hs_loop
_c2	cmp #scancode_return
	bne _c3
	; return pressed
	rts
_c3	cpy #max_hs_name_len
	beq _enter_hs_loop
	; convert the scancode to petscii and then to screen codes
	tax
	lda keyboard_decode_table-1,x
	jsr petscii_to_screencode	
	; store the screencode  in hiscores and on screen
	sta (word1),y
	sta (word3),y
	iny
	jmp _enter_hs_loop

_determine_cursor_type
	cpy #max_hs_name_len
	bcs _blank_cursor
	lda #scr('.')
	rts
_blank_cursor
	lda #scr(' ')
	rts

no_hiscore
	set16i word1, vram + game_over_box_y*scr_w+game_over_box_x
	ldx #8
	ldy #game_over_line_len + 4
	jsr draw_box
	; print text lines
	set16i word1, game_over_line3
	set16i word2, game_over_address+2*scr_w
	ldy #game_over_line_len
	jsr copy_mem

	set16i word1, game_over_line4
	set16i word2, game_over_address+3*scr_w
	ldy #game_over_line_len
	jsr copy_mem

	set16i word1, game_over_line6
	set16i word2, game_over_address+5*scr_w
	ldy #game_over_line_len
	jsr copy_mem

	lda #0
	sta byte1
_l	lda curkey
	cmp #$ff
	bne _done
	jsr wait_vbl
	inc byte1
	inc byte1
	inc byte1
	inc byte1
	bmi _l2
	; bit 7 not set, print title...
	set16i word1, game_over_line1
	set16i word2, game_over_address
	ldy #game_over_line_len
	jsr copy_mem
	jmp _l
_l2 set16i word1, game_over_address
	ldy #game_over_line_len
	lda #scr(' ')
	jsr fill_mem
	jmp _l
_done
_w2	lda curkey
	cmp #$ff
	bne _w2
	rts

handle_fall:
	lda #1
	sta is_harddrop
_l	inc cur_tetromino_y
	jsr test_tetromino_fits
	bcs _nofit

	; Draw playfield
	jsr set_tetromino_in_pf
	jsr draw_playfield
	jsr remove_tetromino_from_pf

	; Wait a little
	jsr wait_vbl
	jsr wait_vbl
	jmp _l

_nofit
	dec cur_tetromino_y
	; Set cur_fall_cnt so that we set the
	; tetromino imediately in the main game loop
	lda #1
	sta cur_fall_cnt
	rts

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
	inc cur_tetromino_y
	jsr test_tetromino_fits
	bcs _nofit
	rts
_nofit
	dec cur_tetromino_y
	rts

handle_rotate:
	; save old tetromino in screen_buf	set16i word1, rotate_buf in case rotation is blocked
	set16i word1, cur_tetromino
	set16i word2, screen_buf
	ldy #4*4
	jsr copy_mem

	jsr rotate_cur_left
	jsr test_tetromino_fits
	bcs _nofit
	rts
_nofit
	set16i word1, screen_buf
	set16i word2, cur_tetromino
	ldy #4*4
	jmp copy_mem

pause_text .byte scr("*** paused. ***")
pause_text_len	.equ * - pause_text
pause_address	.equ vram + (pause_box_y+2)*scr_w+pause_box_x+2
pause_box_x	.equ	(40-pause_text_len-4)/2
pause_box_y	.equ	10
pause_cnt	.equ	byte1
handle_pause:
	; wait for the key to be released
_w	lda curkey
	cmp #$ff
	bne _w

	jsr save_screen
	set16i word1, vram + pause_box_y*scr_w+pause_box_x
	ldx #5
	ldy #pause_text_len + 4
	jsr draw_box
	lda #0
	sta pause_cnt
_l	lda curkey
	cmp #$ff
	bne _done
	jsr wait_vbl
	inc pause_cnt
	inc pause_cnt
	inc pause_cnt
	inc pause_cnt
	bmi _l2
	; bit 7 not set,  print "pause"...
	set16i word1, pause_text
	set16i word2, pause_address
	ldy #pause_text_len
	jsr copy_mem
	jmp _l
_l2 set16i word1, pause_address
	ldy #pause_text_len
	lda #scr(' ')
	jsr fill_mem
	jmp _l
_done
_w2	lda curkey
	cmp #$ff
	bne _w2
	jsr restore_screen
	rts

quit_text .byte scr("*** quit? (y/n) ***")
quit_text_len	.equ * - quit_text
quit_address	.equ vram + (qbox_y+2)*scr_w+qbox_x+2
qbox_x	.equ	(40-quit_text_len-4)/2
qbox_y	.equ	10
quit_cnt	.equ byte1
handle_quit:
	; wait for the key to be released
_w	lda curkey
	cmp #$ff
	bne _w

	jsr save_screen
	set16i word1, vram + qbox_y*scr_w+qbox_x
	ldx #5
	ldy #quit_text_len + 4
	jsr draw_box

	lda #0
	sta quit_cnt
_l	lda curkey
	cmp #54
	beq _quit
	cmp #22
	beq _noquit
	jsr wait_vbl
	inc quit_cnt
	inc quit_cnt
	inc quit_cnt
	inc quit_cnt
	bmi _l2
	; bit 7 not set,  print "quit"...
	set16i word1, quit_text
	set16i word2, quit_address
	ldy #quit_text_len
	jsr copy_mem
	jmp _l
_l2 set16i word1, quit_address
	ldy #quit_text_len
	lda #scr(' ')
	jsr fill_mem
	jmp _l
_quit
	lda #1
	bne _cont
_noquit
	lda #0
_cont
	sta quit_flag

	jsr wait_no_key
	jsr restore_screen

	rts

; ********************************************************************
; *** Init
; ********************************************************************

init_scores_and_next_tetromino:
	lda #1
	sta level

	set16i score_increments, 5	; 1 line
	set16i score_increments+2, 15	; 2 lines
	set16i score_increments+4, 30	; 3 lines
	set16i score_increments+6, 60	; 4 lines

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

; ********************************************************************
; *** Screen updates
; ********************************************************************

print_scores:
	set16m word1, score
	set16i word2, vram_stats_score
	jmp print_uint16

print_lines:
	set16m word1, lines
	set16i word2, vram_stats_lines
	jmp print_uint16

print_level:	
	lda level
	sta word1
	lda #0
	sta word1+1
	set16i word2, vram_stats_level
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

; Save the current screen 
save_screen:
	set16i word1, vram
	set16i word2, screen_buf
	jmp copy_screen

; Restore a screen that was previously saved
restore_screen
	set16i word1, screen_buf
	set16i word2, vram
	jmp copy_screen

copy_screen
	ldx #3
_l	ldy #0
	jsr copy_mem
	inc word1+1
	inc word2+1
	dex
	bne _l
	ldy #232	; == (1000-3*256), but cbmasm can't handle that yet...
	jsr copy_mem
	rts

; ---------------------
; draw_box: Draws a box
; ---------------------
; Input:
;   word1: Top left corner
;   Y: width
;   X: height
; ---------------------
draw_box
	sty _w
	stx _h
	
	; first line
	lda #73	; "╮"
	dey
	sta (word1),y
	lda #64	; "─"
_fl	dey
	beq _fld
	sta (word1),y
	jmp _fl
_fld
	lda #85	; "╭"	
	sta (word1),y
	dex		; first line drawn

_i	add16i word1, scr_w
	dex
	beq _lastline
	; Intermediate line
	lda #93	; "¦"
	sta (word1),y	; Y is zero from last loop
	ldy _w
	dey
	sta (word1),y	;
	lda #scr(' ')
_il	dey
	beq _ild
	sta (word1),y
	jmp _il
_ild
	jmp _i

_lastline
	; last line
	ldy _w
	dey
	lda #75	; "╯"
	sta (word1),y
	lda #64	; "─"
_ll	dey
	beq _lld
	sta (word1),y
	jmp _ll
_lld
	lda #74	; "╰"	
	sta (word1),y
	rts

_w	.reserve 1
_h	.reserve 1

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

; ---------------------
; clean_playfield: Clears the playfield
; ---------------------
; Input: -
; Output: -
; Invalidates:
;    word1
;    word2
;    A,X,Y
; ---------------------
clear_playfield:
	; Source address to word1
	set16i word1, playfield+2  ; skip 2 cols (sentinels)

	ldx #pf_h+2	; Also clear the upper 2 sentinel rows
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

; ---------------------
; test_tetromino_fits: Tests if the current tetromino (cur_tetromino) fits
; into the playfield at (cur_tetromino_x, cur_tetromino_y)
; ---------------------
; Input: (coords in cur_tetromino_x, cur_tetromino_y)
; Output:
;   C-Flag set: Tetromino does not fit
;   C-Flag cleared: Tetromino fits
; ---------------------
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

	sub16i word1, (pf_w+4)+2	; compensate for origin being at (2,1)
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

set_tetromino_in_pf_elem  .macro
	lda (word2),y
	beq _l
	sta (word1), y
_l  iny
	.endm

	.ifdef DEBUG
tmp .reserve 2
	.endif

; ---------------------
; set_tetromino_in_pf: Sets the current tetromino (cur_tetromino)
; in the playfield at (cur_tetromino_x, cur_tetromino_y).
; No checks are performed whether it fits.
; ---------------------
; Input: -
; Ouput: -
; Invalidates:
;    word1
;    word2
;    A, X
; ---------------------
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

	sub16i word1, (pf_w+4)+2	; compensate for origin being at (2,1)
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

; ---------------------
; set_tetromino_in_pf: Removes the current tetromino (cur_tetromino) from
; the playfield at (cur_tetromino_x, cur_tetromino_y).
; No checks are performed whether it fits.
; ---------------------
; Input: -
; Ouput: -
; Invalidates:
;    word1
;    word2
;    A, X
; ---------------------
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

	sub16i word1, (pf_w+4)+2	; compensate for origin being at (2,1)
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
; *** Tetromino routines
; ********************************************************************

; Copy "next_tetromino" to cur_tetromino, and select new next tetromino
; Update stats and next_tetromino
new_tetromino:

	; Update stats
	lda next_tetromino
	asl
	tax
	inc stats,x
	bcc _nooverflow
	inc stats+1,x
_nooverflow

	; Copy next tetromino to current
	; Compute base address of next tetromino. A is already "next_tetromino * 2"
	; so we need to shift 3 times.
	asl
	asl
	asl

	; Now, copy 16 bytes from tetrominos + offset
	tax
	set16i word1, cur_tetromino
	ldy #0
_1	lda tetrominos,x
	sta (word1),Y
	inx
	iny
	cpy #16
	bne _1

	; set position
	lda #pf_w/2
	sta cur_tetromino_x
	lda #0
	sta cur_tetromino_y

	; Set falling delay, countdown, and harddrop
	lda cur_fall_delay
	sta cur_fall_cnt
	lda #0
	sta is_harddrop

	; Pick a new next tetromino
	jsr random
_l  cmp #7
	bcc _done ; less than 7 -> we're good
	sbc #7     
	jmp _l
_done
	sta next_tetromino

	; Update screen
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

rotate_buf:
	.reserve 16

; ********************************************************************
; *** Other routines
; ********************************************************************

	.include "random.asm"

; Convert PETSCII to screen code. See https://sta.c64.org/cbm64pettoscr.html
; Input:
;   A: PETSCII code
; Ouput:
;   A: screen code
petscii_to_screencode
	cmp #32
	bcs _c2
	adc #$80
	rts
_c2	cmp #64
	bcs _c3
	rts
_c3	cmp #96
	bcs _c4
	sec
	sbc #64
	rts
_c4	cmp #128
	bcs _c5
	sec
	sbc #32
	rts
_c5	cmp #160
	bcs _c6
	adc #64
	rts
_c6	cmp #192
	bcs _c7
	sec
	sbc #64
	rts
_c7	cmp #255
	bcs _c8
	sec
	sbc #128
	rts
_c8; only 255 is left...
	lda #94
	rts

; "Decrunch" data
; Input:
;   word1: address of "crunched" (RLE-packed) data 
;   word2: destination address
;   word3: size of (decrunched) data
; Invalidate:
;   A,X,Y,word1,word2,word3
decrunch
_next
	ldy #0
	lda (word1),y
	cmp #%10000000
	bcs _run

	; Not a run, just store byte in 
	sta (word2),y
	inc16 word1
	inc16 word2
	dec16 word3

	jmp _end

_run
	; extract number of repetitions and store it in _len
	and #%01111111
	tax
	inx
	stx _len ; _len now contains the number of repetitions

	; load byte to repeat
	iny
	lda (word1),y

	; store byte repeatedly
	ldy _len
_l	dey
  	sta (word2),y	; STA does not touch the flags,
	bne _l

	; Increment dest pointer by adding _len
	clc
	lda word2
	adc _len
	sta word2
	lda word2+1
	adc #0
	sta word2+1

	; Decrement byte count by subtracing _len
	sec
	lda word3
	sbc _len
	sta word3
	lda word3+1
	sbc #0
	sta word3+1

	; increment source pointer
	add16i word1, 2

_end 
	; check whether remaining byte count is 0
	lda #0
	cmp word3
	bne _next
	cmp word3+1
	bne _next
	; both are 0, so we're done.
	rts
_len .reserve 1

; Multiply 2 unsigned 16bit integers, result must fit into 16 bit 
; Input:
;   word1, word2: numbers to multiply
; Output:
;   word1: result of multiplication
; Invalidates:
;   A
;   X
;   word3
mul16:
	set16i word3, 0
	ldx #16
	lsr16m word1
_l	bcc _no_add
	add16m word3, word2
_no_add
	lsl16m word2
	lsr16m word1
	dex
	bne _l
	set16m word1, word3
	rts

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
	; wait until we're out of vertical blanking
_l	lda via_portb
	and #$20
	beq _l
	; wait until we're entering vertical blanking again
_l2	lda via_portb
	and #$20
	bne _l2
	rts

; Copy memory block. Overlaps work if destination > source
; ---------------------------------
; Input: 
;   word1: source
;   word2: dest
;   Y: # of bytes to copy (if 0, copies 256 bytes)
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

; Fill memory block.
; ------------------
; Input: 
;   word1: mem address
;   A: value to fill memory with
;   Y: # of bytes to fill (if 0, fills 256 bytes)
; Output: -
; Invalidates: Y
fill_mem:
	dey
_l  sta (word1),y
	dey
	bne _l
	sta (word1),y
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
	bne _digit	; Not zero, print it
	ldx _pad
	bne _digit	; No padding, print digit
	cpy #0
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

; Wait until no key is pressed
; --------------------------
; Input: -
; Output: -
; Invalidates: A
wait_no_key
	lda curkey
	cmp #$ff
	bne wait_no_key
	rts

; ********************************************************************
; *** Variables
; ********************************************************************

; Scores 
level:	.reserve 1
score:  .reserve 2
lines:  .reserve 2
stats:  .reserve 7*2    ; Same order as in "tetrominos" list
lines_to_next_level	.reserve 1

playfield:	.reserve (pf_w+2+2)*(pf_h+2+2) , scr('A')
; The following 2 fields are used for line blinking	
pf_line_buf		.reserve pf_w+4
pf_line_empty	.reserve pf_w+4, scr(' ')

cur_fall_delay:		.reserve 1	; Current delay per line
cur_fall_cnt:		.reserve 1	; fall count down; when 0, the tetromino falls down 1 line
cur_tetromino_x:    .reserve 1
cur_tetromino_y:    .reserve 1
cur_tetromino:      .reserve 4*4    ; 16 bytes for data
next_tetromino:     .reserve 1
quit_flag			.reserve 1

hiscores:
	.word 1000, 10
	.byte 10,scr("fork me on ")
	.word 900, 9
	.byte 9, scr("github!    ")
	.word 800, 8
	.byte 8, scr("https://   ")
	.word 700, 7
	.byte 7, scr("github.com/")
	.word 600, 6
	.byte 6, scr("asig/petris")
	.word 500, 5
	.byte 5, scr("           ")
	.word 400, 4
	.byte 4, 83,83,83,83,83,83,83,83,83,83,83
	.word 300, 3
	.byte 3, scr(" commodore ")
	.word 200, 2
	.byte 2, scr("forever :-)")
	.word 100, 1
	.byte 1, 83,83,83,83,83,83,83,83,83,83,83
hiscores_size	.equ * - hiscores
	.if hiscores_size != 10*16
	.fail "Hiscores size is != 160"
	.endif

hiscore_record_size	.equ	hiscores_size/10

; ********************************************************************
; *** Static data
; ********************************************************************

score_increments	.reserve 4*2	; score increments for 1, 2, 3, and 4 removed lines

tetromino_preview: ; 2-byte tetromino previews in screen codes
	.byte $62,$62 ; "I" tetromino
	.byte $7C,$FC ; "Z" tetromino
	.byte $6C,$EC ; "S" tetromino
	.byte $6C,$FC ; "T" tetromino
	.byte $76,$62 ; "J" tetromino
	.byte $6C,$FE ; "L" tetromino
	.byte $E1,$61 ; "O" tetromino

; Tetromino screen codes
TCI	.equ $cc
TCZ	.equ $cc
TCS	.equ $cc
TCT	.equ $cc
TCJ	.equ $cc
TCL	.equ $cc
TCO	.equ $cc

tetrominos:
	; 16 bytes per tetromino
	; order must be I, Z, S, T, J, L, O

	; Tetromino I
	.byte $00,$00,$00,$00
	.byte TCI,TCI,TCI,TCI
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00

	; Tetromino Z
	.byte $00,$00,$00,$00
	.byte TCZ,TCZ,$00,$00
	.byte $00,TCZ,TCZ,$00
	.byte $00,$00,$00,$00

	; Tetromino S
	.byte $00,$00,$00,$00
	.byte $00,TCS,TCS,$00
	.byte TCS,TCS,$00,$00
	.byte $00,$00,$00,$00

	; Tetromino T
	.byte $00,$00,$00,$00
	.byte $00,TCT,$00,$00
	.byte TCT,TCT,TCT,$00
	.byte $00,$00,$00,$00

	; Tetromino J
	.byte $00,$00,$00,$00
	.byte TCJ,$00,$00,$00
	.byte TCJ,TCJ,TCJ,$00
	.byte $00,$00,$00,$00

	; Tetromino L
	.byte $00,$00,$00,$00
	.byte $00,$00,TCL,$00
	.byte TCL,TCL,TCL,$00
	.byte $00,$00,$00,$00

	; Tetromino O
	.byte $00,$00,$00,$00
	.byte $00,TCO,TCO,$00
	.byte $00,TCO,TCO,$00
	.byte $00,$00,$00,$00


	.include "screens.asm"

screen_buf	.equ	*	; Screen buffer at the end of the file so that we don't have to actually store the bytes

	.if (* + 1000) >= $2000
	.fail "Program too big!"
	.endif
