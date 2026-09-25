// Package main exercita: f(g()) com múltiplos retornos, literais
// indexados, method expressions/values e map com chave ponteiro.
package main

import "fmt"

type Point struct{ X, Y int }

func (p Point) Sum() int        { return p.X + p.Y }
func (p *Point) Scale(k int)    { p.X *= k; p.Y *= k }
func (p Point) Add(q Point) Point { return Point{p.X + q.X, p.Y + q.Y} }

func pair() (int, string)        { return 7, "sete" }
func show(n int, s string) string { return fmt.Sprint(n, "=", s) }
func triple() (int, int, int)    { return 1, 2, 3 }
func sum(xs ...int) int {
	t := 0
	for _, x := range xs {
		t += x
	}
	return t
}

func main() {
	fmt.Println(show(pair()))
	fmt.Println(pair())
	fmt.Println(sum(triple()))

	primes := []int{2: 5, 7, 0: 1}
	days := [...]string{3: "qua", 1: "seg"}
	fmt.Println(primes, len(primes), days, len(days))

	sumOf := Point.Sum
	scale := (*Point).Scale
	p := Point{1, 2}
	scale(&p, 10)
	add := p.Add
	fmt.Println(sumOf(p), p, add(Point{1, 1}))

	a, b := &Point{1, 1}, &Point{1, 1}
	seen := map[*Point]string{a: "a"}
	seen[b] = "b"
	_, hasA := seen[a]
	fmt.Println(len(seen), seen[a], seen[b], hasA, *a == *b)
	delete(seen, a)
	fmt.Println(len(seen), seen[b])
}
