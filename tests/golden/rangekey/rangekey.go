// range com chave declarada sobre slice, array e slice nomeado
// (antes: TypeError no g2d; 2º código do audit do kubo).
package main

import "fmt"

type node struct{ n int }

type info []node

func main() {
	xs := info{{1}, {2}, {3}}
	for i := range xs {
		fmt.Println(i, xs[i].n)
	}
	for i, v := range []string{"a", "b"} {
		fmt.Println(i, v)
	}
	arr := [3]uint8{7, 8, 9}
	for i := range arr {
		arr[i] *= 2
	}
	fmt.Println(arr)
	var j int
	for j = range xs {
	}
	fmt.Println(j)
}
