package main

import "fmt"

// Métodos Go com o nome de membros das bases do golib_dart (StringBase,
// FloatBase): sem `$`, sobrescreveriam a base com outra assinatura.
type Redactable string

func (s Redactable) ToBytes() []byte { return []byte("<" + string(s) + ">") }

type Ratio float64

func (r Ratio) ToDouble() string { return fmt.Sprintf("r=%.1f", float64(r)) }

func (r Ratio) ToInteger() int { return int(r) * 10 }

type byteser interface{ ToBytes() []byte }

func main() {
	s := Redactable("x")
	var b byteser = s
	fmt.Println(string(s.ToBytes()), string(b.ToBytes()), s+"y", len(s))
	r := Ratio(2.5)
	fmt.Println(r.ToDouble(), r.ToInteger(), r*2)
}
