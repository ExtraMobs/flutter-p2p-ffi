package main

import (
	"fmt"

	"g2d.test/promotedeep/a"
	"g2d.test/promotedeep/b"
	"g2d.test/promotedeep/c"
)

func main() {
	var x c.X
	fmt.Println(c.RevealX(x))
	x.Name = "x"
	fmt.Println(c.RevealX(x), x.Hello())

	y := c.Y{W: &b.W{T: a.T{Name: "y"}}}
	fmt.Println(c.RevealY(y), y.Hello())

	s := b.S{T: a.T{Name: "s"}}
	fmt.Println(c.RevealS(s), s.Hello(), s.T.Hello())

	z := &c.Z{}
	fmt.Println(c.BumpZ(z), c.BumpZ(z), z.Cnt)
}
