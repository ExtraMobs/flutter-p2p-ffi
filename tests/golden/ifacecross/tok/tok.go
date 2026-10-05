// Package tok NÃO importa fmt: Token satisfaz fmt.Stringer estruturalmente.
// Sem `implements fmt.Stringer`, o fmt.Println de outro pacote formataria os
// campos em vez de chamar String(): errado em silêncio.
package tok

type Token struct {
	Type byte
	Str  string
}

func (t Token) String() string { return "<" + string(t.Type) + ">" }
