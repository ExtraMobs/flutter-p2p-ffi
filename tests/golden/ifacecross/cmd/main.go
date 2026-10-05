// Repro de interfaces satisfeitas por tipo de outro pacote (D8): b.Namer/a.T
// sem import entre eles, *a.P por ponteiro, type assertion e type switch em
// b sobre tipos de a, interface anônima entre pacotes, fmt.Stringer e
// sort.Interface de tipos que não importam fmt/sort.
package main

import (
	"fmt"
	"io"
	"sort"

	"g2d.test/ifacecross/a"
	"g2d.test/ifacecross/b"
	"g2d.test/ifacecross/tok"
)

func main() {
	fmt.Println(b.Greet(a.T{Name: "t"}))
	var n b.Namer = a.NewP()
	fmt.Println(n.Hello(), n.Hello())
	fmt.Println(tok.Token{Type: '{'})
	fmt.Printf("%v %s\n", tok.Token{Type: '['}, tok.Token{Type: '('})

	var e interface{ Hello() string } = a.T{Name: "anon"}
	fmt.Println(e.Hello())

	fmt.Println(b.Name(a.U{}), b.Name(1))
	fmt.Println(b.Kind(a.Op(3)), b.Kind(a.U{}), b.Kind("x"))
	var f interface{ Apply(int) int } = a.Op(5)
	fmt.Println(b.Run(f, 2))

	s := a.Ints{3, 1, 2}
	sort.Sort(s)
	fmt.Println(s, sort.IsSorted(s))

	data, err := io.ReadAll(a.NewSrc("leitor"))
	fmt.Println(string(data), err)
}
