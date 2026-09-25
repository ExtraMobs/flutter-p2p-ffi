// Package main exercita tipos nomeados sobre slice, map e func (com
// métodos, atribuibilidade e aliasing) e métodos de receptor ponteiro em
// tipo nomeado não-struct (inclusive via interface).
package main

import "fmt"

type Lesser interface {
	Len() int
	Less(i, j int) bool
	Swap(i, j int)
}

type IDs []string

func (s IDs) Len() int           { return len(s) }
func (s IDs) Less(i, j int) bool { return s[i] < s[j] }
func (s IDs) Swap(i, j int)      { s[i], s[j] = s[j], s[i] }
func (s *IDs) Add(id string)     { *s = append(*s, id) }

func bubble(x Lesser) {
	n := x.Len()
	for i := 0; i < n; i++ {
		for j := n - 1; j > i; j-- {
			if x.Less(j, j-1) {
				x.Swap(j, j-1)
			}
		}
	}
}

type Set map[string]bool

func (s Set) Add(k string)      { s[k] = true }
func (s Set) Has(k string) bool { return s[k] }

type Op func(a, b int) int

func (f Op) Apply(a, b int) int { return f(a, b) }

type Counter int

func (c *Counter) Inc()          { *c++ }
func (c Counter) String() string { return fmt.Sprint("#", int(c)) }

type Incer interface{ Inc() }

func total(xs []string) int { return len(xs) }

func main() {
	var ids IDs
	ids.Add("c")
	ids.Add("a")
	ids = append(ids, "b")
	bubble(ids)
	fmt.Println(ids, len(ids), ids[1:], []string(ids), total(ids))
	var plain []string = ids
	tail := ids[1:]
	tail[0] = "z"
	fmt.Println(plain, ids, IDs(plain).Len())
	more := IDs{"q", "p"}
	bubble(more)
	fmt.Println(more, make(IDs, 2).Len())

	s := Set{}
	s.Add("x")
	fmt.Println(s.Has("x"), s.Has("y"), len(s), s)
	var none Set
	fmt.Println(none.Has("x"), none == nil)

	add := Op(func(a, b int) int { return a + b })
	fmt.Println(add(2, 3), add.Apply(4, 5))
	var mul Op = func(a, b int) int { return a * b }
	var raw func(a, b int) int = mul
	fmt.Println(mul.Apply(3, 4), raw(5, 6), mul != nil)

	var c Counter
	c.Inc()
	c.Inc()
	p := &c
	p.Inc()
	fmt.Println(c, *p, p.String())
	var i Incer = p
	i.Inc()
	var st fmt.Stringer = c
	fmt.Println(c, st.String())
	cs := []Counter{1, 2}
	cs[1].Inc()
	q := &cs[0]
	q.Inc()
	fmt.Println(cs, *q)
	_, isPtr := i.(*Counter)
	fmt.Println(isPtr, i.(*Counter) == p)
}

type Bag map[string]int

func (b Bag) Delete(k string)    { delete(b, k) }
func (b Bag) Length() int        { return len(b) }
func (b Bag) Value(k string) int { return b[k] }
func (b *Bag) Reset()            { *b = Bag{} }
func (b Bag) ToString() string   { return fmt.Sprint(len(b)) }

type Deleter interface{ Delete(k string) }

func init() {
	b := Bag{"a": 1, "b": 2}
	var d Deleter = b
	d.Delete("a")
	fmt.Println(b.Length(), b.Value("b"), b.ToString())
	b.Reset()
	fmt.Println(b.Length(), b == nil)
}
