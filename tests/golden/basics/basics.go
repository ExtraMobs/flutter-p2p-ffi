// Package main exercita o subconjunto MVP do g2d: controle de fluxo,
// múltiplos retornos, closures, métodos com receptor ponteiro e maps.
package main

import "fmt"

const (
	Zero = iota
	One
	Two
)

const greeting = "custa $5\t\"ok\"\n"

var counter int

// Counter conta coisas.
type Counter struct {
	n    int
	Name string
	tags []string
	next *Counter
}

// Inc incrementa e devolve o novo valor.
func (c *Counter) Inc() int {
	c.n++
	counter++
	return c.n
}

func divmod(a, b int) (q, r int) {
	q = a / b
	r = a % b
	return
}

func pair() (string, error) {
	return "par", nil
}

func sum(xs ...int) int {
	total := 0
	for _, x := range xs {
		total += x
	}
	return total
}

func classify(n int) string {
	switch {
	case n < 0:
		return "negativo"
	case n == 0:
		return "zero"
	}
	switch n % 3 {
	case 0:
		return "múltiplo de 3"
	case 1, 2:
		return "resto " + fmt.Sprint(n%3)
	}
	return "inalcançável"
}

func main() {
	fmt.Println(Zero, One, Two, greeting)
	fmt.Println(7/2, -7/2, 7%3, -7%3, 7.0/2, 1<<10, 6&^3)

	q, r := divmod(17, 5)
	fmt.Println(q, r)
	s, err := pair()
	fmt.Println(s, err)
	s2, err := pair()
	fmt.Println(s2, err == nil)

	x := 10
	{
		x := x + 1
		fmt.Println("interno", x)
	}
	fmt.Println("externo", x)

	c := &Counter{Name: "c1"}
	c.Inc()
	c.Inc()
	fmt.Println(c.Name, c.Inc(), counter, c.next == nil, len(c.tags))

	var funcs []func() int
	for i := 0; i < 3; i++ {
		funcs = append(funcs, func() int { return i * i })
	}
	for _, f := range funcs {
		fmt.Println(f())
	}

	m := map[string]int{"a": 1, "b": 2, "c": 3}
	m["d"] += 4
	m["a"]++
	total := 0
	for k, v := range m {
		if k == "b" {
			delete(m, "c")
		}
		total += v
	}
	fmt.Println(len(m), m["zz"], total >= 8)

	fmt.Println(sum(), sum(1, 2, 3), sum([]int{4, 5}...))

	n := 0
outer:
	for i := range 5 {
		for j := 0; ; j++ {
			if j > i {
				continue outer
			}
			if i == 4 {
				break outer
			}
			n += j
		}
	}
	fmt.Println("n", n)

	for n > 0 {
		n -= 3
	}
	if y := n * 2; y < 0 {
		fmt.Println("y negativo", y)
	} else if y == 0 {
		fmt.Println("y zero")
	} else {
		fmt.Println("y positivo")
	}

	for _, v := range []int{-4, 0, 9, 10} {
		fmt.Println(classify(v))
	}
	f := 3.99
	fmt.Println(3.5, float64(7)/2, int(f), int(-f), 1e6, 0.1+0.2)
}
