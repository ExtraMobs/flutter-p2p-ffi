// Tipos genéricos sobre map, slice e func (Set[T], List[T], Mapper[T]) e com
// receptor ponteiro (Heap[K, V] de github.com/quic-go/quic-go/internal/utils/minheap).
package main

import (
	"cmp"
	"fmt"
)

type Set[T comparable] map[T]struct{}

func (s Set[T]) Add(v T)           { s[v] = struct{}{} }
func (s Set[T]) Has(v T) bool      { _, ok := s[v]; return ok }
func NewSet[T comparable]() Set[T] { return Set[T]{} }

type List[T any] []T

func (l List[T]) Len() int         { return len(l) }
func (l List[T]) Push(v T) List[T] { return append(l, v) }
func (l List[T]) Map(f Mapper[T]) List[T] {
	out := make(List[T], 0, len(l))
	for _, v := range l {
		out = append(out, f(v))
	}
	return out
}

type Mapper[T any] func(T) T

type entry[K, V any] struct {
	key   K
	value V
}

type Heap[K cmp.Ordered, V any] []entry[K, V]

func (h Heap[K, V]) Len() int    { return len(h) }
func (h Heap[K, V]) Empty() bool { return len(h) == 0 }

func (h *Heap[K, V]) Push(key K, value V) {
	*h = append(*h, entry[K, V]{key: key, value: value})
	(*h).up(len(*h) - 1)
}

func (h *Heap[K, V]) Pop() (K, V) {
	values := *h
	last := len(values) - 1
	v := values[0]
	values[0] = values[last]
	var zero entry[K, V]
	values[last] = zero
	values = values[:last]
	if last > 0 {
		values.down(0)
	}
	*h = values
	return v.key, v.value
}

func (h Heap[K, V]) up(i int) {
	for i > 0 {
		p := (i - 1) / 2
		if h[p].key <= h[i].key {
			return
		}
		h[p], h[i] = h[i], h[p]
		i = p
	}
}

func (h Heap[K, V]) down(i int) {
	for {
		l, r, m := 2*i+1, 2*i+2, i
		if l < len(h) && h[l].key < h[m].key {
			m = l
		}
		if r < len(h) && h[r].key < h[m].key {
			m = r
		}
		if m == i {
			return
		}
		h[m], h[i] = h[i], h[m]
		i = m
	}
}

func main() {
	s := Set[string]{}
	s.Add("x")
	t := NewSet[int]()
	t.Add(3)
	fmt.Println(len(s), s.Has("x"), s.Has("y"), t.Has(3), len(t))
	l := List[int]{1, 2}.Push(3)
	var double Mapper[int] = func(i int) int { return i * 2 }
	fmt.Println(l.Len(), l, l.Map(double), List[string](nil).Len())

	var h Heap[int, string]
	for i, k := range []int{5, 1, 4, 2, 3} {
		h.Push(k, fmt.Sprint("v", i))
	}
	for !h.Empty() {
		k, v := h.Pop()
		fmt.Print(k, ":", v, " ")
	}
	fmt.Println(h.Len())
}
