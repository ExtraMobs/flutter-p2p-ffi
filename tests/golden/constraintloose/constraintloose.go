// Constraints sem bound Dart comum: união mista (só move e compara), arrays
// com o mesmo elemento (github.com/rivo/uniseg), união de funcs
// (go.uber.org/fx) e ponteiro + interface de métodos (go.uber.org/zap).
package main

import "fmt"

// União mista: o corpo só move e compara valores.
type sliceElem interface{ bool | int64 | float64 | string }

func first[T sliceElem](v []T) any { return v[0] }

func count[T sliceElem](v []T, x T) int {
	n := 0
	for _, e := range v {
		if e == x {
			n++
		}
	}
	return n
}

// Arrays com o mesmo elemento (github.com/rivo/uniseg).
func propertySearch[E interface{ [3]int | [4]int }](dictionary []E, r rune) (result E) {
	from, to := 0, len(dictionary)
	for to > from {
		middle := (from + to) / 2
		cpRange := dictionary[middle]
		if int(r) < cpRange[0] {
			to = middle
			continue
		}
		if int(r) > cpRange[1] {
			from = middle + 1
			continue
		}
		return cpRange
	}
	return
}

// União de funcs (go.uber.org/fx): só nil e type switch.
type Func = func()
type ErrorFunc = func() error
type Callable interface{ ~func() | ~func() error }

func wrap[T Callable](x T) string {
	if x == nil {
		return "nil"
	}
	// Só um case func: o Dart testa subtipo (TODO/P2-runtime-type-switch-func.md).
	if fn, ok := any(x).(func() error); ok {
		return fmt.Sprint("err:", fn())
	}
	return "outro"
}

// Ponteiro + interface de métodos embutida (go.uber.org/zap).
type Marshaler interface{ Marshal() string }

type MarshalerPtr[T any] interface {
	*T
	Marshaler
}

type point struct{ x, y int }

func (p *point) Marshal() string { return fmt.Sprint(p.x, ",", p.y) }

func marshalAll[T any, P MarshalerPtr[T]](ms []P) []string {
	var out []string
	for _, m := range ms {
		out = append(out, m.Marshal())
	}
	return out
}

func main() {
	fmt.Println(first([]string{"a"}), first([]bool{true}), first([]float64{1.5}))
	fmt.Println(count([]int64{1, 2, 1}, 1), count([]string{"x"}, "y"))
	tab3 := [][3]int{{0, 9, 1}, {10, 19, 2}, {20, 29, 3}}
	tab4 := [][4]int{{0, 4, 7, 8}, {5, 9, 6, 6}}
	fmt.Println(propertySearch(tab3, 15), propertySearch(tab3, 40), propertySearch(tab4, 7))
	var nf Func
	fmt.Println(wrap(func() {}), wrap(func() error { return nil }), wrap(nf))
	fmt.Println(marshalAll[point]([]*point{{1, 2}, {3, 4}}))
}
