//go:build ignore

// Oráculo de `timers.dart` (`timer_context_oracle_test.dart`): timers do
// `time` com a semântica do Go ≥ 1.23. Só ordem de eventos, nunca tempo.
package main

import (
	"fmt"
	"time"
)

const ms = time.Millisecond

func main() {
	// Sleep ordena goroutines pelo prazo.
	done := make(chan string)
	for _, g := range []struct {
		name string
		d    time.Duration
	}{{"c", 60 * ms}, {"a", 20 * ms}, {"b", 40 * ms}} {
		go func() {
			time.Sleep(g.d)
			done <- g.name
		}()
	}
	fmt.Println(<-done, <-done, <-done)

	// After em select: timeout.
	never := make(chan int)
	select {
	case <-never:
		fmt.Println("never")
	case <-time.After(10 * ms):
		fmt.Println("timeout")
	}

	// Timer: len/cap, Stop antes e depois de disparar, Reset.
	t := time.NewTimer(10 * ms)
	fmt.Println(len(t.C), cap(t.C), t.Stop(), t.Stop())
	t.Reset(5 * ms)
	time.Sleep(25 * ms)
	fmt.Println(len(t.C), t.Stop())
	select {
	case <-t.C:
		fmt.Println("stale")
	default:
		fmt.Println("nothing")
	}
	fmt.Println(t.Reset(5*ms), t.Stop(), t.Stop())
	t.Reset(5 * ms)
	<-t.C
	fmt.Println("recv", t.Stop(), t.Reset(time.Hour), t.Stop())

	// Ticker: 3 ticks e Stop.
	tk := time.NewTicker(10 * ms)
	for i := range 3 {
		<-tk.C
		fmt.Println("tick", i)
	}
	tk.Stop()
	time.Sleep(30 * ms)
	select {
	case <-tk.C:
		fmt.Println("tick depois do Stop")
	default:
		fmt.Println("parado")
	}

	// AfterFunc numa goroutine; Stop a tempo impede.
	ran := make(chan string, 2)
	time.AfterFunc(5*ms, func() { ran <- "f" })
	t2 := time.AfterFunc(5*ms, func() { ran <- "nunca" })
	fmt.Println(t2.Stop(), t2.C == nil)
	fmt.Println(<-ran)
	time.Sleep(20 * ms)
	fmt.Println(len(ran))

	// Tick(0) é nil; NewTicker(0) panica.
	fmt.Println(time.Tick(0) == nil)
	func() {
		defer func() { fmt.Println("recover:", recover()) }()
		time.NewTicker(0)
	}()

	// Timer pendente: main bloqueada não é deadlock até ele disparar; f
	// roda e termina, e então sim.
	time.AfterFunc(20*ms, func() { fmt.Println("disparou") })
	<-never
}
