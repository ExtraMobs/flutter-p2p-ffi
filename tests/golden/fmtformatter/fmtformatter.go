// fmt.Formatter/fmt.State (github.com/cockroachdb/redact): Format chamado para
// todo verbo, com flags/largura/precisão, receptor nil e pânico no método.
package main

import (
	"fmt"
	"strings"
)

// Safe imita as SafeString/RedactableString de github.com/cockroachdb/redact.
type Safe string

func (s Safe) Format(f fmt.State, verb rune) {
	w, ok := f.Width()
	p, pok := f.Precision()
	fmt.Fprintf(f, "<%s|%c|%d|%v|%d|%v|%v|%v>", string(s), verb, w, ok, p, pok, f.Flag('+'), f.Flag('#'))
}

type Pt struct{ X, Y int }

func (p *Pt) Format(f fmt.State, verb rune) {
	if p == nil {
		f.Write([]byte("nil-pt"))
		return
	}
	fmt.Fprintf(f, "(%d,%d)", p.X, p.Y)
}

type bomb struct{}

func (bomb) Format(f fmt.State, verb rune) { panic("kaboom") }

func main() {
	fmt.Printf("%v %+8s %.3d %#x\n", Safe("a"), Safe("b"), Safe("c"), Safe("d"))
	fmt.Println(Safe("e"), []Safe{"f"})
	p := &Pt{1, 2}
	fmt.Println(p, *p)
	fmt.Printf("%v|%s\n", p, fmt.Sprint(p))
	var np *Pt
	fmt.Println(np)
	fmt.Println(bomb{})
	var sb strings.Builder
	fmt.Fprintf(&sb, "%v", Safe("g"))
	fmt.Println(sb.String())
}
