// Oráculo: %v de float32/float64/complex e conversões float → inteiro (gc).
// Cada linha começa com os bits do float64 de entrada; o teste Dart reconstrói
// o valor a partir deles.
package main

import (
	"encoding/json"
	"fmt"
	"math"
	"math/rand"
	"os"
)

func conv(x float64) []string {
	return []string{
		fmt.Sprint(int64(x)), fmt.Sprint(uint64(x)), fmt.Sprint(int32(x)), fmt.Sprint(uint32(x)),
		fmt.Sprint(int16(x)), fmt.Sprint(uint16(x)), fmt.Sprint(int8(x)), fmt.Sprint(uint8(x)),
	}
}

func main() {
	vals := []float64{0, math.Copysign(0, -1), 1, -1, 0.1, 1.0 / 3, 1e-5, 1e-4, 123456, 1234567, 1e6, 1e20, 1e21,
		1.5, -1.5, 3.99, -129.5, 300.7, 5e9, 1e10, 9.3e18, 1e30, -1e30, math.NaN(), math.Inf(1), math.Inf(-1),
		math.MaxFloat64, math.SmallestNonzeroFloat64, math.MaxFloat32, math.SmallestNonzeroFloat32,
		9223372036854775807, 9223372036854777856, 18446744073709549568, 18446744073709551616,
		-9223372036854775808, 2147483647.9, -2147483648.9, -2147483649, 4294967295.5, 16777217, 0.30000000000000004}
	r := rand.New(rand.NewSource(1))
	for i := 0; i < 3000; i++ {
		switch i % 3 {
		case 0:
			vals = append(vals, math.Float64frombits(r.Uint64()))
		case 1:
			vals = append(vals, float64(math.Float32frombits(r.Uint32())))
		default:
			vals = append(vals, (r.Float64()-0.5)*math.Pow(2, float64(r.Intn(140)-20)))
		}
	}
	var rows [][]string
	for i, x := range vals {
		y := vals[(i+1)%len(vals)]
		f := float32(x)
		row := []string{fmt.Sprintf("%016x", math.Float64bits(x)), fmt.Sprintf("%016x", math.Float64bits(y)),
			fmt.Sprint(x), fmt.Sprint(f), fmt.Sprint(complex(x, y)), fmt.Sprint(complex64(complex(x, y)))}
		row = append(row, conv(x)...)
		row = append(row, conv(float64(f))...)
		rows = append(rows, row)
	}
	if err := json.NewEncoder(os.Stdout).Encode(rows); err != nil {
		panic(err)
	}
}
