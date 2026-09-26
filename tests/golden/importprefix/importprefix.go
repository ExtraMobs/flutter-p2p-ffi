// Nome Dart declarado na library igual a um prefixo de import: campo `Time`
// (Dart `time`, sombreia o prefixo no corpo e no construtor da classe),
// método `Fmt`, função `Strings` e campo de struct anônima. O prefixo ganha
// `_`; parâmetro local continua com o nome Go.
package main

import (
	"fmt"
	"strings"
	"time"
)

type P struct {
	Time    time.Duration
	Timeout time.Duration
}

func (p P) Fmt() string { return fmt.Sprint(p.Time, "/", p.Timeout) }

func Strings(s ...string) string { return strings.Join(s, ",") }

func show(time time.Duration) { fmt.Println(time) }

func main() {
	p := P{Time: 2 * time.Second}
	fmt.Println(p.Time, p.Timeout, p.Fmt())
	show(p.Time)
	fmt.Println(Strings("a", "b"))
	var anon struct{ Strings []string }
	anon.Strings = append(anon.Strings, strings.TrimPrefix("xy", "x"))
	fmt.Println(anon.Strings)
}
