// Package main exercita tipos declarados dentro de funções (içados),
// structs anônimas (tabelas de teste, igualdade, cópia) e interfaces
// anônimas com métodos.
package main

import "fmt"

type Named struct{ N int }

func (n Named) Name() string { return fmt.Sprint("n", n.N) }

func first() int {
	type pair struct{ a, b int }
	p := pair{1, 2}
	q := p
	q.a = 10
	return p.a + q.a
}

func second() string {
	type pair struct{ s string }
	return pair{"dois"}.s
}

func describe(v interface{ Name() string }) string { return "<" + v.Name() + ">" }

func main() {
	fmt.Println(first(), second())

	tests := []struct {
		in   string
		want int
	}{
		{"a", 1},
		{"bb", 2},
		{in: "ccc", want: 3},
	}
	for _, tc := range tests {
		fmt.Println(tc.in, len(tc.in) == tc.want)
	}

	pt := struct{ X, Y int }{1, 2}
	other := struct{ X, Y int }{1, 2}
	cp := pt
	cp.X = 9
	fmt.Println(pt == other, pt, cp)

	var box struct {
		Items []string
		Count int
	}
	box.Items = append(box.Items, "x")
	box.Count++
	fmt.Println(box)

	var namer interface{ Name() string } = Named{7}
	fmt.Println(namer.Name(), describe(Named{8}), describe(namer))
	var anyv any = Named{9}
	if nm, ok := anyv.(interface{ Name() string }); ok {
		fmt.Println(nm.Name())
	}

	type celsius float64
	type reading struct {
		where string
		temp  celsius
	}
	rs := []reading{{"sala", 21.5}, {"rua", -3}}
	fmt.Println(rs, rs[1].temp+1)
}
