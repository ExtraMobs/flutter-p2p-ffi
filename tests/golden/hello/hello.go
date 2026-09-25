// Package main é o fixture mínimo para validar o pipeline goast → g2d → dartast.
package main

import "fmt"

// Greeter cumprimenta alguém pelo nome.
type Greeter struct {
	Name string
}

// Greet monta a saudação.
func (g Greeter) Greet() string {
	return "Hello, " + g.Name + "!"
}

func add(a, b int) int {
	return a + b
}

func main() {
	g := Greeter{Name: "world"}
	fmt.Println(g.Greet())
	fmt.Println(add(1, 2))
}
