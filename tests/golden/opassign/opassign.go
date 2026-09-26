// Operadores compostos sem equivalente Dart: &^= sobre índice, campo e
// ponteiro; <<=, >>=, /=, %=, &^=, |= sobre índice de map (inteiro e float).
package main

import "fmt"

type flags struct{ f uint16 }

func main() {
	s := []uint8{0xff, 0xf0}
	s[0] &^= 0x0f
	i := 1
	s[i] &^= 0x30
	var x flags
	x.f = 0xffff
	x.f &^= 0x00f0
	p := &x
	p.f &^= 1
	arr := [2]int64{-1, 7}
	arr[0] &^= 6
	m := map[string]int{"a": 3, "b": -7}
	m["a"] <<= 2
	m["a"] /= 5
	m["b"] %= 3
	m["b"] >>= 1
	m["c"] &^= 1
	m["a"] |= 16
	var sh uint = 3
	m["d"] = 1
	m["d"] <<= sh
	fm := map[int]float64{1: 7}
	fm[1] /= 2
	fmt.Println(s, x.f, arr, m, fm)
}
