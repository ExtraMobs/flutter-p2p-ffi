// Campo em branco: sempre zero, aparece no %v/%+v (_:0) como no Go, e não
// muda igualdade nem chave de map (P2-runtime-fmt-campo-branco).
package main

import "fmt"

type Pad struct {
	A int
	_ int
	B int
	_ [0]func() // não comparável (padrão do protobuf pragma)
}

type Q struct {
	_ struct{ X, Y int }
	S string
	_ *int
}

func main() {
	p := Pad{A: 1, B: 2}
	fmt.Println(p)
	fmt.Printf("%v %+v\n", p, p)
	q := Q{S: "s"}
	fmt.Printf("%v %+v\n", q, q)
	m := map[Q]int{q: 1, {S: "a"}: 2}
	fmt.Println(m, q == Q{S: "s"})
}
