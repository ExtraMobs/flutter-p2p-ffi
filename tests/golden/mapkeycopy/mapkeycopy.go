package main

import "fmt"

type S struct{ a int }

func main() {
	m := map[S]int{}
	s := S{1}
	m[s] = 1
	s.a = 2
	m[s] = 2
	fmt.Println(len(m), m[S{1}], m[S{2}])
	for k := range m {
		k.a = 100
	}
	fmt.Println(m[S{1}], m[S{2}])

	// ++, op= e chave array.
	n := map[[2]int]int{}
	k := [2]int{1, 2}
	n[k]++
	k[0] = 9
	n[k] += 5
	fmt.Println(len(n), n[[2]int{1, 2}], n[[2]int{9, 2}])

	// Chave interface com struct dentro.
	var i map[any]string = map[any]string{}
	t := S{3}
	i[t] = "três"
	t.a = 4
	_, ok := i[S{3}]
	fmt.Println(i[S{3}], ok, len(i))
}
