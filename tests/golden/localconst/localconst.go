// Constantes declaradas dentro de função (ident:const: 58 pacotes no audit
// do kubo, ex. gonum/mathext EllipticRF).
package main

import "fmt"

type Level int8

const limit = 1 // de pacote, sombreada abaixo

func main() {
	const (
		lower = 5.0 / (1 << 256) / (1 << 256) / (1 << 256) / (1 << 254)
		upper = 1 / lower
	)
	fmt.Println(upper > 1e300, lower < 1e-300)

	const limit = 10
	x := 3
	fmt.Println(x < limit, limit*2)

	const (
		a Level = iota + 1
		b
		c
	)
	fmt.Println(a, b, c, c-a)

	const greeting string = "olá"
	f := func() string { return greeting + "!" }
	fmt.Println(f(), len(greeting))

	var u uint16 = 40000
	const half = 32768
	fmt.Println(u > half)
}
