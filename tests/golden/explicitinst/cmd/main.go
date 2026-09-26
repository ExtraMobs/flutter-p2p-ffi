// Instanciação explícita: f[int](x), pkg.F[T](x), pkg.New[K, V](...) e
// f[T] como valor (go.opentelemetry.io/otel/attribute, golang-lru/v2).
package main

import (
	"fmt"

	"g2d.test/explicitinst/gen"
)

func id[T any](x T) T { return x }

func Map[T, U any](xs []T, f func(T) U) []U {
	out := make([]U, 0, len(xs))
	for _, x := range xs {
		out = append(out, f(x))
	}
	return out
}

func main() {
	fmt.Println(gen.AsSlice[bool]([]bool{true}), id[int](3), id[string]("s"))
	p := gen.New[string, int]("a", 1)
	fmt.Println(p.K, p.V, *p)
	f := id[float64]
	g := gen.AsSlice[int]
	fmt.Println(f(1.5), g([]int{4}), Map[int, string]([]int{1, 2}, func(i int) string { return fmt.Sprint(i * 2) }))
	h := Map[int, int]
	fmt.Println(h([]int{3}, id[int]))
}
