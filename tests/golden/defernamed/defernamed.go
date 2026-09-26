// defer de valor de tipo func nomeado (context.CancelFunc em kubo/core/commands):
// o closure fica em $f e pode ser quem chama recover().
package main

import "fmt"

type CancelFunc func()

type Guard func() any

func withCancel(tag string) (int, CancelFunc) {
	return len(tag), func() { fmt.Println("cancel", tag) }
}

func work() (r any) {
	n, cancel := withCancel("ctx")
	defer cancel()
	var g Guard = func() any { return recover() } // recover chamado pelo defer
	defer func() { fmt.Println("depois do guard") }()
	defer g()
	fmt.Println("trabalho", n)
	panic("boom")
}

func main() {
	defer func() { fmt.Println("main recover:", recover()) }()
	work()
}
