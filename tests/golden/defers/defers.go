// Package main exercita defer/panic/recover: ordem LIFO, argumentos
// avaliados no defer, resultados nomeados alterados por defers, recuperação
// de panics do usuário e de erros de runtime (mesmas mensagens do Go).
package main

import "fmt"

type Point struct{ X int }

func order() {
	for i := 0; i < 3; i++ {
		defer fmt.Println("defer", i)
	}
	x := 10
	defer fmt.Println("x no defer:", x) // avaliado agora
	x = 20
	fmt.Println("x no fim:", x)
}

func double(n int) (r int) {
	defer func() { r *= 2 }()
	return n + 1
}

func safe(name string, f func()) (msg string) {
	defer func() {
		if e := recover(); e != nil {
			msg = fmt.Sprint(name, ": recuperado: ", e)
		}
	}()
	f()
	return name + ": ok"
}

func repanic() (s string) {
	defer func() { s = fmt.Sprint("final: ", recover()) }()
	defer func() { panic("segundo") }()
	panic("primeiro")
}

func main() {
	order()
	fmt.Println(double(4), recover())

	zero := 0
	var nm map[string]int
	var p *Point
	xs := []int{1, 2, 3}
	var s string = "abc"
	fmt.Println(safe("nada", func() {}))
	fmt.Println(safe("valor", func() { panic(42) }))
	fmt.Println(safe("div", func() { fmt.Println(1 / zero) }))
	fmt.Println(safe("map", func() { nm["a"] = 1 }))
	fmt.Println(safe("nil", func() { fmt.Println(p.X) }))
	fmt.Println(safe("indice", func() { fmt.Println(xs[len(xs)+2]) }))
	fmt.Println(safe("fatia", func() { fmt.Println(xs[1:5]) }))
	fmt.Println(safe("string", func() { fmt.Println(s[7]) }))
	fmt.Println(safe("erro", func() { panic(fmt.Sprint("custom ", 1)) }))
	fmt.Println(repanic())

	count := 0
	func() {
		defer func() { count++ }()
		defer func() { count *= 10 }()
		count = 1
	}()
	fmt.Println(count)
	fmt.Println(indirect())
	named()
	method()
	value()
}

// recover só funciona chamado diretamente pela função adiada.
func helperRecover() any { return recover() }

func deferredNamed() { fmt.Println("nomeada recupera:", recover()) }

type R struct{ tag string }

func (r R) deferredMethod() { fmt.Println("método recupera:", r.tag, recover()) }

func indirect() (msg string) {
	defer func() {
		msg = fmt.Sprint("externo: ", recover())
	}()
	func() {
		defer func() {
			fmt.Println("helper devolve:", helperRecover())
			inner := func() any { return recover() }
			fmt.Println("closure aninhada devolve:", inner())
		}()
		panic("x")
	}()
	return "não chega"
}

func named() {
	defer deferredNamed()
	panic("y")
}

func method() {
	defer R{"m"}.deferredMethod()
	panic("z")
}

func value() {
	fv := func() { fmt.Println("valor de função recupera:", recover()) }
	defer fv()
	panic("w")
}

