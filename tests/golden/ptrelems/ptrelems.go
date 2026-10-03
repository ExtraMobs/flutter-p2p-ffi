// Elementos ponteiro e interface em slices, arrays e maps: append que
// realoca, copy, cópia de array, troca e atribuição copiam o ponteiro, nunca
// o objeto apontado; struct por valor em []any continua por valor.
package main

import "fmt"

type P struct{ X int }

func main() {
	p := &P{1}
	s := []*P{p}
	s = append(s, &P{2})
	s[0].X = 5
	fmt.Println(p.X, s[0] == p)
	d := make([]*P, 1)
	copy(d, s)
	d[0].X = 6
	fmt.Println(p.X)
	arrp := [2]*P{{1}, {3}}
	arrp2 := arrp
	arrp2[0].X = 9
	fmt.Println(arrp[0].X)
	var xs []interface{}
	xs = append(xs, P{1})
	xs = append(xs, 2, 3)
	_, ok := xs[0].(P)
	_, ok2 := xs[0].(*P)
	fmt.Println(ok, ok2)
	ys := append([]interface{}(nil), xs...)
	_, ok = ys[0].(P)
	fmt.Println(ok)
	x0 := xs[0]
	xs[0] = P{2}
	fmt.Println(x0, xs[0], ys[0])

	// Atribuir ponteiro sobre ponteiro não escreve no alvo.
	s[0] = &P{7}
	fmt.Println(p.X, s[0].X)
	arrp[1] = p
	fmt.Println(arrp[1] == p, arrp2[1].X)
	s[0], s[1] = s[1], s[0]
	fmt.Println(s[0].X, s[1].X)
	m := map[string]*P{"a": p}
	m["a"] = &P{11}
	fmt.Println(p.X, m["a"].X)

	// Structs e arrays por valor continuam copiados.
	vs := []P{{1}, {2}}
	vs2 := append([]P(nil), vs...)
	vs2[0].X = 8
	fmt.Println(vs[0].X, vs2[0].X)
	va := [1]P{{4}}
	vb := va
	vb[0].X = 5
	fmt.Println(va[0].X, vb[0].X)
	aa := [][2]int{{1, 2}}
	aa = append(aa, [2]int{3, 4})
	q := &aa[0]
	aa[0] = [2]int{9, 9}
	fmt.Println(q[0], aa)
}
