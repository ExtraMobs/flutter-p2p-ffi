// Package tok imita github.com/polydawn/refmt/tok: tipos e constantes que
// os pacotes de refmt importam com `import .`.
package tok

import "fmt"

type TokenType byte

const (
	TMapOpen  TokenType = '{'
	TMapClose TokenType = '}'
	TString   TokenType = 's'
)

type Token struct {
	Type TokenType
	Str  string
}

func (t Token) String() string {
	if t.Type == TString {
		return fmt.Sprintf("<%c:%s>", t.Type, t.Str)
	}
	return fmt.Sprintf("<%c>", t.Type)
}

var Count int

func IsValue(t TokenType) bool {
	Count++
	return t == TString
}
