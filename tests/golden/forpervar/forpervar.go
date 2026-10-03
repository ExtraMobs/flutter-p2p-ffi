package main

import "fmt"

type P struct{ X int }

func main() {
	// Go ≥ 1.22: cada iteração tem a sua variável (caixa e struct).
	var ps []*int
	for i := 0; i < 3; i++ {
		ps = append(ps, &i)
	}
	for _, p := range ps {
		fmt.Print(*p, " ")
	}
	fmt.Println()
	var fs []func()
	for p := (P{0}); p.X < 3; p.X++ {
		fs = append(fs, func() { fmt.Print(p.X, " ") })
	}
	for _, f := range fs {
		f()
	}
	fmt.Println()
	// continue também passa pela cópia; a cópia vê o valor da iteração.
	var qs []*int
	for i := 0; i < 6; i++ {
		if i%2 == 0 {
			qs = append(qs, &i)
			continue
		}
		i++
	}
	for _, q := range qs {
		fmt.Print(*q, " ")
	}
	fmt.Println()
	// Sem post: ainda uma variável por iteração.
	var rs []*int
	for j := 0; j < 3; {
		rs = append(rs, &j)
		j++
	}
	for _, r := range rs {
		fmt.Print(*r, " ")
	}
	fmt.Println()
}
