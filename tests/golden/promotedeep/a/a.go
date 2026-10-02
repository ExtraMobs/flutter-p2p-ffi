// Package a: donos de fato de métodos não exportados promovidos através de
// dois saltos de pacote (a → b → c):
// TODO/P1-design-promocao-transitiva-nao-exportada.
package a

type T struct{ Name string }

func (t T) Hello() string  { return "hi " + t.Name }
func (t T) secret() string { return "a:" + t.Name }

type I interface{ secret() string }

func Reveal(i I) string { return i.secret() }

// Cnt: não-struct com método não exportado de receptor ponteiro.
type Cnt int

func (c *Cnt) bump()     { *c += 2 }
func (c Cnt) peek() int { return int(c) }

type Bumper interface {
	bump()
	peek() int
}

func Bump(b Bumper) int {
	b.bump()
	return b.peek()
}
