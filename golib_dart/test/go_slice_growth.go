// Oráculo: sequência de cap de append para vários tipos de elemento.
// Saída: JSON {"<tipo>": {"size": n, "pointers": b, "caps": [...], "bulk": [...]}}.
//
// Os slices escapam (sink) de propósito: o Go 1.25 dá a slices que não
// escapam um buffer de 32 bytes no stack no primeiro append (otimização do
// compilador, dependente de análise de escape). O runtime do g2d modela o
// growslice do heap.
package main

import (
	"encoding/json"
	"os"
	"unsafe"
)

type ptr3 struct{ a, b, c *int }
type big600 struct {
	p *int
	_ [592]byte
}

var sink any

func caps[T any](pointers bool) map[string]any {
	var s []T
	var seq []int
	last := -1
	for i := 0; i < 5000; i++ {
		s = append(s, *new(T))
		sink = s
		if cap(s) != last {
			last = cap(s)
			seq = append(seq, last)
		}
	}
	// append de vários de uma vez a partir de caps variados.
	var bulk []int
	for _, start := range []int{0, 1, 5, 17, 300, 1000} {
		for _, n := range []int{1, 3, 7, 40, 700} {
			t := make([]T, start)
			t = append(t, make([]T, n)...)
			bulk = append(bulk, cap(t))
		}
	}
	var zero T
	return map[string]any{"size": unsafe.Sizeof(zero), "pointers": pointers, "caps": seq, "bulk": bulk}
}

func main() {
	out := map[string]any{
		"byte":   caps[byte](false),
		"int32":  caps[int32](false),
		"int":    caps[int](false),
		"string": caps[string](true),
		"arr3":   caps[[3]int](false),
		"ptr3":   caps[ptr3](true),
		"arr100": caps[[100]int](false),
		"big600": caps[big600](true),
		"iface":  caps[any](true),
		"empty":  caps[struct{}](false),
	}
	if err := json.NewEncoder(os.Stdout).Encode(out); err != nil {
		panic(err)
	}
}
