package b

import "g2d.test/anoncross/a"

func Pair() struct{ X int } { return struct{ X int }{4} }

// Tagged difere de struct{ X int } só pela tag: outro tipo.
func Tagged() struct {
	X int `json:"x"`
} {
	return struct {
		X int `json:"x"`
	}{5}
}

// Same diz se v é a mesma struct anônima que b.Pair devolve.
func Same(v any) bool {
	_, ok := v.(struct{ X int })
	return ok
}

func Box() struct {
	Name  string
	At    a.Point
	Inner struct{ X int }
	Tags  []string
} {
	return struct {
		Name  string
		At    a.Point
		Inner struct{ X int }
		Tags  []string
	}{Name: "b", At: a.Point{X: 3}, Inner: Pair()}
}
