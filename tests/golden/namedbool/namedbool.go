// Tipo nomeado sobre bool (github.com/ipld/go-ipld-prime/fluent/qp): classe
// go.GoBool; condições desembrulham $b, !/&&/|| e comparações embrulham.
package main

import "fmt"

type Flag bool

func (f Flag) String() string {
	if f {
		return "on"
	}
	return "off"
}

type Opt bool

const Enabled Opt = true

func (o *Opt) Toggle() { *o = !*o }

type Config struct {
	Debug Flag
	Fast  Opt
}

func check(n int) Flag { return n > 2 }

func main() {
	var f Flag = true
	g := !f
	fmt.Println(f, !f, g, f && g, f || g, f == g, f != g)
	h := check(3) && f
	fmt.Println(h, check(1), bool(h), Flag(1 < 2))
	var o Opt
	o.Toggle()
	fmt.Println(o, o == Enabled, !o)
	c := Config{Debug: f, Fast: Enabled}
	if bool(c.Debug) && bool(c.Fast) {
		fmt.Println("ambos")
	}
	for i := 0; Flag(i < 2); i++ {
		fmt.Print(i, " ")
	}
	switch {
	case c.Debug == false:
		fmt.Println("nunca")
	case !bool(c.Debug):
		fmt.Println("não")
	case bool(c.Debug):
		fmt.Println("debug", c)
	}
	m := map[Flag]int{true: 1, false: 0}
	fmt.Printf("%v %t %v %T\n", m[f], o, Opt(false), o)
	var zero Opt
	var i any = zero
	_, isOpt := i.(Opt)
	fmt.Println(zero, isOpt, i == any(false))
}
