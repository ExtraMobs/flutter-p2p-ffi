// Endereços no fmt: %v de *T não-struct e de func, %p/%#p de ponteiro, slice,
// map e func. O valor não é reproduzível nem no Go; o teste compara a forma.
package main

import (
	"fmt"
	"strings"
)

type T struct{ n int }

type N int

func (n *N) inc() { *n++ }

// shape reduz um endereço à forma (0x + hex), que é reproduzível; o valor não é.
func shape(s string) string {
	if s == "<nil>" || s == "0x0" || s == "%!p(int=5)" {
		return s
	}
	ok := strings.HasPrefix(s, "0x") && len(s) > 2
	for _, c := range s[2:] {
		ok = ok && (c >= '0' && c <= '9' || c >= 'a' && c <= 'f')
	}
	if ok {
		return "ADDR"
	}
	return "?" + s
}

func main() {
	x := 5
	p := &x
	var np *int
	f := func() {}
	s := []int{1, 2}
	m := map[string]int{}
	var n N
	pn := &n
	t := &T{1}
	for _, v := range []string{
		fmt.Sprint(p), fmt.Sprint(np), fmt.Sprintf("%v", p), fmt.Sprint(f),
		fmt.Sprintf("%p", p), fmt.Sprintf("%p", s), fmt.Sprintf("%p", m), fmt.Sprintf("%p", f),
		fmt.Sprintf("%p", t), fmt.Sprintf("%p", pn), fmt.Sprintf("%p", np), fmt.Sprintf("%p", x),
	} {
		fmt.Print(shape(v), " ")
	}
	fmt.Println()
	// Mesmo endereço para o mesmo objeto; diferente para outro.
	fmt.Println(fmt.Sprintf("%p", p) == fmt.Sprintf("%p", &x), fmt.Sprintf("%p", s) == fmt.Sprintf("%p", &s[0]),
		fmt.Sprintf("%p", s) == fmt.Sprintf("%p", s[1:]), fmt.Sprint(p) == fmt.Sprintf("%p", p))
	h := fmt.Sprintf("%#p", t)
	fmt.Println(!strings.HasPrefix(h, "0x"), len(h) > 0, fmt.Sprint(t), fmt.Sprintf("%v", *pn))
}
