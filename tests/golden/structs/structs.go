// Package main exercita a semântica de valor das structs: cópia em
// atribuição/argumento/retorno/range, atribuição in-place vista por ponteiros,
// receptores valor × ponteiro, igualdade estrutural e structs como chave.
package main

import "fmt"

type Point struct {
	X, Y int
}

type Box struct {
	Name  string
	Min   Point
	Max   Point
	Owner *Point
}

func (p Point) Moved(dx int) Point {
	p.X += dx // mexe só na cópia do receptor
	return p
}

func (p *Point) Move(dx int) {
	p.X += dx
}

func (b Box) Width() int { return b.Max.X - b.Min.X }

func grow(b Box) Box {
	b.Max.X *= 2
	return b
}

func origin() Point { return Point{} }

func main() {
	a := Point{1, 2}
	b := a // cópia
	b.X = 10
	fmt.Println(a, b, a == b, a == Point{1, 2})

	p := &a // p aponta para a
	a = Point{7, 8}
	fmt.Println(*p, p.X, *p == a)
	*p = Point{3, 4}
	fmt.Println(a)

	c := a.Moved(5)
	fmt.Println(a, c)
	a.Move(100)
	p.Move(1)
	fmt.Println(a)

	box := Box{Name: "caixa", Min: Point{0, 0}, Max: Point{4, 3}, Owner: p}
	box2 := grow(box)
	fmt.Println(box.Width(), box2.Width(), box.Max, box2.Max, box2.Owner == box.Owner)
	box2.Min.Y = 9
	fmt.Println(box.Min, box2.Min, box == box2)
	box3 := box
	fmt.Println(box == box3, box3.Owner == p)
	box3.Owner = &Point{3, 4}
	fmt.Println(box == box3, *box3.Owner == *box.Owner)

	inner := &box.Max
	box.Max = Point{50, 60}
	fmt.Println(*inner, box.Width())

	pts := []Point{{1, 1}, {2, 2}}
	for _, pt := range pts {
		pt.X = 99 // cópia do elemento
	}
	pts[0].Y = 7
	q := pts[1]
	q.X = 42
	fmt.Println(pts, q)

	seen := map[Point]string{{1, 2}: "a"}
	seen[Point{3, 4}] = "b"
	fmt.Println(seen[Point{1, 2}], seen[Point{3, 4}], len(seen), origin() == Point{})

	var zero Box
	fmt.Println(zero, zero.Owner == nil)
}
