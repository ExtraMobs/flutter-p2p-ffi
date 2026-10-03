// Method set de valor × ponteiro numa interface: um T guardado por valor não
// tem os métodos de receptor *T (type assertion, comma-ok, type switch, fmt).
package main

import "fmt"

type P struct{ X int }

func (p *P) Inc() { p.X++ }

func (p P) Get() int { return p.X }

type Incer interface{ Inc() }

type Getter interface{ Get() int }

type A [1]int

func (a *A) String() string { return "A!" }

func (a *A) Inc() { a[0]++ }

type B [1]int

func (b B) String() string { return "B!" }

func describe(x interface{}) string {
	switch v := x.(type) {
	case Incer:
		v.Inc()
		return "incer"
	case Getter:
		return fmt.Sprint("getter ", v.Get())
	case fmt.Stringer:
		return "stringer " + v.String()
	default:
		return "not"
	}
}

func main() {
	var x interface{} = P{}
	_, ok := x.(Incer)
	fmt.Println(ok)
	switch x.(type) {
	case Incer:
		fmt.Println("incer")
	default:
		fmt.Println("not")
	}
	fmt.Println(A{1})
	fmt.Println(&A{1})
	fmt.Println(B{1}, &B{1})

	p := &P{3}
	fmt.Println(describe(P{7}), describe(p), p.X)
	fmt.Println(describe(A{1}), describe(&A{1}), describe(B{2}))
	_, ok = interface{}(p).(Incer)
	fmt.Println(ok)
	_, ok = interface{}(A{}).(fmt.Stringer)
	_, ok2 := interface{}(&A{}).(fmt.Stringer)
	fmt.Println(ok, ok2)
	g, ok := x.(Getter)
	fmt.Println(g.Get(), ok)

	defer func() { fmt.Println("recover:", recover()) }()
	_ = x.(Incer)
}
