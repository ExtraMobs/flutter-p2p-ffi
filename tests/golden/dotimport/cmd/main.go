// Repro de github.com/polydawn/refmt/pretty e refmt/shared: `import .` de
// um pacote do grafo (tipo, constante, função, variável e método).
package main

import (
	"fmt"

	. "g2d.test/dotimport/tok"
)

type pump struct{ toks []Token }

func (p *pump) step(tt TokenType, s string) {
	p.toks = append(p.toks, Token{Type: tt, Str: s})
}

func main() {
	var p pump
	p.step(TMapOpen, "")
	p.step(TString, "k")
	p.step(TMapClose, "")
	for _, t := range p.toks {
		fmt.Println(t, IsValue(t.Type), t.String())
	}
	Count += 10
	fmt.Println(Count, TString, Token{Type: TMapClose})
}
