// Transcendentais do math (porta do Go puro). As que no amd64 não passam por
// assembly (Sin, Cos, Tan, Atan, Cbrt, Log1p, Expm1, Round, Frexp, Mod...)
// saem com precisão total; as que usam Exp/Log (assembly no amd64, pode
// diferir no último bit) com %.12g.
package main

import (
	"fmt"
	"math"
)

func main() {
	xs := []float64{0, math.Copysign(0, -1), 0.5, -0.5, 1, 2, 3.7, -2.25, 10, 1e-8, 0.1,
		123.456, -7.5, 1e9, -3e12, 1e15, 1e300, math.Inf(1), math.Inf(-1), math.NaN()}
	for _, x := range xs {
		s, c := math.Sincos(x)
		fr, e := math.Frexp(x)
		i, f := math.Modf(x)
		fmt.Println(x, math.Sin(x), math.Cos(x), math.Tan(x), s, c)
		fmt.Println(" ", math.Atan(x), math.Cbrt(x), math.Log1p(x), math.Expm1(x))
		fmt.Println(" ", math.Round(x), math.RoundToEven(x), fr, e, i, f)
		fmt.Println(" ", math.Mod(x, 2.5), math.Nextafter(x, 0), math.Ldexp(x, 3), math.Ldexp(x, -1070))
		lg, sg := math.Lgamma(x)
		fmt.Printf("  %.12g %.12g %.12g %.12g %.12g\n", math.Exp(x), math.Log(x), math.Log2(x), math.Log10(x), math.Erfc(x))
		fmt.Printf("  %.12g %.12g %.12g %d %.12g\n", math.Pow(x, 1.5), math.Pow(x, 3), lg, sg, math.Gamma(x))
	}
	fmt.Println(math.Pow(2, 10), math.Pow(-2, 3), math.Pow(2, -2), math.Log2(8), math.Log2(0.125))
	fmt.Println(math.Round(2.5), math.Round(-2.5), math.RoundToEven(2.5), math.RoundToEven(3.5))
}
