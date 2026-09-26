// strings.Builder: struct de shim por valor (campo, ponteiro, cópia com o
// pânico do Go, Grow com a classe de tamanho do alocador).
package main

import (
	"fmt"
	"strings"
)

type replay struct {
	name string
	sb   strings.Builder
}

func render(b *strings.Builder, parts ...string) {
	for i, p := range parts {
		if i > 0 {
			b.WriteByte(',')
		}
		b.WriteString(p)
	}
}

func try(f func()) (r any) {
	defer func() { r = recover() }()
	f()
	return
}

func main() {
	var b strings.Builder
	fmt.Println(b.Len(), b.Cap(), b.String() == "")
	n, err := b.WriteString("olá")
	b.WriteRune('→')
	b.WriteRune(-1)
	b.Write([]byte{'!'})
	fmt.Println(n, err, b.Len(), b.Cap(), b.String())
	b.Grow(100)
	fmt.Println(b.Len(), b.Cap())
	var r replay
	r.name = "x"
	render(&r.sb, "a", "b", "c")
	fmt.Println(r.sb.String(), r.sb.Len())
	c := b // cópia de Builder não-zero
	fmt.Println(try(func() { c.WriteString("x") }))
	fmt.Println(c.String() == b.String())
	b.Reset()
	fmt.Println(b.Len(), b.String() == "")
	var z strings.Builder
	z2 := z // cópia do zero: permitida
	z2.WriteString("ok")
	fmt.Println(z2.String(), z.Len())
}
