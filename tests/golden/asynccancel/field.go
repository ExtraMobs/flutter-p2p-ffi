package main

import (
	"context"
	"fmt"
	"sync"
)

// Campo func() não exportado tem classe de cor própria: guardando um
// CancelFunc ele fica síncrono, e a closure que o chama ainda pode virar
// CancelFunc (go.uber.org/fx/internal/fxclock).
type deadlineCtx struct {
	cancelInner func()
	mu          sync.Mutex
	err         error
}

func (c *deadlineCtx) cancel(err error) {
	c.mu.Lock()
	if c.err == nil {
		c.err = err
		c.cancelInner()
	}
	c.mu.Unlock()
}

func withTimeout(ctx context.Context) (context.Context, context.CancelFunc) {
	inner, cancelInner := context.WithCancel(ctx)
	d := &deadlineCtx{cancelInner: cancelInner}
	return inner, func() { d.cancel(context.Canceled) }
}

// Campo que recebe uma closure que suspende: classe async.
type job struct{ run func() }

func fields(log chan string) {
	ctx, cancel := withTimeout(context.Background())
	cancel()
	cancel()
	fmt.Println("fields:", ctx.Err())
	j := job{run: func() { log <- "job" }}
	if j.run != nil {
		j.run()
	}
}
