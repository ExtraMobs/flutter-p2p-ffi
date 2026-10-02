// Cor async transitiva (M4): quem chama quem suspende também suspende,
// atravessando interfaces, embedding, tipos nomeados, genéricos, defer,
// sync.Once/WaitGroup e um Mutex disputado de verdade entre goroutines.
package main

import (
	"fmt"
	"sync"
)

// recv suspende no próprio corpo; twice só chama (cor transitiva).
func recv(ch chan int) int { return <-ch }

func twice(ch chan int) int { return recv(ch) + recv(ch) }

// Recursão: o ciclo não impede a cor.
func countdown(ch chan int, n int) int {
	if n == 0 {
		return <-ch
	}
	return countdown(ch, n-1) + 1
}

// Uma implementação suspende: o método da interface (e todas as
// implementações) viram Future.
type Source interface {
	Next() int
	Name() string
}

type fixed struct{ v int }

func (f fixed) Next() int    { return f.v }
func (f fixed) Name() string { return "fixed" }

type piped struct{ ch chan int }

func (p *piped) Next() int    { return <-p.ch }
func (p *piped) Name() string { return "piped" }

// Next e Name promovidos de *piped.
type wrapper struct {
	*piped
	tag string
}

// Tipo nomeado sobre básico: *counter encaminha para o método de valor.
type counter int

func (c counter) Plus(ch chan int) int { return int(c) + <-ch }

type adder interface{ Plus(ch chan int) int }

// Genérico: chamada pelo método da restrição.
type nexter interface{ Next() int }

// tap tem receptor valor (argumento de tipo não anulável).
type tap struct{ ch chan int }

func (t tap) Next() int { return <-t.ch }

func sum[T nexter](xs []T) int {
	s := 0
	for _, x := range xs {
		s += x.Next()
	}
	return s
}

type locked struct {
	mu sync.Mutex
	n  int
}

// Inc espera o Mutex (pode estar com outra goroutine): async.
func (l *locked) Inc() {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.n++
}

// String é chamado pelo fmt de forma síncrona: o Lock fica síncrono.
func (l *locked) String() string {
	l.mu.Lock()
	defer l.mu.Unlock()
	return fmt.Sprintf("locked(%d)", l.n)
}

// tally nunca suspende segurando o Mutex: lock() síncrono, Add fica síncrona.
type tally struct {
	mu sync.Mutex
	n  int
}

func (t *tally) Add(d int) int {
	t.mu.Lock()
	t.n += d
	v := t.n
	t.mu.Unlock()
	return v
}

func pair(ch chan int) (int, bool) {
	v, ok := <-ch
	return v, ok
}

// O defer espera um canal: a função roda os defers com await.
func deferred(ch chan int, out *[]int) {
	defer func() { *out = append(*out, <-ch) }()
	*out = append(*out, 1)
}

func main() {
	ch := make(chan int, 10)
	for i := 1; i <= 6; i++ {
		ch <- i
	}
	fmt.Println("twice", twice(ch))
	fmt.Println("countdown", countdown(ch, 3))
	for _, s := range []Source{fixed{7}, &piped{ch}, wrapper{&piped{ch}, "w"}} {
		fmt.Println(s.Name(), s.Next())
	}

	var once sync.Once
	for i := 0; i < 2; i++ {
		once.Do(func() { fmt.Println("once", <-ch) })
	}

	ch <- 1
	ch <- 2
	var ad adder = counter(5)
	var adp adder = new(counter)
	fmt.Println("plus", ad.Plus(ch), adp.Plus(ch))

	ch <- 10
	ch <- 20
	fmt.Println("sum", sum([]tap{{ch}, {ch}}))

	ch <- 9
	v := func() int { return <-ch * 2 }()
	fmt.Println("lit", v)

	c2 := make(chan int, 1)
	c2 <- 5
	close(c2)
	a, ok := pair(c2)
	b, ok2 := pair(c2)
	fmt.Println("pair", a, ok, b, ok2)

	ch <- 8
	var out []int
	deferred(ch, &out)
	fmt.Println("defer", out)

	p := &piped{make(chan int)}
	got := make(chan int)
	go func() { got <- p.Next() }()
	p.ch <- 42
	fmt.Println("go", <-got)

	var wg sync.WaitGroup
	res := make(chan int, 2)
	wg.Go(func() { res <- 1 })
	wg.Go(func() { res <- 2 })
	wg.Wait()
	fmt.Println("wg", <-res+<-res)

	// Mutex disputado: a primeira goroutine segura o lock enquanto espera um
	// canal; a segunda (Inc) tem que suspender no Lock até ela soltar.
	var l locked
	held := make(chan bool)
	release := make(chan bool)
	done := make(chan bool)
	go func() {
		l.mu.Lock()
		held <- true
		<-release
		l.n += 10
		l.mu.Unlock()
		done <- true
	}()
	<-held
	go func() {
		l.Inc()
		done <- true
	}()
	release <- true
	<-done
	<-done
	fmt.Println("mutex", l.String(), &l)

	var tl tally
	go func() {
		tl.Add(1)
		done <- true
	}()
	<-done
	fmt.Println("tally", tl.Add(2))
}
