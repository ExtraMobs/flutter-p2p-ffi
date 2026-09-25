// Package main exercita interfaces: métodos, satisfação implícita, error
// customizado, Stringer no fmt, type assertion (comma-ok e falha
// recuperada), type switch e valor × ponteiro na interface.
package main

import "fmt"

type Shape interface {
	Area() float64
	Name() string
}

type Rect struct{ W, H float64 }

type Circle struct{ R float64 }

func (r Rect) Area() float64  { return r.W * r.H }
func (r Rect) Name() string    { return "rect" }
func (c *Circle) Area() float64 { return 3 * c.R * c.R }
func (c *Circle) Name() string  { return "circle" }
func (c *Circle) Grow()         { c.R++ }

type NotFound struct{ Key string }

func (e NotFound) Error() string { return "não encontrado: " + e.Key }

type Point struct{ X, Y int }

func (p Point) String() string { return fmt.Sprint("(", p.X, ",", p.Y, ")") }

func find(k string) error {
	if k == "x" {
		return NotFound{k}
	}
	return nil
}

func describe(s Shape) string {
	switch v := s.(type) {
	case Rect:
		return fmt.Sprint("Rect ", v.W, "x", v.H)
	case *Circle:
		v.Grow()
		return fmt.Sprint("Circle r=", v.R)
	default:
		return "?"
	}
}

func total(shapes []Shape) float64 {
	t := 0.0
	for _, s := range shapes {
		t += s.Area()
	}
	return t
}

func nilAssert() (msg string) {
	defer func() { msg = fmt.Sprint(recover()) }()
	var nothing any
	_ = nothing.(Rect)
	return "sem panic"
}

func main() {
	c := &Circle{R: 1}
	shapes := []Shape{Rect{2, 3}, c}
	fmt.Println(total(shapes), shapes[0].Name(), shapes[1].Name())
	fmt.Println(describe(shapes[0]), describe(shapes[1]), c.R)

	var s Shape = Rect{1, 1}
	r, ok := s.(Rect)
	_, isCircle := s.(*Circle)
	fmt.Println(r.W, ok, isCircle)

	err := find("x")
	fmt.Println(err, err != nil, find("y") == nil)
	nf, isNF := err.(NotFound)
	fmt.Println(isNF, nf.Key, nilAssert())

	fmt.Println(Point{1, 2}, []Point{{3, 4}})

	var anything any = Point{5, 6}
	if st, ok := anything.(fmt.Stringer); ok {
		fmt.Println("stringer:", st.String())
	}
	defer func() { fmt.Println("recuperado:", recover()) }()
	_ = anything.(Shape).Area()
}
