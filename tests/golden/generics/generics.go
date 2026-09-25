// Package main exercita genéricos: funções com constraints numéricas e
// cmp.Ordered, inferência e instanciação explícita, zero value de T,
// slices de T e structs genéricas com métodos.
package main

import (
	"cmp"
	"fmt"
)

type Number interface {
	~int | ~int64 | ~float64
}

type Meters float64

func Sum[T Number](xs ...T) T {
	var total T
	for _, x := range xs {
		total += x
	}
	return total
}

func Avg[T Number](xs []T) T {
	return Sum(xs...) / T(len(xs))
}

func Max[T cmp.Ordered](a, b T) T {
	if a > b {
		return a
	}
	return b
}

func Map[T, U any](xs []T, f func(T) U) []U {
	out := make([]U, 0, len(xs))
	for _, x := range xs {
		out = append(out, f(x))
	}
	return out
}

type Stack[T any] struct {
	items []T
}

func (s *Stack[T]) Push(v T) { s.items = append(s.items, v) }

func (s *Stack[T]) Pop() (T, bool) {
	var zero T
	if len(s.items) == 0 {
		return zero, false
	}
	v := s.items[len(s.items)-1]
	s.items = s.items[:len(s.items)-1]
	return v, true
}

func (s Stack[T]) Len() int { return len(s.items) }

type Pair[K comparable, V any] struct {
	Key K
	Val V
}

func main() {
	fmt.Println(Sum(1, 2, 3), Sum(1.5, 2.25), Sum[Meters](1, 2), Sum[int](), Avg([]int{7, 8}))
	fmt.Println(Max(3, 7), Max("abc", "abd"), Max(2.5, -1.0))
	strs := Map([]int{1, 2, 3}, func(i int) string { return fmt.Sprint("n", i) })
	fmt.Println(strs, len(strs))
	var s Stack[string]
	s.Push("a")
	s.Push("b")
	v, ok := s.Pop()
	fmt.Println(v, ok, s.Len())
	s.Pop()
	v, ok = s.Pop()
	fmt.Println(v == "", ok)
	p := Pair[string, int]{"k", 1}
	fmt.Println(p, p.Key)
}
