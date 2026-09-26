// Interfaces genéricas: constraint autorreferente (`K Key[K]`), constraint
// que usa outra (`N NodeID[K]`), valor de interface genérica, tipo genérico
// que implementa interface (`List[K]` → sort.Interface) e genérico que
// implementa interface genérica (`*lru[K, V]` → `Cache[K, V]`).
package main

import (
	"fmt"
	"sort"
)

type Key[K any] interface {
	BitLen() int
	Xor(other K) K
	Compare(other K) int
}

type NodeID[K Key[K]] interface {
	Key() K
	String() string
}

type k8 uint8

func (k k8) BitLen() int { return 8 }
func (k k8) Xor(o k8) k8 { return k ^ o }
func (k k8) Compare(o k8) int {
	switch {
	case k < o:
		return -1
	case k > o:
		return 1
	}
	return 0
}

type node struct{ k k8 }

func (n node) Key() k8         { return n.k }
func (n node) String() string  { return fmt.Sprint("node-", uint8(n.k)) }

func Distance[K Key[K]](a, b K) int { return a.Xor(b).BitLen() }

func Closest[K Key[K], N NodeID[K]](target K, ns []N) N {
	best := ns[0]
	for _, n := range ns[1:] {
		if uint8(any(n.Key().Xor(target)).(k8)) < uint8(any(best.Key().Xor(target)).(k8)) {
			best = n
		}
	}
	return best
}

// Tipo genérico que implementa sort.Interface.
type List[K Key[K]] []K

func (l List[K]) Len() int           { return len(l) }
func (l List[K]) Less(i, j int) bool { return l[i].Compare(l[j]) < 0 }
func (l List[K]) Swap(i, j int)      { l[i], l[j] = l[j], l[i] }

type Cache[K comparable, V any] interface {
	Add(k K, v V) bool
	Get(k K) (V, bool)
}

type lru[K comparable, V any] struct{ m map[K]V }

func (c *lru[K, V]) Add(k K, v V) bool { _, ok := c.m[k]; c.m[k] = v; return !ok }
func (c *lru[K, V]) Get(k K) (V, bool) { v, ok := c.m[k]; return v, ok }

func use[K comparable, V any](c Cache[K, V], k K, v V) {
	fmt.Println(c.Add(k, v), c.Add(k, v))
	fmt.Println(c.Get(k))
}

func main() {
	fmt.Println(Distance(k8(3), k8(5)))
	var key Key[k8] = k8(6)
	fmt.Println(key.Xor(k8(3)), key.BitLen())
	fmt.Println(Closest(k8(1), []node{{7}, {3}, {1}}))
	l := List[k8]{3, 1, 2}
	sort.Sort(l)
	fmt.Println(l, sort.IsSorted(l))
	use[string, int](&lru[string, int]{m: map[string]int{}}, "a", 1)
	var c Cache[int, string] = &lru[int, string]{m: map[int]string{}}
	_, isCache := c.(Cache[int, string])
	fmt.Println(isCache)
}
