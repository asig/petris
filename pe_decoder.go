package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
)

var (
	flagIn  = flag.String("in", "", "Input file")
	flagOut = flag.String("out", "", "Output file")
)

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
	b, err := ioutil.ReadFile(*flagIn)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Can'read file %q: %s", *flagIn, err)
		os.Exit(1)
	}

	var peFile map[string]interface{}
	json.Unmarshal(b, &peFile)

	data := deobfuscate(peFile["data"].(string))
	var peData map[string]interface{}
	json.Unmarshal([]byte(data), &peData)
	screens := peData["screens"].([]interface{})
	// screens := screensWrapper["data"]
	fmt.Printf("%T\n", screens[0])
	os.WriteFile(*flagOut, []byte(data), 0644)
}
