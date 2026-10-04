// Package tok declara o tipo que o obj importa com ponto.
package tok

type TokenType byte

const (
	TNull   TokenType = '0'
	TString TokenType = 's'
)

type Token struct {
	Type TokenType
	Str  string
}
