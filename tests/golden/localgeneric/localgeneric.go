// Tipo local em função genérica: classe içada genérica nos parâmetros da
// função (_wrap$box$<T>), com os dicionários no construtor.
package main

import "fmt"

func Wrap[T any](v T) any {
	type box struct{ v T }
	return box{v}
}

func Pairs[K comparable, V any](m map[K]V, keys []K) []any {
	type pair struct {
		K K
		V V
	}
	type list []pair
	var out list
	for _, k := range keys {
		out = append(out, pair{k, m[k]})
	}
	res := make([]any, len(out))
	for i, p := range out {
		res[i] = p
	}
	return res
}

func main() {
	fmt.Println(Wrap(3), Wrap("s"))
	fmt.Println(Pairs(map[string]int{"a": 1, "b": 2}, []string{"b", "a", "z"}))
	fmt.Printf("%+v\n", Pairs(map[int]bool{1: true}, []int{1}))
}
