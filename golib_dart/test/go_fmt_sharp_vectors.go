//go:build ignore

// Oráculo do `#` em float e runa e do %#v dos erros do runtime
// (fmt_test.dart): imprime [formato, tipo, argumento, saída] em JSON.
package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"os"
	"strconv"
)

func main() {
	floats := []float64{0, 1, -1, 3.5, 3, 100000, 1e6, 1e21, 1e-5, 0.000123, 123456789, 1.0 / 3,
		math.Copysign(0, -1), math.Inf(1), math.Inf(-1), math.NaN(), 2.5e-308, 12.0, 0.1, 1e100}
	floatFmts := []string{"%#g", "%#G", "%#.3g", "%#.0g", "%#.1g", "%#.10g", "%#e", "%#.0e", "%#.3E",
		"%#f", "%#.0f", "%#.2f", "%#F", "%#.0F", "%#10.3g", "%#-10.0f|", "%#+g", "%# .0e", "%#012.1f",
		"%#08.0g", "%#v", "%#.3v"}
	var rows [][]string
	for _, f := range floatFmts {
		for _, x := range floats {
			bits := strconv.FormatUint(math.Float64bits(x), 16)
			rows = append(rows, []string{f, "f64", bits, fmt.Sprintf(f, x)})
			y := float32(x)
			bits32 := strconv.FormatUint(uint64(math.Float32bits(y)), 16)
			rows = append(rows, []string{f, "f32", bits32, fmt.Sprintf(f, y)})
		}
	}
	runes := []rune{'a', '\'', '\n', 'é', 0x1F600, 0x10FFFF + 1, -1, 0}
	for _, f := range []string{"%#q", "%#+q", "%#5q", "%#-5q|", "%#U", "%#v"} {
		for _, r := range runes {
			rows = append(rows, []string{f, "rune", strconv.Itoa(int(r)), fmt.Sprintf(f, r)})
		}
	}
	rows = append(rows,
		[]string{"%#v", "err", "new", fmt.Sprintf("%#v", errors.New("x\"y"))},
		[]string{"%#v", "err", "wrapnil", fmt.Sprintf("%#v", fmt.Errorf("a %w", nil))},
		[]string{"%#v", "err", "errorf", fmt.Sprintf("%#v", fmt.Errorf("b %d", 1))},
	)
	if err := json.NewEncoder(os.Stdout).Encode(rows); err != nil {
		panic(err)
	}
}
