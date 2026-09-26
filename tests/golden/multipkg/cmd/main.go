package main

import (
	"fmt"

	"g2d.test/multipkg/geom"
)

type Square struct{ Side int }

func (s Square) Area() int { return s.Side * s.Side }

func main() {
	p := geom.Point{X: 1, Y: 2}
	q := p // cópia: struct de outro pacote tem semântica de valor
	q.Grow(10)
	fmt.Println(p, q, p.Add(q))

	n := geom.New(1, 1)
	n.Grow(1)
	fmt.Println(*n, geom.Scale)

	path := geom.Path{p, q}
	fmt.Println(path.Len(), len(path))

	shapes := []geom.Shape{geom.Rect{Max: geom.Point{X: 2, Y: 3}}, Square{4}}
	for _, s := range shapes {
		fmt.Println(s.Area())
	}

	var c geom.Counter
	c.Inc()
	c.Inc()
	fmt.Println(c)

	geom.Hit()
	geom.Hits += 2
	h := &geom.Hits
	*h *= 10
	fmt.Println(geom.Hits, *h)
}
