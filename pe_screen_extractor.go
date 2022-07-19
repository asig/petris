package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strings"
)

var (
	flagIn      = flag.String("in", "", "Input file")
	flagOut     = flag.String("out", "", "Output file")
	flagScreens = flag.String("screens", "", "Screens to process")
	flagDumpPE  = flag.String("dump_pe", "", "File to dump deobfuscated PE file to")
)

const rleMarker = 0

type packedScreen []int32

func (scr *packedScreen) String() string {
	var s []string
	for _, v := range *scr {
		s = append(s, fmt.Sprintf("$%02x", v))
	}
	return strings.Join(s, ", ")
}

func usage() {
	fmt.Fprintf(os.Stderr, "Usage: pe_decoder -in=<pe-file> -out=<output file>\n")
	os.Exit(1)
}

func deobfuscate(raw string) string {
	r := make(map[rune]string)
	o := []rune(raw)
	a := string(o[0])
	i := string(a)
	res := string(a)
	var n rune = 256

	var t string

	for c := 1; c < len(o); c++ {
		var l = o[c]
		if 256 > l {
			t = string(o[c])
		} else {
			var found bool
			t, found = r[l]
			if !found {
				t = i + a
			}
		}
		res = res + t
		a = string([]rune(t)[0])
		r[n] = i + a
		n++
		i = t
	}
	return res
}

func (scr *packedScreen) emit(c int32) {
	*scr = append(*scr, c)
}

func (scr *packedScreen) emitRun(c, l int32) {
	if l > 1 {
		for l > 256 {
			scr.emit(rleMarker)
			scr.emit(255)
			scr.emit(c)
			l -= 256
		}
		scr.emit(rleMarker)
		scr.emit(l - 1)
		scr.emit(c)
		return
	}
	if c == rleMarker {
		scr.emit(rleMarker)
		scr.emit(0)
		scr.emit(c)
		return
	}
	scr.emit(c)
}

func packScreen(raw map[string]interface{}) packedScreen {
	packed := packedScreen{}

	// w := int(raw["sizeX"].(float64))
	// h := int(raw["sizeY"].(float64))

	var flat []int32
	for _, line := range raw["charData"].([]interface{}) {
		for _, c := range line.([]interface{}) {
			flat = append(flat, int32(c.(float64)))
		}
	}

	l := int32(1)
	c := flat[0]
	for pos := 1; pos < len(flat); pos++ {
		if flat[pos] == c {
			// Same run
			l++
		} else {
			packed.emitRun(c, l)
			c = flat[pos]
			l = 1
		}
	}
	packed.emitRun(c, l)

	return packed
}

func main() {

	flag.Parse()

	if *flagIn == "" {
		fmt.Fprintf(os.Stderr, "-in parameter missing!\n")
		usage()
	}
	if *flagOut == "" {
		fmt.Fprintf(os.Stderr, "-out parameter missing!\n")
		usage()
	}

	screensToExport := make(map[string]bool)
	for _, s := range strings.Split(*flagScreens, ",") {
		if s != "" {
			screensToExport[strings.ToLower(s)] = true
		}
	}

	b, err := ioutil.ReadFile(*flagIn)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Can'read file %q: %s", *flagIn, err)
		os.Exit(1)
	}

	var peFile map[string]interface{}
	json.Unmarshal(b, &peFile)

	data := deobfuscate(peFile["data"].(string))
	if *flagDumpPE != "" {
		ioutil.WriteFile(*flagDumpPE, []byte(data), 0644)
	}

	var peData map[string]interface{}
	json.Unmarshal([]byte(data), &peData)
	screens := peData["screens"].([]interface{})

	outfile, err := os.Create(*flagOut)
	if err != nil {
		log.Fatalf("Can't create file %q: %s", *flagOut, err)
	}

	for _, screen := range screens {
		scr := screen.(map[string]interface{})
		name := strings.ToLower(scr["name"].(string))
		if len(screensToExport) == 0 || screensToExport[name] {
			packed := packScreen(scr)
			outfile.WriteString(fmt.Sprintf("%s:\t.byte %s\n", name, packed.String()))
		}
	}
	outfile.Close()
}
