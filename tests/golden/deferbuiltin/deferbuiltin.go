// defer de builtin (golang.org/x/net/http2: defer delete): argumentos
// avaliados no defer, execução na saída da função.
package main

import "fmt"

type E struct{ n int }

func del(m map[string]int, k string) {
	defer delete(m, k) // chave avaliada agora
	k = "zz"
	fmt.Println("antes", len(m))
}

func boom(e E) (r any) {
	defer func() { r = recover() }()
	defer panic(e) // valor copiado agora
	e.n = 99
	return nil
}

func main() {
	m := map[string]int{"a": 1, "b": 2}
	del(m, "a")
	fmt.Println(len(m), m)
	fmt.Println(boom(E{7}))
	s := []int{1, 2, 3}
	func() {
		defer clear(s)
		defer fmt.Println("clear depois", s)
	}()
	fmt.Println(s)
}
