// Builtins min, max e clear (Go 1.21). Repro do audit do kubo: o laço de
// pebble/internal/bitflip e o clear de quic-go/internal/utils/ringbuffer.
package main

import (
	"fmt"
	"math"
)

type Level int

type P struct{ X, Y int }

// Anel genérico como o ringbuffer do quic-go.
type Ring[T any] struct {
	ring    []T
	headPos int
}

func (r *Ring[T]) Init(size int) { r.ring = make([]T, 0, size) }

func (r *Ring[T]) Push(t T) { r.ring = append(r.ring, t) }

func (r *Ring[T]) Clear() {
	clear(r.ring[:cap(r.ring)])
	r.ring = r.ring[:0]
	r.headPos = 0
}

// Como pebble/internal/bitflip: resultados nomeados nunca lidos (só
// return explícito) e min no limite do laço.
func checkSliceForBitFlip(data []byte, sum func([]byte) uint32, want uint32) (found bool, indexFound int, bitFound int) {
	for i := 0; i < min(len(data), 40*(1<<10)); i++ {
		for bit := 0; bit < 8; bit++ {
			data[i] ^= (1 << bit)
			got := sum(data)
			data[i] ^= (1 << bit)
			if got == want {
				return true, i, bit
			}
		}
	}
	return false, 0, 0
}

// Resultado nomeado com return sem valores continua sendo local.
func split(n int) (lo, hi int) {
	lo, hi = min(n, 10), max(n, 10)
	return
}

func main() {
	data := []byte("abcdef")
	limit := 4
	n := 0
	for i := 0; i < min(len(data), limit); i++ {
		n++
	}
	fmt.Println(n, max(len(data), limit, 2))
	sum := func(b []byte) uint32 {
		var s uint32
		for _, c := range b {
			s = s*31 + uint32(c)
		}
		return s
	}
	want := sum([]byte("abcdef"))
	data[2] ^= 1 << 3
	fmt.Println(checkSliceForBitFlip(data, sum, want))
	fmt.Println(split(4))

	a, b, c := 5, -3, 9
	fmt.Println(min(a, b, c), max(a, b, c), min(a, 7))
	var l1, l2 Level = 3, 8
	fmt.Println(min(l1, l2)+1, max(l1, l2))
	var u1, u2 uint8 = 250, 10
	fmt.Println(min(u1, u2), max(u1, u2)+10)
	s1, s2 := "banana", "apple"
	fmt.Println(min(s1, s2), max(s1, s2, "cherry"))

	nan, zero := math.NaN(), 0.0
	neg := math.Copysign(0, -1)
	fmt.Println(min(1.5, nan, -2.0), max(nan, 3.0))
	// sinal do zero via 1/x (+Inf ou -Inf)
	fmt.Println(1/min(zero, neg), 1/max(neg, zero))
	fmt.Println(1/min(neg, zero), 1/max(zero, neg))
	var f1, f2 float32 = 1.25, -0.5
	fmt.Println(min(f1, f2), max(f1, f2))

	m := map[string]int{"a": 1, "b": 2}
	clear(m)
	m["c"] = 3
	fmt.Println(len(m), m)
	var nilMap map[int]int
	clear(nilMap)
	fmt.Println(len(nilMap))

	xs := []int{1, 2, 3, 4}
	clear(xs[1:3])
	fmt.Println(xs)
	ps := []P{{1, 2}, {3, 4}}
	held := &ps[0]
	clear(ps)
	held.X = 7
	fmt.Println(ps, *held)

	var r Ring[string]
	r.Init(4)
	r.Push("x")
	r.Push("y")
	full := r.ring[:cap(r.ring)]
	r.Clear()
	fmt.Println(len(r.ring), cap(r.ring), full[0] == "", full[1] == "")
}
