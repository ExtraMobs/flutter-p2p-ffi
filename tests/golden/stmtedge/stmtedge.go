// Statements que quebravam a emissão: alvo entre parênteses (`(*p)++`,
// `(x) += 3`), switch e type switch vazios, variável do type switch
// atribuída no case e rótulos que são palavras reservadas do Dart.
package main

import "fmt"

type celsius float64

func tag() int {
	fmt.Println("tag avaliada")
	return 7
}

func kind(i any) string {
	switch v := i.(type) {
	case int:
		v++
		v *= 2
		return fmt.Sprint("int ", v)
	case string, []byte:
		v = "trocado"
		return fmt.Sprint("multi ", v)
	case celsius:
		v += 0.25
		return fmt.Sprint("celsius ", v)
	default:
		v = nil
		return fmt.Sprint("default ", v)
	}
}

func addr(i any) string {
	switch v := i.(type) {
	case celsius:
		p := &v
		*p += 0.5
		return fmt.Sprint("celsius ", v)
	default:
		return fmt.Sprint("default ", v)
	}
}

func main() {
	x := 1
	p := &x
	(*p)++
	((*p))--
	(*p) += 2
	(x) += 3
	(x) = (x) * 2
	fmt.Println("x", x)

	m := map[string]int{"a": 1}
	(m["a"])++
	(m["b"]) += 5
	fmt.Println("m", m["a"], m["b"])

	s := []int{1, 2}
	(s[0]) = 10
	(s[1])++
	fmt.Println("s", s)

	var c celsius = 1.5
	(c)++
	fmt.Println("c", c)

	switch x {
	}
	switch tag() {
	}
	switch {
	}
	var i any = x
	switch i.(type) {
	}
	fmt.Println(kind(3), kind("s"), kind([]byte("b")), kind(celsius(2)), kind(1.5))
	fmt.Println(addr(celsius(1)), addr(2))

in:
	for k := range 3 {
		if k == 1 {
			break in
		}
		fmt.Println("in", k)
	}
new:
	for k := 0; k < 3; k++ {
		for j := range 3 {
			if j == 1 {
				continue new
			}
			fmt.Println("new", k, j)
		}
	}
true:
	for _, r := range "ab" {
		switch r {
		case 'a':
			continue true
		}
		fmt.Println("true", string(r))
		break true
	}
	seq := func(yield func(int) bool) {
		for n := range 4 {
			if !yield(n) {
				return
			}
		}
	}
class:
	for n := range seq {
	is:
		for k := range 3 {
			if k == 1 {
				continue is
			}
			if n == 2 {
				break class
			}
			fmt.Println("class", n, k)
		}
	}
}
