// Constraints com core type (S ~[]E, M ~map[K]V: funções de golang.org/x/exp/slices,
// reembrulho no slice nomeado) e interfaces de constraint aninhadas
// (golang.org/x/exp/constraints.Integer; pebble/v2/sstable/colblk align).
package main

import "fmt"

// Funções de golang.org/x/exp/slices (core type ~[]E).
func Index[S ~[]E, E comparable](s S, v E) int {
	for i := range s {
		if v == s[i] {
			return i
		}
	}
	return -1
}

func Contains[S ~[]E, E comparable](s S, v E) bool { return Index(s, v) >= 0 }

func Equal[S ~[]E, E comparable](s1, s2 S) bool {
	if len(s1) != len(s2) {
		return false
	}
	for i := range s1 {
		if s1[i] != s2[i] {
			return false
		}
	}
	return true
}

func Clone[S ~[]E, E any](s S) S {
	if s == nil {
		return nil
	}
	return append(S([]E{}), s...)
}

func Insert[S ~[]E, E any](s S, i int, v ...E) S {
	tail := append(S(nil), s[i:]...)
	s = append(s[:i], v...)
	return append(s, tail...)
}

func Delete[S ~[]E, E any](s S, i, j int) S { return append(s[:i], s[j:]...) }

func Reverse[S ~[]E, E any](s S) {
	for i, j := 0, len(s)-1; i < j; i, j = i+1, j-1 {
		s[i], s[j] = s[j], s[i]
	}
}

func Keys[M ~map[K]V, K comparable, V any](m M) int { return len(m) }

type IDs []string

func (ids IDs) Join() string {
	out := ""
	for _, s := range ids {
		out += s
	}
	return out
}

type Set map[string]bool

// golang.org/x/exp/constraints
type Signed interface {
	~int | ~int8 | ~int16 | ~int32 | ~int64
}

type Unsigned interface {
	~uint | ~uint8 | ~uint16 | ~uint32 | ~uint64 | ~uintptr
}

type Integer interface{ Signed | Unsigned }

type Float interface{ ~float32 | ~float64 }

type Ordered interface{ Integer | Float | ~string }

// pebble/v2/sstable/colblk/base.go
func align[T Integer](offset, val T) T { return (offset + val - 1) & ^(val - 1) }

func maxOf[T Ordered](a, b T) T {
	if a > b {
		return a
	}
	return b
}

type offset uint32

func main() {
	ids := IDs{"a", "b", "c"}
	fmt.Println(Index(ids, "b"), Contains(ids, "z"), Equal(ids, IDs{"a", "b", "c"}))
	c := Clone(ids)
	c[0] = "x"
	fmt.Println(ids, c, c.Join(), Clone(IDs(nil)) == nil)
	ins := Insert(ids, 1, "p", "q")
	fmt.Println(ins, ins.Join(), len(ins))
	d := Delete([]int{1, 2, 3, 4}, 1, 3)
	fmt.Println(d)
	Reverse(ids)
	fmt.Println(ids, Keys(Set{"a": true}), Keys(map[int]int{}))

	fmt.Println(align(13, 8), align(uint8(250), 4), align(offset(17), 16), align[int64](-3, 4))
	fmt.Println(maxOf(1.5, 2), maxOf("a", "b"), maxOf(offset(3), 2))
}
