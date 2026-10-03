// Package a devolve structs anônimas: no Go, `struct{ X int }` é o mesmo
// tipo em qualquer pacote.
package a

type Point struct{ X, Y int }

func Pair() struct{ X int } { return struct{ X int }{3} }

// Box aninha uma struct anônima e usa um tipo nomeado exportado.
func Box() struct {
	Name  string
	At    Point
	Inner struct{ X int }
	Tags  []string
} {
	b := struct {
		Name  string
		At    Point
		Inner struct{ X int }
		Tags  []string
	}{Name: "a", At: Point{1, 2}}
	b.Inner.X = 7
	b.Tags = append(b.Tags, "t")
	return b
}

// Count usa uma struct anônima com campo não exportado (só deste pacote).
func Count() int {
	c := struct{ n int }{n: 1}
	c.n++
	return c.n
}
