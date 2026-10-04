// D9: Value.Call sempre suspende; quem chama por reflexão vira async, e a
// função chamada pode suspender (construtores do fx/dig). Num contexto que
// precisa ficar síncrono (String()), a chamada fica síncrona.
package main

import (
	"fmt"
	"reflect"
	"time"
)

type Repo struct{ Path string }

func openRepo(path string) *Repo {
	time.Sleep(time.Millisecond) // I/O que suspende
	return &Repo{Path: path}
}

func newNode(r *Repo) (string, error) { return "node@" + r.Path, nil }

// build chama os construtores só por reflexão, como o dig.
func build(ctors ...any) []reflect.Value {
	var last []reflect.Value
	for _, c := range ctors {
		v := reflect.ValueOf(c)
		in := make([]reflect.Value, v.Type().NumIn())
		for i := range in {
			in[i] = last[0]
		}
		last = v.Call(in)
	}
	return last
}

type Label struct{}

func (Label) String() string {
	f := func(n int) int { return n * 2 }
	return fmt.Sprint("label ", reflect.ValueOf(f).Call([]reflect.Value{reflect.ValueOf(21)})[0].Int(), " ", twice(f, 4))
}

// twice é async só por chamar por reflexão: num contexto síncrono
// (String()) quem chama usa a gêmea `twice$sync`.
func twice(f any, n int) int {
	v := reflect.ValueOf(f)
	r := v.Call([]reflect.Value{reflect.ValueOf(n)})[0]
	return int(v.Call([]reflect.Value{r})[0].Int())
}

func main() {
	out := build(func() string { return "/repo" }, openRepo, newNode)
	fmt.Println(out[0], out[1].IsNil())
	v := reflect.ValueOf(fmt.Sprintf)
	fmt.Println(v.CallSlice([]reflect.Value{reflect.ValueOf("%d-%d"), reflect.ValueOf([]any{1, 2})})[0])
	fmt.Println(Label{}, twice(func(n int) int { return n + 1 }, 1))
}
