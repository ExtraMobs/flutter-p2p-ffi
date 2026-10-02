package main

import (
	"fmt"

	"g2d.test/promotecross/a"
	"g2d.test/promotecross/b"
	"g2d.test/promotecross/both"
	"g2d.test/promotecross/c"
	"g2d.test/promotecross/d"
)

func main() {
	w := b.W{T: a.T{Name: "w"}}
	fmt.Println(w.Hello(), a.Reveal(w))

	wp := b.WPtr{T2: &a.T2{N: 1}}
	wp.Bump()
	fmt.Println(wp.Value())

	cc := c.C{Mid: b.Mid{T3: a.T3{Tag: "x"}}}
	fmt.Println(cc.Label())

	amb := both.Ambi{}
	fmt.Println(amb.Kinded1.Kind(), amb.Kinded2.Kind())

	bo := both.Both{Whisperer1: a.Whisperer1{W: "1"}, Whisperer2: d.Whisperer2{W: "2"}}
	fmt.Println(a.Hear1(bo), d.Hear2(bo))
}
