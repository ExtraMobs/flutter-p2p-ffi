// Package conf inicializa variáveis de pacote esperando goroutines: o
// $goInit vira async e o main o espera antes de tudo.
package conf

import (
	"fmt"
	"sync"
)

// Total é calculado por goroutines na inicialização do pacote.
var Total = sum(1, 2, 3, 4)

// Names é preenchido pela função init, que espera um WaitGroup.
var Names []string

func sum(xs ...int) int {
	ch := make(chan int)
	for _, x := range xs {
		go func() { ch <- x * x }()
	}
	t := 0
	for range xs {
		t += <-ch
	}
	return t
}

func init() {
	var wg sync.WaitGroup
	var mu sync.Mutex
	got := map[string]bool{}
	for _, n := range []string{"b", "a", "c"} {
		wg.Go(func() {
			mu.Lock()
			got[n] = true
			mu.Unlock()
		})
	}
	wg.Wait()
	for _, n := range []string{"a", "b", "c"} {
		if got[n] {
			Names = append(Names, n)
		}
	}
	fmt.Println("conf.init", len(Names))
}
