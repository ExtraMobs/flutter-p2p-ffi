// Package main exercita a inicialização de pacote: variáveis em ordem de
// dependência (não de declaração), inicializadores com efeitos, múltiplas
// funções init em mais de um arquivo e func literal em nível de pacote.
package main

import "fmt"

var total = compute("total", base*2) // depende de base, declarada depois
var base = compute("base", 21)

var x, y = pair()

var counter int

var registry = map[string]int{}

var double = func(n int) int { return n * 2 }

func compute(name string, v int) int {
	counter++
	fmt.Println("init var", name, v, counter)
	return v
}

func pair() (int, int) {
	fmt.Println("pair")
	return 1, 2
}

func init() {
	fmt.Println("init a1", total, base, fromB, counter)
	registry["a"] = 1
}

func init() {
	fmt.Println("init a2", len(registry))
}

func main() {
	fmt.Println("main", total, base, x, y, fromB, counter, len(registry), registry["b"], double(5))
}
