// context.CancelFunc é uma classe própria (síncrona, formato do shim) e a
// func() comum fica livre para ser async (TODO D7).
package main

import (
	"context"
	"fmt"
	"time"
)

type closers struct{ fns []func() }

func (c *closers) add(f func()) { c.fns = append(c.fns, f) }

func (c *closers) run() {
	for i := len(c.fns) - 1; i >= 0; i-- {
		c.fns[i]()
	}
}

// return de vários resultados: CancelFunc → func() async.
func withCancel(ctx context.Context) (context.Context, func()) {
	return context.WithCancel(ctx)
}

func main() {
	log := make(chan string, 10)
	c := &closers{}

	ctx, cancel := context.WithCancel(context.Background())
	c.add(cancel)                       // CancelFunc vira func() async: embrulhada
	c.add(func() { log <- "closure" }) // closure que suspende guardada como func()

	// atribuição de vários valores para uma variável func().
	var stop func()
	_, stop = context.WithTimeout(ctx, time.Hour)
	c.add(stop)

	ctx2, cancel2 := withCancel(ctx)
	c.add(cancel2)

	// literal síncrono num CancelFunc: continua síncrono.
	var done context.CancelFunc = func() { fmt.Println("done") }
	var plain func() = done // CancelFunc → func() async

	var none context.CancelFunc
	var f2 func() = none // nil continua nil
	fmt.Println(f2 == nil)

	c.run()
	generics(log)
	fields(log)
	plain()
	done()
	close(log)
	for s := range log {
		fmt.Println(s)
	}
	<-ctx.Done()
	fmt.Println(ctx.Err(), ctx2.Err())
}
