// [N]T(s) (Go 1.20; go.opentelemetry.io/otel/attribute: [1]KeyValue(kvs)):
// cópia dos N primeiros, pânico se o slice for curto.
package main

import "fmt"

type KV struct{ K, V string }

type Pair [2]KV

func try(f func()) (r any) {
	defer func() { r = recover() }()
	f()
	return
}

func main() {
	kvs := []KV{{"a", "1"}, {"b", "2"}, {"c", "3"}}
	one := [1]KV(kvs)
	kvs[0].V = "x" // o array é cópia
	p := Pair(kvs[1:])
	fmt.Println(one, p, kvs[0])
	b := []byte("hello")
	fmt.Println([4]byte(b), [0]int([]int(nil)))
	fmt.Println(try(func() { _ = [4]KV(kvs) }))
}
