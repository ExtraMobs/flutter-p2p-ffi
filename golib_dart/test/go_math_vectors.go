package main

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
)

func main() {
	values := []float64{0, math.Copysign(0, -1), 1, -1, 2, 0.1, 1e-300, 1e300,
		math.SmallestNonzeroFloat64, 2.2250738585072014e-308, math.MaxFloat64,
		math.Inf(1), math.Inf(-1), math.NaN(), 12345.6789, 9007199254740993}
	rows := []string{}
	for _, x := range values {
		if v := math.Sqrt(x); math.IsNaN(v) {
			rows = append(rows, "NaN")
		} else {
			rows = append(rows, fmt.Sprintf("%016x", math.Float64bits(v)))
		}
	}
	if err := json.NewEncoder(os.Stdout).Encode(rows); err != nil {
		panic(err)
	}
}
