// Package main exercita promoção por embedding de tipo nomeado não-struct
// com método de receptor ponteiro (por valor e por ponteiro, direto, em
// profundidade 2, sombreado e por interface) e de tipos locais (inclusive
// homônimos em funções diferentes): TODO/P1-construcao-promocao-dart-invalido.
package main

import "fmt"

type Counter int

func (c *Counter) Inc()     { *c++ }
func (c Counter) Show() int { return int(c) * 10 }

type Holder struct{ Counter }

type PtrHolder struct{ *Counter }

// Outer: Inc promovido em profundidade 2 (Outer → Holder → Counter).
type Outer struct {
	Holder
	Name string
}

// Shadow sombreia Show, então o Counter vai por forwarders inline.
type Shadow struct{ Counter }

func (Shadow) Show() int { return -1 }

type Incer interface{ Inc() }

type P struct{ X int }

func (p P) Get() int { return p.X }

func first() int {
	type Q struct{ P }
	return Q{P{1}}.Get()
}

func second() int {
	type Q struct {
		P
		Y int
	}
	q := Q{P{2}, 3}
	return q.Get() + q.Y
}

func main() {
	h := Holder{}
	h.Counter.Inc()
	h.Inc()
	fmt.Println(h, h.Show())

	c := Counter(5)
	ph := PtrHolder{&c}
	ph.Inc()
	fmt.Println(c, ph.Show())

	o := Outer{Name: "o"}
	o.Inc()
	o.Holder.Inc()
	var i Incer = &o
	i.Inc()
	fmt.Println(o.Counter, o.Show())

	s := Shadow{}
	s.Inc()
	fmt.Println(s.Counter, s.Show())

	type Q struct{ P }
	fmt.Println(Q{P{7}}.Get(), first(), second())
}
