// Método de valor de tipo nomeado não-struct que toma o endereço do
// receptor (c.inc() com receptor ponteiro, &c): o receptor vira caixa local.
package main

import "fmt"

type Counter int

func (c *Counter) inc() { *c++ }

func (c Counter) Twice() Counter {
	c.inc()
	c.inc()
	return c
}

func (c Counter) Addr() Counter {
	p := &c
	*p += 10
	return c
}

type Stack []int

func (s *Stack) push(v int) { *s = append(*s, v) }

func (s Stack) With(v int) Stack {
	s.push(v)
	return s
}

func main() {
	var l Counter = 5
	l.inc()
	st := Stack{1}
	st2 := st.With(2)
	fmt.Println(Counter(1).Twice(), l, l.Addr(), l, st, st2)
}
