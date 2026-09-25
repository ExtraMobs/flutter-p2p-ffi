// Package main exercita ponteiros nil tipados: numa interface eles não são
// nil, métodos com receptor ponteiro rodam com receptor nil, receptor valor
// dá panic, assertion devolve o ponteiro nil.
package main

import "fmt"

type Speaker interface{ Speak() string }

type Node struct {
	Name string
	Next *Node
}

func (n *Node) Speak() string {
	if n == nil {
		return "nó nil"
	}
	return "nó " + n.Name
}

func (n *Node) Len() int {
	if n == nil {
		return 0
	}
	return 1 + n.Next.Len()
}

type Val struct{ X int }

func (v Val) Speak() string { return fmt.Sprint("val ", v.X) }

func try(name string, f func()) {
	defer func() {
		if r := recover(); r != nil {
			fmt.Println(name, "panic:", r)
		}
	}()
	f()
}

func main() {
	var p *Node
	var s Speaker = p
	fmt.Println(s != nil, s.Speak(), p.Speak(), p.Len())
	list := &Node{"a", &Node{"b", nil}}
	fmt.Println(list.Len(), list.Speak())

	back, ok := s.(*Node)
	fmt.Println(back == nil, ok, s == p)
	var a any = p
	fmt.Println(a != nil, a)
	switch v := s.(type) {
	case *Node:
		fmt.Println("case *Node, nil?", v == nil)
	}

	var vp *Val
	var s2 Speaker = vp
	try("valor", func() { fmt.Println(s2.Speak()) })
	try("campo", func() { fmt.Println(p.Name) })

	var q *int
	var b any = q
	qb, okq := b.(*int)
	fmt.Println(b != nil, qb == nil, okq)

	var empty Speaker
	fmt.Println(empty == nil)
}
