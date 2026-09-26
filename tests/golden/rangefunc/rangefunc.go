// range sobre func (Go 1.23): continue/break do laço, return de dentro (com
// defer e resultados nomeados), rótulos de fora, switch, e o pânico do Go
// quando o iterador ignora o false.
package main

import "fmt"

func seq(n int) func(func(int) bool) {
	return func(yield func(int) bool) {
		for i := 0; i < n; i++ {
			if !yield(i) {
				fmt.Println("parou em", i)
				return
			}
		}
	}
}

func pairs(m []string) func(func(int, string) bool) {
	return func(yield func(int, string) bool) {
		for i, s := range m {
			if !yield(i, s) {
				return
			}
		}
	}
}

func first(n int) (int, string) {
	for i := range seq(n) {
		if i == 2 {
			return i * 10, "achou"
		}
	}
	return -1, "nada"
}

func find(xs []string, w string) (idx int) {
	defer func() { idx++ }()
	for i, s := range pairs(xs) {
		if s == w {
			return i
		}
	}
	return -2
}

func bad(yield func(int) bool) {
	yield(1)
	yield(2) // ignora o false: pânico do Go
}

func main() {
	for i := range seq(3) {
		fmt.Println("i", i)
	}
	for i := range seq(10) {
		if i%2 == 1 {
			continue
		}
		if i > 4 {
			break
		}
		fmt.Println("par", i)
	}
	fmt.Println(first(5))
	fmt.Println(first(1))
	fmt.Println(find([]string{"a", "b"}, "b"), find(nil, "x"))
outer:
	for i := range seq(3) {
		for j := range seq(3) {
			if j == 1 {
				continue outer
			}
			if i == 2 {
				break outer
			}
			fmt.Println(i, j)
		}
	}
	for _, s := range pairs([]string{"x", "y"}) {
		switch s {
		case "x":
			fmt.Println("switch x")
			break
		}
		fmt.Println("depois", s)
	}
	count := 0
	for range seq(4) {
		count++
	}
	fmt.Println("count", count)
	func() {
		defer func() { fmt.Println("recover:", recover()) }()
		for x := range bad {
			fmt.Println("bad", x)
			break
		}
	}()
}
