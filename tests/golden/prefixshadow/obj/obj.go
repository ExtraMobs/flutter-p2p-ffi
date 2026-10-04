// Package obj: parâmetro `tok` e campo `atlas` com o nome de pacotes
// importados. O g2d cita o pacote onde o Go não cita (constante dobrada
// `tok.TokenType(48)`, zero value do campo no construtor): o prefixo do
// import não pode ser sombreado pelo local.
package obj

import (
	"g2d.test/prefixshadow/atlas"
	. "g2d.test/prefixshadow/tok"
)

type Slab struct {
	atlas atlas.Atlas
	rows  []string
}

func NewSlab(a atlas.Atlas) *Slab { return &Slab{atlas: a} }

func (s Slab) Name() string { return s.atlas.Name }

func Reset(tok *Token) bool {
	if tok.Type == TString {
		tok.Type = TNull
		return true
	}
	return false
}

func Empty() Slab { return Slab{} }
