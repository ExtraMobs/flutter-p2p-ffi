package main

import "fmt"

type P struct{ X int }

func First[T any](xs []T) T { return xs[0] }

func Dup[T any](v T) (T, T) { c := v; return v, c }

type Box[T any] struct{ V T }

func (b Box[T]) Get() T { return b.V }

func (b *Box[T]) Put(v T) { b.V = v }

func Show[T any](v T) { fmt.Println(v) }

type Num interface{ ~int | ~float64 }

func Sum[T Num](xs []T) T {
	var s T
	for _, x := range xs {
		s += x
	}
	return s
}

func main() {
	s := []P{{1}}
	v := First(s)
	v.X = 5
	fmt.Println(s[0].X)
	a, b := Dup(P{1})
	a.X = 9
	fmt.Println(b.X)

	bx := Box[P]{P{2}}
	g := bx.Get()
	g.X = 7
	fmt.Println(bx.V.X)
	q := P{3}
	bx.Put(q)
	q.X = 8
	fmt.Println(bx.V.X)

	arr := [2]int{1, 2}
	c, _ := Dup(arr)
	c[0] = 100
	fmt.Println(arr, c)

	// Ponteiro e interface: sem cópia.
	p := &P{4}
	pp := First([]*P{p})
	pp.X = 40
	fmt.Println(p.X, pp == p)
	Show(P{6})
	Show(p)
	fmt.Println(Sum([]int{1, 2, 3}))
}
