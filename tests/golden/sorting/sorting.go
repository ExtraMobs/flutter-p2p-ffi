// Oráculo do shim sort (porta do pdqsort/stable do Go) e repro de
// github.com/gogo/protobuf/sortkeys (sort.Sort sobre slices nomeados,
// sort.Strings, sort.Float64s).
package main

import (
	"fmt"
	"sort"
)

type Uint64Slice []uint64

func (p Uint64Slice) Len() int           { return len(p) }
func (p Uint64Slice) Less(i, j int) bool { return p[i] < p[j] }
func (p Uint64Slice) Swap(i, j int)      { p[i], p[j] = p[j], p[i] }

type BoolSlice []bool

func (p BoolSlice) Len() int           { return len(p) }
func (p BoolSlice) Less(i, j int) bool { return p[j] }
func (p BoolSlice) Swap(i, j int)      { p[i], p[j] = p[j], p[i] }

// traced registra cada Less/Swap num hash: a sequência de chamadas tem de
// ser a do Go, não só o resultado.
type item struct {
	key, id int
}

type traced struct {
	xs    []item
	h     uint32
	calls int
}

func (t *traced) mix(op, i, j int) {
	t.h = (t.h ^ uint32(op*1000003+i*1009+j)) * 16777619
	t.calls++
}
func (t *traced) Len() int { return len(t.xs) }
func (t *traced) Less(i, j int) bool {
	t.mix(1, i, j)
	return t.xs[i].key < t.xs[j].key
}
func (t *traced) Swap(i, j int) {
	t.mix(2, i, j)
	t.xs[i], t.xs[j] = t.xs[j], t.xs[i]
}

func gen(n, pattern, mod int) []item {
	xs := make([]item, n)
	seed := uint32(n*31 + pattern)
	for i := range xs {
		seed = seed*1664525 + 1013904223
		k := 0
		switch pattern {
		case 0:
			k = int(seed>>8) % mod
		case 1:
			k = i
		case 2:
			k = n - i
		case 3:
			k = i % 7
		case 4:
			k = 5
		case 5:
			k = i
			if i%10 == 0 {
				k = int(seed>>8) % n
			}
		}
		xs[i] = item{k, i}
	}
	return xs
}

func ids(xs []item) (h uint32) {
	for _, x := range xs {
		h = h*31 + uint32(x.id)
	}
	return
}

func main() {
	for _, n := range []int{0, 1, 2, 5, 12, 13, 20, 49, 50, 51, 100, 300} {
		for pattern := 0; pattern < 6; pattern++ {
			t := &traced{xs: gen(n, pattern, 4)}
			sort.Sort(t)
			s := &traced{xs: gen(n, pattern, 4)}
			sort.Stable(s)
			// Leituras antes das chamadas: a ordem entre operando e chamada no
			// mesmo Println não é especificada (TODO/P1-construcao-ordem-avaliacao).
			calls, h := t.calls, t.h
			sorted := sort.IsSorted(t)
			fmt.Println(n, pattern, calls, h, ids(t.xs), sorted, s.calls, s.h, ids(s.xs))
		}
	}
	for _, n := range []int{7, 60, 250} {
		xs := gen(n, 0, 5)
		sort.Slice(xs, func(i, j int) bool { return xs[i].key < xs[j].key })
		ys := gen(n, 0, 5)
		sort.SliceStable(ys, func(i, j int) bool { return ys[i].key < ys[j].key })
		fmt.Println(n, ids(xs), ids(ys), xs[:3], ys[:3])
	}

	u := Uint64Slice{5, 1 << 63, 3, 0, 18446744073709551615, 3}
	sort.Sort(u)
	b := BoolSlice{true, false, true, false}
	sort.Sort(b)
	ss := []string{"b", "", "ação", "a", "B", "ab"}
	sort.Strings(ss)
	var zero float64
	nan := zero / zero
	fs := []float64{2, nan, -1, 0, -zero, 1 / zero, nan, 0.5}
	sort.Float64s(fs)
	is := []int{3, -1, 2, -1, 9}
	sort.Ints(is)
	fmt.Println(u, b, ss, fs, is)
}
