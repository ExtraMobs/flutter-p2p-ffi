// Conversão entre structs de mesmo subjacente (tags ignoradas), nomeadas e
// anônimas: o resultado é uma cópia.
package main

import "fmt"

type Inner struct{ N int }

type A struct {
	X     int
	In    Inner
	Inner        // embutido
	tag   string `json:"t"`
}

type B struct {
	X     int
	In    Inner
	Inner
	tag   string
}

func (b B) Sum() int { return b.X + b.In.N + b.N }

type P struct{ Lat, Lng float64 }

func main() {
	a := A{X: 1, In: Inner{2}, Inner: Inner{3}, tag: "a"}
	b := B(a)
	a.In.N = 100 // b é cópia
	a.N = 200
	fmt.Println(b, b.Sum(), a.In.N, b.tag)
	p := P(struct{ Lat, Lng float64 }{1.5, -2})
	q := struct{ Lat, Lng float64 }(p)
	fmt.Println(p, q.Lat, B(A{X: 9}).Sum())
}
