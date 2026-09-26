// Package geom é a library importada pelo cmd: tipos, métodos, constantes e
// interfaces usados de outro pacote.
package geom

import "fmt"

const Scale = 3

type Point struct{ X, Y int }

func (p Point) Add(q Point) Point { return Point{p.X + q.X, p.Y + q.Y} }

func (p *Point) Grow(d int) {
	p.X += d
	p.Y += d
}

func (p Point) String() string { return fmt.Sprint("(", p.X, ",", p.Y, ")") }

type Path []Point

func (ps Path) Len() int { return len(ps) }

type Shape interface{ Area() int }

type Rect struct{ Min, Max Point }

func (r Rect) Area() int { return (r.Max.X - r.Min.X) * (r.Max.Y - r.Min.Y) }

type Counter int

func (c *Counter) Inc() { *c++ }

func New(x, y int) *Point { return &Point{x * Scale, y * Scale} }

// Hits é uma var exportada sem inicializador: outro pacote a lê, escreve e
// toma o endereço.
var Hits int

func Hit() { Hits++ }
