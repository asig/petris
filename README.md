# README

Welcome to 

```
▐████▖████▌██████████▌
▐▌  ▐▌█      █        
▐████▘████▌  █ ▛▚▝▛▐▀ 
▐▌    █      █ ▙▞ ▌▐▄ 
▐▌    ████▌  █ ▌▐▗▙ ▐ 
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▟ 
```

PETris is a small Tetris implementation for the Commodore PET 2001 with
BASIC 1. It will not run on other Commodores.

## How to build and run

To build PETris, you need the following tools:
   - `make`
   - [cbmasm](https://github.com/asig/cbmasm)
   - a recent version of [go](https://go.dev) 

If you want to generate a `TAP` file as well, you need to also download
Luigi di Fraia's [prg2tap](https://luigidifraia.wordpress.com/tag/prg2tap/) tools.
   
Then, just run make:
   - `make` to build the prg file,
   - `make petris.tap` to create a `TAP` file that can be used with [Tapuino](https://github.com/sweetlilmre/tapuino) on a real PET,
   - or `make run` to run it in VICE.

## License
Copyright (c) 2022 Andreas Signer.  
Licensed under [GPLv3](https://www.gnu.org/licenses/gpl-3.0).
