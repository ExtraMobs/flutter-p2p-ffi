// Structs anônimas de pacotes diferentes: mesmo tipo na atribuição, na
// comparação e na type assertion.
package main

import (
	"fmt"

	"g2d.test/anoncross/a"
	"g2d.test/anoncross/b"
)

func main() {
	p, q := a.Pair(), b.Pair()
	p = q
	var v any = a.Pair()
	_, ok := v.(struct{ X int })
	fmt.Println(p.X, ok)

	fmt.Println(a.Pair() == b.Pair(), a.Pair() == struct{ X int }{3})
	fmt.Println(b.Same(a.Pair()), b.Same(b.Tagged()), b.Same(struct{ X int }{9}))

	var t any = b.Tagged()
	_, tok := t.(struct{ X int })
	fmt.Println(tok)

	x, y := a.Box(), b.Box()
	x = y
	x.Inner = a.Pair()
	x.Tags = append(x.Tags, "u")
	fmt.Println(x, y, x.At == y.At)
	fmt.Printf("%T\n", a.Pair())
	fmt.Println(a.Count())
}
