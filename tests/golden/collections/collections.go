// Package main exercita slices (aliasing, cap, append, copy, 3 índices),
// maps (nil, zero value, comma-ok, delete durante range) e ponteiros para
// valores não-struct (&x, &s[i], &o.f, new).
package main

import "fmt"

type Counter struct {
	Hits int
	Tags []string
}

var sink any

func swap(a, b *int) { *a, *b = *b, *a }

func bump(p *int) { *p++ }

func sum(xs ...int) (total int) {
	for _, x := range xs {
		total += x
	}
	return
}

func main() {
	// Aliasing: fatias compartilham o array até o append realocar.
	base := make([]int, 3, 5)
	a := base[:2]
	a = append(a, 7) // cabe: escreve em base[2]
	b := append(base, 8, 9)
	c := append(base, 10, 11, 12) // não cabe: realoca
	c[0] = 100
	fmt.Println(base, a, b, c, len(c), cap(c), cap(b))
	d := base[1:2:3]
	d = append(d, 50) // cabe (cap 2): sobrescreve base[2]
	d = append(d, 60) // não cabe: realoca
	fmt.Println(base, d, len(d), cap(d))

	// Crescimento: sequência de cap igual à do runtime Go. O slice escapa
	// (sink) porque o Go 1.25 dá a slices que não escapam um buffer de 32
	// bytes no stack no primeiro append (otimização do compilador).
	var grow []string
	sink = &grow
	caps := []int{}
	for i := 0; i < 40; i++ {
		grow = append(grow, "x")
		if len(caps) == 0 || caps[len(caps)-1] != cap(grow) {
			caps = append(caps, cap(grow))
		}
	}
	fmt.Println(caps, grow == nil, len(grow[5:9]))

	// copy com sobreposição e slice nil.
	s := []int{1, 2, 3, 4, 5}
	n := copy(s[1:], s)
	var nilSlice []int
	fmt.Println(s, n, nilSlice == nil, len(nilSlice), nilSlice, sum(), sum(s...), sum(1, 2))
	nilSlice = append(nilSlice, 1)
	fmt.Println(nilSlice, nilSlice == nil, cap(nilSlice))

	// Structs em slices: elementos atualizados in-place.
	cs := []Counter{{Hits: 1}, {Hits: 2}}
	first := &cs[0]
	cs[0] = Counter{Hits: 10, Tags: []string{"t"}}
	first.Hits++
	fmt.Println(cs[0].Hits, len(cs[0].Tags), first.Hits)

	// Maps: nil, zero value, comma-ok, delete durante range.
	var nm map[string]int
	v, ok := nm["x"]
	fmt.Println(nm == nil, len(nm), nm["x"], v, ok)
	m := map[string]int{"a": 1, "b": 2, "c": 3}
	v, ok = m["b"]
	fmt.Println(v, ok, m)
	for k := range m {
		delete(m, k)
	}
	m["z"] = 26
	fmt.Println(m, len(m))
	groups := map[int][]string{}
	groups[1] = append(groups[1], "um")
	groups[1] = append(groups[1], "uno")
	fmt.Println(groups, len(groups[2]))

	// Ponteiros para não-struct.
	x, y := 1, 2
	swap(&x, &y)
	px := &x
	bump(px)
	bump(&y)
	fmt.Println(x, y, *px, px == &x, &x == &y)
	elem := &s[2]
	*elem = 99
	cnt := Counter{}
	hits := &cnt.Hits
	*hits += 5
	fmt.Println(s, cnt.Hits, hits == &cnt.Hits)
	np := new(int)
	*np = 42
	q := np
	*q++
	fmt.Println(*np, *q, np == q)
}
