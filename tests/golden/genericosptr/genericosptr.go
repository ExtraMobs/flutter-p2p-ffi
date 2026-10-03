package main

import (
	"cmp"
	"fmt"
)

type P struct{ X int }

func (p *P) Inc() { p.X++ }

type Arr [2]int

type Name string

// *T instanciado com struct/array: o objeto vira go.Ptr<T> na fronteira.
func Set[T any](p *T, v T) { *p = v }

func Get[T any](p *T) T { return *p }

func IsNil[T any](p *T) bool { return p == nil }

func Same[T any](a, b *T) bool { return a == b }

func Pick[T any](a, b *T, first bool) *T {
	if first {
		return a
	}
	return b
}

func New[T any]() *T { return new(T) }

func SetVia[T any](p *T, v T) { Set(p, v) } // genérico chamando genérico

func Swap[T any](a, b *T) { *a, *b = *b, *a }

// Operadores compostos sobre T.
func div[T int | float64](a, b T) T { a /= b; return a }

func ops[T ~int | ~int64](a, b T) T {
	a += b
	a *= b
	a -= 1
	a /= 2
	a %= 7
	return a
}

// `+` sobre cmp.Ordered e ~string.
func add[T cmp.Ordered](a, b T) T { return a + b }

func cat[T ~string](a, b T) T {
	a += b
	return a + "!"
}

func main() {
	x, y := P{1}, P{2}
	q := &x
	Set(&x, P{7})
	fmt.Println(x, q.X, Get(&y), IsNil(&x), IsNil[P](nil))
	fmt.Println(Same(&x, q), Same(&x, &y))
	r := Pick(&x, &y, false)
	r.Inc()
	fmt.Println(y, r == &y)
	n := New[P]()
	n.Inc()
	fmt.Println(*n)
	SetVia(&y, P{9})
	fmt.Println(y)

	a := Arr{1, 2}
	Set(&a, Arr{3, 4})
	fmt.Println(a)
	var raw [2]string
	Set(&raw, [2]string{"u", "v"})
	fmt.Println(raw)

	set := Set[P]
	set(&x, P{11})
	pick := Pick[P]
	fmt.Println(x, pick(&x, &y, true).X)

	i, j := 1, 2
	Swap(&i, &j)
	fmt.Println(i, j)
	Swap(&x, &y)
	fmt.Println(x, y, q.X)
	Swap(&a, &Arr{5, 6})
	fmt.Println(a)

	fmt.Println(div(7, 2), div(7.0, 2), ops(5, 3), ops(int64(-9), 4))
	fmt.Println(add("a", "b"), add(1.5, 2), add(3, 4), cat(Name("go"), "lang"))
}
