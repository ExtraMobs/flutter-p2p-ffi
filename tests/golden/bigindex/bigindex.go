// Índices e limites fora de ±2^53 (uint64 >= 2^63, int64 grandes e
// negativos): a mensagem do panic traz o valor exato, igual em VM, JS e Wasm;
// make com len/cap enormes dá o panic do makeslice em vez de alocar.
package main

import "fmt"

func try(f func()) {
	defer func() { fmt.Println(recover()) }()
	f()
}

func main() {
	s := []int{1}
	a := [2]int{}
	str := "x"
	var u uint64 = 1 << 63
	var i int64 = 1<<60 + 1
	var n int64 = -(1<<62 + 3)
	var small int64 = -2
	try(func() { _ = s[u] })
	try(func() { _ = s[i] })
	try(func() { _ = s[n] })
	try(func() { _ = s[small] })
	try(func() { _ = a[i] })
	try(func() { _ = str[u] })
	try(func() { _ = s[:u] })
	try(func() { _ = s[i:] })
	try(func() { _ = s[:1:u] })
	try(func() { _ = str[:i] })
	try(func() { _ = str[i:] })
	try(func() { _ = make([]int, u) })
	try(func() { _ = make([]int, 1, u) })
	fmt.Println(s[i-(1<<60)-1], str[u-(1<<63)])
}
