// Type switch/assertion sobre tipos func: o Go exige o tipo idêntico (o
// Dart só testa subtipo entre tipos de função: retorno covariante com `void`
// no topo, parâmetros contravariantes).
package main

import "fmt"

type Handler func(int)

func kind(x any) string {
	switch x.(type) {
	case func():
		return "func()"
	case func() error:
		return "func() error"
	case func(int):
		return "func(int)"
	case Handler:
		return "Handler"
	case func(int) (int, error):
		return "func(int) (int, error)"
	case func(...int) int:
		return "func(...int) int"
	}
	return "outro"
}

// Case único: a variável do switch fica ligada ao tipo do case (desembrulha
// o valor guardado, não só testa).
func call(x any) string {
	switch v := x.(type) {
	case func() error:
		if v() == nil {
			return "ok"
		}
		return "erro"
	case func(int):
		v(9)
		return "chamado"
	}
	return "outro"
}

func main() {
	fmt.Println(kind(func() error { return nil }), kind(func() {}), kind(func(any) {}))
	fmt.Println(kind(Handler(func(int) {})), kind(func(int) {}))
	fmt.Println(kind(func(int) (int, error) { return 0, nil }), kind(func(...int) int { return 0 }))
	fmt.Println(call(func() error { return nil }), call(func(int) {}), call("x"))

	var x any = func() {}
	f, ok := x.(func())
	fmt.Println(ok, f != nil)
	g, ok := x.(func(int))
	fmt.Println(ok, g == nil)

	fmt.Printf("%T %T %T\n", x, func(int) (int, error) { return 0, nil }, Handler(func(int) {}))
}
