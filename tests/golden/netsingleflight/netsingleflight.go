// singleflight do LookupIPAddr (lookup.go do Go): consultas iguais
// simultâneas no mesmo Resolver saem uma vez só. O Dial do Resolver conta as
// discagens e segura cada uma até o portão abrir; depois falha. O número de
// discagens depende do /etc/resolv.conf (servidores × tentativas), então só
// aparece comparado com o de uma consulta sozinha.
package main

import (
	"context"
	"errors"
	"fmt"
	"net"
	"sync"
	"sync/atomic"
	"time"
)

var (
	dials atomic.Int32
	gate  chan struct{}
	mu    sync.Mutex
)

func newResolver() *net.Resolver {
	return &net.Resolver{PreferGo: true, Dial: func(ctx context.Context, network, address string) (net.Conn, error) {
		dials.Add(1)
		select {
		case <-gate:
			return nil, errors.New("fake dial refused")
		case <-ctx.Done():
			return nil, ctx.Err()
		}
	}}
}

// together roda as consultas ao mesmo tempo e abre o portão depois que
// todas começaram.
func together(fs ...func()) {
	var wg sync.WaitGroup
	for _, f := range fs {
		wg.Add(1)
		go func() { defer wg.Done(); f() }()
	}
	time.Sleep(100 * time.Millisecond)
	close(gate)
	wg.Wait()
}

func lookup(r *net.Resolver, host string, errs *[]bool) func() {
	return func() {
		_, err := r.LookupIPAddr(context.Background(), host)
		mu.Lock()
		*errs = append(*errs, err != nil)
		mu.Unlock()
	}
}

func main() {
	r := newResolver()
	var errs []bool
	gate = make(chan struct{})
	together(lookup(r, "sf.test", &errs))
	single := dials.Swap(0)
	fmt.Println("single:", single > 0, errs)

	errs = nil
	gate = make(chan struct{})
	together(lookup(r, "sf.test", &errs), lookup(r, "sf.test", &errs), lookup(r, "sf.test", &errs))
	fmt.Println("concurrent == single:", dials.Swap(0) == single, errs)

	// Nomes diferentes não se juntam.
	gate = make(chan struct{})
	together(lookup(r, "a.sf.test", &errs), lookup(r, "b.sf.test", &errs))
	fmt.Println("two names == 2*single:", dials.Swap(0) == 2*single)

	// Resolvers diferentes não se juntam.
	gate = make(chan struct{})
	together(lookup(r, "sf.test", &errs), lookup(newResolver(), "sf.test", &errs))
	fmt.Println("two resolvers == 2*single:", dials.Swap(0) == 2*single)

	// Quem cancela sai logo com o erro do ctx; a consulta compartilhada segue
	// e o outro recebe o resultado dela.
	gate = make(chan struct{})
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan string, 2)
	go func() {
		_, err := r.LookupIPAddr(context.Background(), "sf.test")
		done <- fmt.Sprint("background: err=", err != nil)
	}()
	time.Sleep(20 * time.Millisecond)
	go func() {
		_, err := r.LookupIPAddr(ctx, "sf.test")
		done <- fmt.Sprint("canceled: ", err)
	}()
	time.Sleep(50 * time.Millisecond)
	cancel()
	fmt.Println(<-done)
	close(gate)
	fmt.Println(<-done)
	fmt.Println("shared after cancel == single:", dials.Swap(0) == single)

	// Sozinho e cancelado: a consulta é esquecida e cancelada (o Dial vê o
	// ctx cancelado), e a próxima começa do zero.
	gate = make(chan struct{})
	ctx, cancel = context.WithCancel(context.Background())
	go func() { time.Sleep(50 * time.Millisecond); cancel() }()
	_, err := r.LookupIPAddr(ctx, "sf.test")
	fmt.Println("alone canceled:", err)
	time.Sleep(50 * time.Millisecond)
	dials.Swap(0)
	close(gate)
	_, err = r.LookupIPAddr(context.Background(), "sf.test")
	var de *net.DNSError
	fmt.Println("after forget:", errors.As(err, &de), dials.Swap(0) == single)
}
