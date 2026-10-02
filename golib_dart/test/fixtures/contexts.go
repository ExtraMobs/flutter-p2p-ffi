//go:build ignore

// Oráculo de `contexts.dart` (`timer_context_oracle_test.dart`): o pacote
// `context` com goroutines e timers. Só ordem de eventos, nunca tempo.
package main

import (
	"context"
	"errors"
	"fmt"
	"time"
)

const ms = time.Millisecond

type key string

// Implementação de fora de Context, sem String(): o cancelamento dela chega
// aos filhos por uma goroutine.
type myCtx struct {
	ch  chan struct{}
	err error
}

func (c *myCtx) Deadline() (time.Time, bool) { return time.Time{}, false }
func (c *myCtx) Done() <-chan struct{}       { return c.ch }
func (c *myCtx) Err() error                  { return c.err }
func (c *myCtx) Value(k any) any {
	if k == key("my") {
		return "valor de myCtx"
	}
	return nil
}

func worker(ctx context.Context, name string, out chan<- string) {
	<-ctx.Done()
	out <- name + ": " + ctx.Err().Error()
}

func main() {
	bg := context.Background()
	fmt.Println(bg, context.TODO(), bg.Done() == nil, bg.Err())
	root, cancelRoot := context.WithCancel(bg)
	vctx := context.WithValue(root, key("k"), 42)
	mid, cancelMid := context.WithCancel(vctx)
	fmt.Println(mid)
	fmt.Println(context.WithValue(context.WithoutCancel(mid), 7, time.Second))
	fmt.Println(mid.Value(key("k")), mid.Value("k"), mid.Value(7))

	// Cascata: cancelar `mid` acorda só os de baixo dele.
	out := make(chan string, 4)
	leaf, cancelLeaf := context.WithCancel(mid)
	defer cancelLeaf()
	sib, cancelSib := context.WithCancel(root)
	go worker(leaf, "leaf", out)
	go worker(mid, "mid", out)
	go worker(sib, "sib", out)
	cancelMid()
	a, b := <-out, <-out
	if a > b {
		a, b = b, a
	}
	fmt.Println(a, "|", b, "|", root.Err(), sib.Err())
	cancelRoot()
	fmt.Println(<-out)
	cancelSib()

	// WithTimeout: DeadlineExceeded, Cause, Timeout().
	tctx, cancelT := context.WithTimeoutCause(bg, 10*ms, errors.New("lento"))
	_, ok := tctx.Deadline()
	fmt.Println(ok, tctx.Err())
	<-tctx.Done()
	fmt.Println(tctx.Err(), context.Cause(tctx), errors.Is(tctx.Err(), context.DeadlineExceeded))
	cancelT()
	te := tctx.Err().(interface{ Timeout() bool })
	fmt.Printf("%v %T %#v\n", te.Timeout(), tctx.Err(), tctx.Err())

	// Timeout do pai vence antes do do filho.
	p, cancelP := context.WithTimeout(bg, 10*ms)
	c, cancelC := context.WithTimeout(p, time.Hour)
	<-c.Done()
	fmt.Println(c.Err(), p.Err())
	cancelC()
	cancelP()

	// Cancelado antes do prazo.
	q, cancelQ := context.WithTimeout(bg, 10*ms)
	cancelQ()
	time.Sleep(20 * ms)
	fmt.Println(q.Err(), context.Cause(q))

	// WithCancelCause.
	cc, cancelCause := context.WithCancelCause(bg)
	cancelCause(errors.New("boom"))
	cancelCause(errors.New("outra"))
	child, _ := context.WithCancel(cc)
	fmt.Println(cc.Err(), context.Cause(cc), child.Err(), context.Cause(child))

	// Pai de fora.
	my := &myCtx{ch: make(chan struct{})}
	mc, cancelMy := context.WithCancel(my)
	fmt.Println(mc, mc.Value(key("my")))
	go func() {
		time.Sleep(5 * ms)
		my.err = context.Canceled
		close(my.ch)
	}()
	<-mc.Done()
	fmt.Println("myCtx:", mc.Err())
	cancelMy()

	// AfterFunc e stop.
	actx, cancelA := context.WithCancel(bg)
	ran := make(chan string, 2)
	stop1 := context.AfterFunc(actx, func() { ran <- "f1" })
	stop2 := context.AfterFunc(actx, func() { ran <- "f2" })
	fmt.Println(stop2(), stop2())
	cancelA()
	fmt.Println(<-ran, stop1())
	time.Sleep(10 * ms)
	fmt.Println(len(ran))

	// WithoutCancel.
	wp, cancelW := context.WithTimeout(context.WithValue(bg, key("k"), "v"), time.Hour)
	w := context.WithoutCancel(wp)
	cancelW()
	_, okW := w.Deadline()
	fmt.Println(wp.Err(), w.Err(), w.Done() == nil, okW, w.Value(key("k")))

	// WithTimeout pendente (AfterFunc interno) segura o deadlock até vencer.
	last, cancelLast := context.WithTimeout(bg, 20*ms)
	defer cancelLast()
	context.AfterFunc(last, func() { fmt.Println("venceu:", last.Err()) })
	never, cancelNever := context.WithCancel(bg)
	defer cancelNever()
	<-never.Done()
}
