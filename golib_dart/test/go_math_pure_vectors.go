// Oráculo das transcendentais do shim math: rodar com GOARCH=386, onde o
// pacote math do Go usa só o código Go puro (no amd64, Exp e Log são
// assembly). Imprime entradas e resultados (bits) em JSON.
package main

import (
	"encoding/json"
	"fmt"
	"math"
	"math/rand/v2"
	"os"
)

func fb(v float64) string {
	if math.IsNaN(v) {
		return "NaN" // payload de NaN não é portável
	}
	return fmt.Sprintf("%016x", math.Float64bits(v))
}

func main() {
	xs := []float64{0, math.Copysign(0, -1), 1, -1, 2, -2, 0.5, -0.5, 1.5, -1.5, 2.5, -2.5, 3, -3,
		0.1, 0.25, 0.75, 0.9, 1.2, 1.25, 1.75, 1.46, 7.5, 8, 28, 33.5, -33.5, 100, -100.5, 170.5, 171.7,
		200.5, 700, 709.7, 710, -745, -746, 1e-10, -1e-10, 1e-20, 1e-300, 1e300, -1e300,
		math.SmallestNonzeroFloat64, -math.SmallestNonzeroFloat64, 2.2250738585072014e-308,
		math.MaxFloat64, -math.MaxFloat64, math.Pi, math.E, math.Pi / 2, -math.Pi / 4,
		1 << 29, 1<<29 + 0.5, 1e10, 1e15, 1e22, 1 << 60, -(1 << 60), 4503599627370496.5,
		math.Inf(1), math.Inf(-1), math.NaN()}
	r := rand.New(rand.NewPCG(11, 13))
	for i := 0; i < 200; i++ {
		xs = append(xs, r.NormFloat64()*math.Pow(10, float64(r.IntN(13)-6)))
	}
	for i := 0; i < 60; i++ {
		if v := math.Float64frombits(r.Uint64()); !math.IsNaN(v) {
			xs = append(xs, v)
		}
	}
	ys := []float64{0, math.Copysign(0, -1), 1, -1, 2, -2, 0.5, -0.5, 3, -3, 1.5, 0.3, -7.25, 10,
		63, 64, 1e10, -1e10, 1 << 63, math.Inf(1), math.Inf(-1), math.NaN(), math.Pi}
	var in []string
	for _, x := range xs {
		in = append(in, fmt.Sprintf("%016x", math.Float64bits(x)))
	}
	var yin []string
	for _, y := range ys {
		yin = append(yin, fmt.Sprintf("%016x", math.Float64bits(y)))
	}
	out := map[string][]string{}
	add := func(k string, v ...any) { out[k] = append(out[k], fmt.Sprint(v...)) }
	for _, x := range xs {
		add("exp", fb(math.Exp(x)))
		add("expm1", fb(math.Expm1(x)))
		add("log", fb(math.Log(x)))
		add("log2", fb(math.Log2(x)))
		add("log10", fb(math.Log10(x)))
		add("log1p", fb(math.Log1p(x)))
		fr, e := math.Frexp(x)
		add("frexp", fb(fr), " ", e)
		i, f := math.Modf(x)
		add("modf", fb(i), " ", fb(f))
		add("round", fb(math.Round(x)))
		add("roundToEven", fb(math.RoundToEven(x)))
		add("cbrt", fb(math.Cbrt(x)))
		add("sin", fb(math.Sin(x)))
		add("cos", fb(math.Cos(x)))
		add("tan", fb(math.Tan(x)))
		s, c := math.Sincos(x)
		add("sincos", fb(s), " ", fb(c))
		add("atan", fb(math.Atan(x)))
		lg, sg := math.Lgamma(x)
		add("lgamma", fb(lg), " ", sg)
		add("gamma", fb(math.Gamma(x)))
		add("erfc", fb(math.Erfc(x)))
		for _, k := range []int{-1080, -1074, -1022, -60, -1, 0, 1, 52, 1023, 1100} {
			add("ldexp", fb(math.Ldexp(x, k)))
		}
		for _, y := range ys {
			add("pow", fb(math.Pow(x, y)))
			add("mod", fb(math.Mod(x, y)))
			add("nextafter", fb(math.Nextafter(x, y)))
		}
	}
	for _, x := range ys {
		for _, y := range ys {
			add("pow2", fb(math.Pow(x, y)))
		}
	}
	json.NewEncoder(os.Stdout).Encode(map[string]any{"x": in, "y": yin, "out": out})
}
