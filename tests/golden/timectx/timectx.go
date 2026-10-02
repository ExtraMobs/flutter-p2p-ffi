// Timers do time e o shim context com goroutines (M4c).
package main

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"
)

type ctxKey string

func worker(ctx context.Context, id int, out chan<- string) {
	tick := time.NewTicker(2 * time.Millisecond)
	defer tick.Stop()
	n := 0
	for {
		select {
		case <-ctx.Done():
			out <- fmt.Sprintf("worker %d parou: %v", id, ctx.Err())
			return
		case <-tick.C:
			n++
		}
	}
}

func slow(ctx context.Context, d time.Duration) error {
	select {
	case <-time.After(d):
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func main() {
	// Sleep ordena goroutines
	var mu sync.Mutex
	var order []int
	var wg sync.WaitGroup
	for _, ms := range []int{60, 20, 40} {
		wg.Add(1)
		go func() {
			defer wg.Done()
			time.Sleep(time.Duration(ms) * time.Millisecond)
			mu.Lock()
			order = append(order, ms)
			mu.Unlock()
		}()
	}
	wg.Wait()
	fmt.Println("ordem:", order)

	// Timer: Stop antes de disparar, Reset
	t := time.NewTimer(time.Hour)
	fmt.Println("stop:", t.Stop())
	t.Reset(time.Millisecond)
	<-t.C
	fmt.Println("disparou; stop depois:", t.Stop())

	// AfterFunc
	done := make(chan struct{})
	time.AfterFunc(time.Millisecond, func() { close(done) })
	<-done
	fmt.Println("afterfunc")

	// context: cancelamento em cascata
	root := context.WithValue(context.Background(), ctxKey("user"), "ana")
	ctx, cancel := context.WithCancel(root)
	out := make(chan string)
	go worker(ctx, 1, out)
	time.Sleep(5 * time.Millisecond)
	cancel()
	fmt.Println(<-out)
	fmt.Println("valor:", ctx.Value(ctxKey("user")), ctx.Value(ctxKey("x")))

	// WithTimeout
	tctx, tcancel := context.WithTimeout(context.Background(), 3*time.Millisecond)
	defer tcancel()
	err := slow(tctx, time.Hour)
	fmt.Println("timeout:", err, errors.Is(err, context.DeadlineExceeded))
	fmt.Println("rápido:", slow(context.Background(), time.Millisecond))

	// Cause
	cctx, ccancel := context.WithCancelCause(context.Background())
	ccancel(errors.New("motivo"))
	fmt.Println("causa:", cctx.Err(), context.Cause(cctx))
	fmt.Println(context.Background(), context.TODO())
}
