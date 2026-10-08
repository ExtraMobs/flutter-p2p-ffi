// Shim de slices: funções genéricas da stdlib chamadas com slices sem nome,
// slice nomeado, structs por valor, floats com NaN, closures de comparação;
// efeitos no array original (Delete/DeleteFunc/Compact zeram a cauda,
// Insert/Replace in-place com sobreposição), cap do Grow/Clone/Concat e os
// pânicos do Go.
package main

import (
	"fmt"
	"math"
	"slices"
	"strings"
)

type IDs []string

type pt struct{ x, y int }

func try(name string, f func()) {
	defer func() { fmt.Println(name, "panic:", recover()) }()
	f()
}

func main() {
	ints := []int{5, 2, 8, 2, 9, 1}
	fmt.Println(slices.Contains(ints, 8), slices.Index(ints, 2), slices.Index(ints, 7))
	fmt.Println(slices.IndexFunc(ints, func(v int) bool { return v > 6 }), slices.ContainsFunc(ints, func(v int) bool { return v < 0 }))
	c := slices.Clone(ints)
	slices.Sort(c)
	fmt.Println(c, ints, len(c), cap(c), slices.IsSorted(c), slices.IsSorted(ints))
	fmt.Println(slices.Clone([]int(nil)) == nil, slices.Equal(ints, c), slices.Equal(c, []int{1, 2, 2, 5, 8, 9}))
	fmt.Println(slices.Compare([]int{1, 2}, []int{1, 3}), slices.Compare([]int{1, 2, 3}, []int{1, 2}), slices.Compare([]int{}, []int(nil)))
	fmt.Println(slices.Min(ints), slices.Max(ints))
	i, found := slices.BinarySearch(c, 5)
	j, found2 := slices.BinarySearch(c, 6)
	fmt.Println(i, found, j, found2)

	ids := IDs{"b", "c", "a", "c"}
	slices.Sort(ids)
	ids = slices.Compact(ids)
	fmt.Printf("%T %v %d\n", ids, ids, len(ids))
	ids = slices.Insert(ids, 1, "x", "y")
	fmt.Println(ids, len(ids), cap(ids))

	pts := []pt{{3, 1}, {1, 2}, {3, 0}, {2, 5}, {1, 1}}
	byX := func(a, b pt) int { return a.x - b.x }
	st := slices.Clone(pts)
	slices.SortStableFunc(st, byX)
	fmt.Println(st, slices.IsSortedFunc(st, byX))
	slices.SortFunc(pts, func(a, b pt) int {
		if a.x != b.x {
			return a.x - b.x
		}
		return a.y - b.y
	})
	fmt.Println(pts, slices.MinFunc(pts, byX), slices.MaxFunc(pts, byX))
	k, ok := slices.BinarySearchFunc(pts, 2, func(p pt, x int) int { return p.x - x })
	fmt.Println(k, ok)

	fl := []float64{3, math.NaN(), -1, math.Inf(1), 0}
	slices.Sort(fl)
	fmt.Println(fl, slices.Min(fl), slices.Max([]float64{1, 2}))
	n, nok := slices.BinarySearch(fl, math.NaN())
	fmt.Println(n, nok)

	// Efeitos no array original.
	orig := []int{1, 2, 3, 4, 5}
	d := slices.Delete(orig, 1, 3)
	fmt.Println(d, orig)
	orig = []int{1, 2, 3, 4, 5, 6}
	d = slices.DeleteFunc(orig, func(v int) bool { return v%2 == 0 })
	fmt.Println(d, orig)
	orig = []int{1, 1, 2, 2, 2, 3}
	d = slices.CompactFunc(orig, func(a, b int) bool { return a == b })
	fmt.Println(d, orig)
	big := make([]int, 4, 10)
	copy(big, []int{1, 2, 3, 4})
	ins := slices.Insert(big, 1, big[2:4]...) // sobreposição: os valores originais
	fmt.Println(ins, big[:6])
	rep := slices.Replace([]int{1, 2, 3, 4, 5}, 1, 4, 9)
	fmt.Println(rep)
	r := []int{0, 1, 2, 3, 4, 5, 6, 7}
	rep = slices.Replace(r[:6], 1, 3, r[3:7]...)
	fmt.Println(rep, r)

	g := slices.Grow([]int{1}, 10)
	fmt.Println(g, len(g), cap(g), cap(slices.Clip(g)))
	cc := slices.Concat([]int{1}, nil, []int{2, 3})
	fmt.Println(cc, len(cc), cap(cc), slices.Concat[[]int]() == nil)
	fmt.Println(slices.Repeat([]string{"a", "b"}, 3))
	rv := []string{"x", "y", "z"}
	slices.Reverse(rv)
	fmt.Println(rv)

	words := []string{"Go", "dart", "Ab"}
	fmt.Println(slices.EqualFunc(words, []string{"go", "DART", "ab"}, strings.EqualFold),
		slices.CompareFunc([]int{1, 2}, []string{"1", "3"}, func(a int, b string) int { return strings.Compare(fmt.Sprint(a), b) }))
	slices.SortFunc(words, strings.Compare)
	fmt.Println(words)

	// pdqsort de verdade (> 12 elementos): a ordem dos empates do SortFunc
	// (instável) e o stable têm de bater com o Go.
	big2 := make([]pt, 500)
	seed := uint32(7)
	for i := range big2 {
		seed = seed*1664525 + 1013904223
		big2[i] = pt{int(seed>>24) % 16, i}
	}
	st2 := slices.Clone(big2)
	slices.SortFunc(big2, byX)
	slices.SortStableFunc(st2, byX)
	h, h2 := 0, 0
	for i := range big2 {
		h = (h*31 + big2[i].y) % 1000003
		h2 = (h2*31 + st2[i].y) % 1000003
	}
	fmt.Println(h, h2, big2[:5], slices.IsSortedFunc(st2, byX))
	fbig := make([]float64, 300)
	for i := range fbig {
		seed = seed*1664525 + 1013904223
		fbig[i] = float64(seed%1000) / 7
		if i%37 == 0 {
			fbig[i] = math.NaN()
		}
	}
	slices.Sort(fbig)
	fmt.Println(fbig[:10], fbig[290:], slices.IsSorted(fbig))

	try("Min", func() { slices.Min([]int{}) })
	try("MaxFunc", func() { slices.MaxFunc([]int(nil), func(a, b int) int { return a - b }) })
	try("Grow", func() { slices.Grow([]int{}, -1) })
	try("Insert", func() { slices.Insert([]int{1}, 3, 2) })
	try("Delete", func() { slices.Delete([]int{1, 2}, 1, 3) })
	try("Repeat", func() { slices.Repeat([]int{1}, -1) })
	// Mensagens do Go para s[i:j:k] (boundsSlice3B/3C, também negativos).
	s, i3, j3, k3, n3 := []int{1, 2}, 1, 3, 2, -1
	try("3B", func() { _ = s[i3:j3:k3] })
	try("3C", func() { _ = s[j3:k3:k3] })
	try("3A", func() { _ = s[i3:i3:j3] })
	try("3C-", func() { _ = s[n3:k3:k3] })
	try("3B-", func() { _ = s[i3:n3:k3] })
	try("3A-", func() { _ = s[i3:k3:n3] })
}
