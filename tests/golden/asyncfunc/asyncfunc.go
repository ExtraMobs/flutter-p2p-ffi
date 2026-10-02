// Valores func que suspendem (M4): a classe da assinatura vira
// `Future<R> Function(...)` e toda chamada por valor dela espera.
package main

import (
	"errors"
	"fmt"
	"sync"
)

// Group imita o golang.org/x/sync/errgroup: guarda o primeiro erro.
type Group struct {
	wg   sync.WaitGroup
	once sync.Once
	err  error
}

func (g *Group) Go(f func() error) {
	g.wg.Add(1)
	go func() {
		defer g.wg.Done()
		if err := f(); err != nil {
			g.once.Do(func() { g.err = err })
		}
	}()
}

func (g *Group) Wait() error {
	g.wg.Wait()
	return g.err
}

// Handler é um tipo nomeado sobre func: a classe é a da assinatura.
type Handler func(string) string

type server struct {
	in  chan string
	out chan string
}

func (s *server) loop() {
	for v := range s.in {
		s.out <- "<" + v + ">"
	}
	close(s.out)
}

// Ask suspende: method value dele vira valor async.
func (s *server) Ask(v string) string {
	s.in <- v
	return <-s.out
}

func upper(s string) string { // síncrona, mas da mesma classe: embrulhada
	b := []byte(s)
	for i, c := range b {
		if c >= 'a' && c <= 'z' {
			b[i] = c - 32
		}
	}
	return string(b)
}

type pipeline struct {
	steps []func(string) string
}

func (p *pipeline) run(v string) string {
	for _, f := range p.steps {
		v = f(v)
	}
	return v
}

func compose(f, g Handler) Handler {
	return func(s string) string { return g(f(s)) }
}

func apply[T, U any](x T, f func(T) U) U { return f(x) }

func main() {
	s := &server{in: make(chan string), out: make(chan string)}
	go s.loop()

	// method value async, função síncrona e literal na mesma classe
	p := &pipeline{steps: []func(string) string{upper, s.Ask, func(v string) string { return v + "!" }}}
	fmt.Println(p.run("go"))

	// tipo nomeado sobre func, composição e retorno de func
	var h Handler = s.Ask
	h = compose(h, upper)
	fmt.Println(h("dart"))

	// guardado numa interface e recuperado por type assertion
	var a any = p.steps[1]
	if f, ok := a.(func(string) string); ok {
		fmt.Println(f("any"))
	}

	// errgroup: closures que esperam canais
	var g Group
	results := make(chan int, 3)
	for i := range 3 {
		g.Go(func() error {
			results <- i * 10
			if i == 1 {
				return errors.New("falhou 1")
			}
			return nil
		})
	}
	fmt.Println("erro:", g.Wait())
	close(results)
	sum := 0
	for r := range results {
		sum += r
	}
	fmt.Println("soma:", sum)

	// Once.Do com valor func async e defer de chamada por valor
	var once sync.Once
	step := func() { fmt.Println("once:", s.Ask("x")) }
	once.Do(step)
	once.Do(step)
	func() {
		defer step()
		fmt.Println("antes do defer")
	}()

	// genérico: parâmetro func(T) U tem formato fixo (síncrono)
	fmt.Println(apply(21, func(x int) int { return x * 2 }))
	close(s.in)
}
