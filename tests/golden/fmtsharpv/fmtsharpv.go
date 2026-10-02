// %#v: sintaxe Go do valor (básicos, structs, slices, arrays, maps, nil,
// GoStringer), com os nomes de tipo do Go.
package main

import (
	"errors"
	"fmt"
	"strings"
)

type P struct{ X, Y int }

type Color string

type Level uint8

type IDs []string

type Hash [3]byte

type Tags map[string]int

type Node struct {
	Name  string
	Next  *Node
	Items []P
	Meta  map[string][]int
	Any   any
	Err   error
}

type Mixed struct {
	P
	B    []byte
	Arr  [2]bool
	C    Color
	L    Level
	F    float64
	Z    complex128
	IDs  IDs
	Tags Tags
	u    uint
	Nils []int
	Nilm map[int]string
	Nest [][]string
}

type G struct{ n int }

func (g G) GoString() string { return fmt.Sprintf("G<%d>", g.n) }

type S struct{ n int }

func (s S) String() string { return "str" }

type H struct {
	G G
	S S
}

type PG struct{ n int }

func (p *PG) GoString() string { return "PG!" }

func main() {
	fmt.Printf("%#v %#v %#v %#v\n", 1, int8(-3), uint(7), uint8(200))
	fmt.Printf("%#v %#v %#v %#v\n", 1.5, float32(2), 1e21, 100000.0)
	fmt.Printf("%#v %#v %#v\n", "a\"b\n", true, 'x')
	fmt.Printf("%#v %#v\n", complex(1, -2), uintptr(10))
	fmt.Printf("%#v %#v\n", Color("red"), Level(3))
	fmt.Printf("%#v\n", nil)

	p := P{1, 2}
	fmt.Printf("%#v\n", p)
	fmt.Printf("%#v\n", &p)
	var np *P
	fmt.Printf("%#v\n", np)
	fmt.Printf("%#v|%+v|%v\n", []P{{1, 2}, {3, 4}}, p, p)

	fmt.Printf("%#v\n", []int{1, 2, 3})
	fmt.Printf("%#v\n", []int{})
	var ns []string
	fmt.Printf("%#v\n", ns)
	fmt.Printf("%#v\n", []string{"a", "b"})
	fmt.Printf("%#v\n", [][]int{{1}, {2, 3}, nil})
	fmt.Printf("%#v\n", [3]int{1, 2, 3})
	fmt.Printf("%#v\n", [2]P{})
	fmt.Printf("%#v\n", []byte("hi"))
	fmt.Printf("%#v\n", []byte(nil))
	fmt.Printf("%#v\n", [2]byte{1, 255})
	fmt.Printf("%#v\n", []float64{1, 2.5})
	fmt.Printf("%#v\n", []any{1, "a", nil, P{1, 2}, 2.5})
	fmt.Printf("%#v\n", []error{nil, errors.New("x")}[0])

	fmt.Printf("%#v\n", map[string]int{"b": 2, "a": 1})
	fmt.Printf("%#v\n", map[int]bool{})
	var nm map[string]P
	fmt.Printf("%#v\n", nm)
	fmt.Printf("%#v\n", map[string][]int{"x": {1, 2}, "y": nil})
	fmt.Printf("%#v\n", map[P]string{{2, 1}: "b", {1, 2}: "a"})
	fmt.Printf("%#v\n", map[string]map[string]int{"o": {"i": 1}})

	fmt.Printf("%#v\n", IDs{"a", "b"})
	fmt.Printf("%#v\n", IDs(nil))
	fmt.Printf("%#v\n", Hash{1, 2, 3})
	fmt.Printf("%#v\n", Tags{"k": 1})

	n := Node{Name: "n", Items: []P{{1, 2}}, Meta: map[string][]int{"a": {1}}, Any: 5}
	fmt.Printf("%#v\n", n)
	n.Any = []int{1}
	n.Err = nil
	fmt.Printf("%#v\n", n.Any)
	fmt.Printf("%#v\n", &n)
	m := Mixed{P: P{1, 2}, B: []byte{1}, C: "c", L: 9, F: 3, Z: 1, IDs: IDs{"i"}, Tags: Tags{"t": 1}, u: 4,
		Nest: [][]string{{"a"}}}
	fmt.Printf("%#v\n", m)

	fmt.Printf("%#v|%v|%s\n", G{3}, G{3}, S{1})
	fmt.Printf("%#v\n", S{1})
	fmt.Printf("%#v\n", H{G{1}, S{2}})
	fmt.Printf("%#v|%#v\n", &PG{1}, PG{1})
	fmt.Printf("%#v\n", []G{{1}, {2}})
	fmt.Printf("%10v|%-6v|\n", []int{1}, "x")
	var a any = P{5, 6}
	fmt.Printf("%#v\n", a)

	// `#` em float e runa; erros do runtime em %#v.
	g := 3.5
	fmt.Printf("%#g|%#.3g|%#e|%#.0f|%#10.0e|%#v\n", g, 100000.0, g, 3.0, g, g)
	fmt.Printf("%#g|%#G|%#.0g\n", 1e6, float32(0.1), 0.0)
	fmt.Printf("%#q|%#+q|%#v|%#U\n", 'x', 'é', 'y', 'z')
	fmt.Printf("%#v\n", errors.New("boom"))
	var err error = fmt.Errorf("n=%d", 1)
	fmt.Printf("%#v\n", err)

	// Ponteiro aninhado não nil: (*T)(endereço); o teste compara a forma.
	n2 := Node{Name: "b", Next: &Node{Name: "a"}}
	fmt.Println(mask(fmt.Sprintf("%#v", n2)))
	fmt.Println(mask(fmt.Sprintf("%#v", []*P{&p, nil})))
	fmt.Println(mask(fmt.Sprintf("%#v", []any{&p})))
	fmt.Println(mask(fmt.Sprintf("%#v", map[string]*P{"k": &p})))
	fmt.Println(mask(fmt.Sprintf("%#v", fmt.Errorf("w: %w", errors.New("in")))))
	fmt.Println(strings.Contains(fmt.Sprintf("%#v", []*P{&p}), fmt.Sprintf("%p", &p)))
}

// mask troca o endereço de `(*T)(0x...)`, que nem o Go reproduz, por ADDR.
func mask(s string) string {
	out := ""
	for {
		i := strings.Index(s, ")(0x")
		if i < 0 {
			return out + s
		}
		j := i + 4
		for j < len(s) && (s[j] >= '0' && s[j] <= '9' || s[j] >= 'a' && s[j] <= 'f') {
			j++
		}
		out += s[:i] + ")(ADDR"
		s = s[j:]
	}
}
