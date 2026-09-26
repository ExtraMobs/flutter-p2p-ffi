// Type assertion comma-ok para tipo func sem nome (o zero é nil) e nomeado.
package main

import "fmt"

type Op func(int) int

func main() {
	var x any = func(n int) int { return n * 2 }
	f, ok := x.(func(int) int)
	fmt.Println(ok, f(4))
	g, ok := x.(func(string))
	fmt.Println(ok, g == nil)
	var y any = Op(func(n int) int { return n + 1 })
	o, ok := y.(Op)
	fmt.Println(ok, o(1))
	h, ok := y.(func(int) int)
	fmt.Println(ok, h == nil)
}
