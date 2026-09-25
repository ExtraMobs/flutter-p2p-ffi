// Package main exercita arrays [N]T como valores: cópia em atribuição e
// argumento, ==, chave de map, arrays aninhados, fatia compartilhando o
// armazenamento, ponteiro para elemento e para o array.
package main

import "fmt"

type Pt struct {
	Pos [2]int
}

func sum(a [4]int) int {
	s := 0
	for _, v := range a {
		s += v
	}
	a[0] = 100 // só a cópia
	return s
}

func main() {
	a := [4]int{1, 2, 3}
	b := a
	b[0] = 9
	fmt.Println(a, b, a == b, len(a), sum(a), a[0])
	names := [...]string{"x", "y"}
	fmt.Println(names, len(names), names == [2]string{"x", "y"})

	s := a[1:3]
	s[0] = 50
	s = append(s, 60) // cabe: escreve em a[3]
	fmt.Println(a, s, cap(s))
	p := &a[2]
	*p = 7
	pa := &a
	pa[0] = -1
	fmt.Println(a, pa[3])

	seen := map[[2]int]bool{{1, 2}: true}
	fmt.Println(seen[[2]int{1, 2}], seen[[2]int{2, 1}])

	var grid [2][3]int
	grid[1][2] = 5
	row := grid[1]
	row[0] = 8
	fmt.Println(grid, row)

	p1 := Pt{Pos: [2]int{1, 2}}
	p2 := p1
	p2.Pos[0] = 10
	fmt.Println(p1, p2, p1 == p2)
}
