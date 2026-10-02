// Método não exportado com o mesmo nome Dart de uma constante, função ou
// variável do pacote: dentro da classe, o nome de pacote não pode ser
// sombreado pelo membro. Exportado (método/campo `Name`, `Size` e func/var
// de pacote) sai qualificado pelo import da própria library.
package main

import "fmt"

type op int

const sub op = 1

var add = 10

func mul(a op) op { return a * 3 }

type T struct{ n int }

func (t *T) sub(o op) op { return o + 1 }

func (t *T) add(d int) { t.n += d }

func (t T) mul(a op) op { return a * 5 }

func (t *T) Sub() op { return t.sub(sub) }

func (t *T) Add() int {
	t.add(add)
	f := func() int { return add * 2 }
	return t.n + f()
}

func (t T) Mul() op { return t.mul(mul(sub)) + mul(2) }

var Size = 3

func Name() string { return "pacote" }

type U struct{ Size int }

func (u U) Name() string {
	g := func() int { return Size + 1 }
	return fmt.Sprint("U ", Name(), " ", Size, " ", u.Size, " ", g())
}

type I interface{ sub(op) op }

func use(i I) op { return i.sub(sub) }

func main() {
	t := &T{}
	fmt.Println(t.Sub(), t.Add(), t.Mul(), use(t), sub, add, mul(4))
	add = 20
	fmt.Println(t.Add())
	fmt.Println(U{Size: 9}.Name(), Name(), Size)
}
