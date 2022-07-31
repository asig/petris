/*
 * Copyright (c) 2022 Andreas Signer <asigner@gmail.com>
 *
 * This file is part of petris.
 *
 * petris is free software: you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * petris is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with petris.  If not, see <http://www.gnu.org/licenses/>.
 */

package main

import (
	"fmt"
)

type screen struct {
	name string
	data [][]int32
}

var screenToUnicode = map[int32]rune{
	0x20: ' ', // Space
	0xe2: '▀', // Upper half block
	0x64: '▁', // Lower one eighth block
	0x6f: '▂', // Lower one quarter block
	0x79: '▃', // Lower three eighths block
	0x62: '▄', // Lower half block
	0xf8: '▅', // Lower five eighths block
	0xf9: '▆', // Lower three quarters block
	0xe3: '▇', // Lower seven eighths block
	0xa0: '█', // Full block
	0xe7: '▉', // Left seven eighths block
	0xea: '▊', // Left three quarters block
	0xf6: '▋', // Left five eighths block
	0x61: '▌', // Left half block
	0x75: '▍', // Left three eighths block
	0x74: '▎', // Left one quarter block
	0x65: '▏', // Left one eighth block
	0xe1: '▐', // Right half block
	// 0x2591: '░', // Light shade
	0x66: '▒', // Medium shade
	// 0x2593: '▓', // Dark shade
	0x63: '▔', // Upper one eighth block
	0x67: '▕', // Right one eighth block
	0x7b: '▖', // Quadrant lower left
	0x6c: '▗', // Quadrant lower right
	0x7e: '▘', // Quadrant upper left
	0xfc: '▙', // Quadrant upper left and lower left and lower right
	0x7f: '▚', // Quadrant upper left and lower right
	0xec: '▛', // Quadrant upper left and upper right and lower left
	0xfb: '▜', // Quadrant upper left and upper right and lower right
	0x7c: '▝', // Quadrant upper right
	0xff: '▞', // Quadrant upper right and lower left
	0xfe: '▟', // Quadrant upper right and lower left and lower right
}

var screens []screen = []screen{
	{
		name: "logo",
		data: [][]int32{
			{0xE1, 0xA0, 0xA0, 0xA0, 0xA0, 0x7B, 0xA0, 0xA0, 0xA0, 0xA0, 0x61, 0xA0, 0xA0, 0xA0, 0xA0, 0xA0, 0xA0, 0xA0, 0xA0, 0xA0, 0xA0, 0x61},
			{0xE1, 0x61, 0x20, 0x20, 0xE1, 0x61, 0xA0, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0xA0, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20},
			{0xE1, 0xA0, 0xA0, 0xA0, 0xA0, 0x7E, 0xA0, 0xA0, 0xA0, 0xA0, 0x61, 0x20, 0x20, 0xA0, 0x20, 0xEC, 0x7F, 0x7C, 0xEC, 0xE1, 0xE2, 0x20},
			{0xE1, 0x61, 0x20, 0x20, 0x20, 0x20, 0xA0, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0xA0, 0x20, 0xFC, 0xFF, 0x20, 0x61, 0xE1, 0x62, 0x20},
			{0xE1, 0x61, 0x20, 0x20, 0x20, 0x20, 0xA0, 0xA0, 0xA0, 0xA0, 0x61, 0x20, 0x20, 0xA0, 0x20, 0x61, 0xE1, 0x6C, 0xFC, 0x20, 0xE1, 0x20},
			{0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0xFE, 0x20},
		},
	},
}

func (scr *screen) convert() []byte {
	res := ""
	for _, l := range scr.data {
		for _, i := range l {
			r, found := screenToUnicode[i]
			if !found {
				r = ' '
			}
			res = res + string(r)
		}
		res = res + string('\n')
	}
	return []byte(res)
}

func main() {
	for _, scr := range screens {
		t := scr.convert()
		fmt.Printf(">> %s <<\n", scr.name)
		fmt.Printf("------------------------------------------\n")
		fmt.Printf("%s", string(t))
		fmt.Printf("------------------------------------------\n")
	}
}
