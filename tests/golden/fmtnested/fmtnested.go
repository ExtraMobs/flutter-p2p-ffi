// Métodos String()/Error() em valores aninhados (handleMethods/printValue
// do fmt): *T aninhado usa o method set de *T, campo não exportado não chama
// métodos, panic e nil deref dentro do método viram %!v(PANIC=...)/<nil>.
package main

import (
	"errors"
	"fmt"
)

type T struct{ n int }

func (t *T) String() string { return fmt.Sprint("T", t.n) }

type K int

func (k K) String() string { return "K!" }

type W struct {
	k K
	E K
}

type Q struct{ n int }

func (q *Q) String() string { return fmt.Sprint("Q", q.n) }

type B struct{}

func (b *B) String() string { panic("boom") }

type E struct{ msg string }

func (e *E) Error() string { return "E:" + e.msg }

type V struct{ n int }

func (v V) String() string { return fmt.Sprint("V", v.n) }

type Holder struct {
	Err    error
	T      *T
	Ks     []K
	hidden []K
	V      V
	Plain  T
	m      map[string]K
}

type Arr [2]int

func (a *Arr) String() string { return "Arr!" }

type N struct{ p *T }

func (n N) String() string { return "N" + n.p.String() }

func main() {
	fmt.Println([]*T{{1}, {2}})
	fmt.Println(W{1, 2})
	var q *Q
	fmt.Printf("%v\n", q)
	fmt.Println(q)
	fmt.Println(&B{})
	fmt.Println("after")

	fmt.Println([]error{&E{"a"}, errors.New("b")})
	fmt.Printf("%v %s\n", []error{&E{"a"}}, []fmt.Stringer{&T{3}})
	fmt.Println(map[string]*T{"x": {4}}, map[K]V{1: {2}})
	fmt.Println([]interface{}{&T{5}, V{6}, K(7), &E{"c"}})
	fmt.Println(Holder{Err: &E{"d"}, T: &T{8}, Ks: []K{1}, hidden: []K{2}, V: V{9}, Plain: T{10}, m: map[string]K{"k": 3}})
	fmt.Printf("%+v\n", Holder{Err: &E{"d"}, T: &T{8}, hidden: []K{2}})
	fmt.Println([]Arr{{1, 2}}, []*Arr{{3, 4}})
	fmt.Println([]T{{11}}, [1]*T{{12}})
	fmt.Println([]V{{13}}, []*V{{14}})
	fmt.Println(fmt.Sprint(&B{}), fmt.Sprintf("%s|%d", &B{}, &B{}))
	fmt.Println([]*B{{}}, []*Q{nil})
	fmt.Println(N{&T{15}}, N{})
	fmt.Printf("[%v] [%s]\n", N{}, []N{{}})

	// Campo de parâmetro de tipo e de interface: ponteiro guardado é *T
	// (método de *T e `==` por endereço).
	fmt.Println(Box[*T]{&T{16}}, Box[T]{T{17}}, Box[any]{&E{"g"}}, Box[any]{V{18}})
	e1 := &E{"h"}
	fmt.Println(Box[error]{e1} == Box[error]{e1}, Box[error]{e1} == Box[error]{&E{"h"}})
	fmt.Println(Pair{e1} == Pair{e1}, Pair{e1} == Pair{&E{"h"}}, Pair{V{1}} == Pair{V{1}})
}

type Box[X any] struct{ V X }

type Pair struct{ A interface{} }
