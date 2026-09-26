// sync/atomic: tipos como structs de shim (impressos como o Go), funções sobre
// *T; contadores do go.opentelemetry.io/otel e Pointer[T]/Value.
package main

import (
	"fmt"
	"sync/atomic"
)

// Counter de go.opentelemetry.io/otel/.../internal/counter.
var exporterN atomic.Int64

func NextExporterID() int64 { return exporterN.Add(1) - 1 }

type cfg struct{ name string }

type stats struct {
	hits   atomic.Uint64
	closed atomic.Bool
	cur    atomic.Pointer[cfg]
	last   atomic.Value
}

func try(f func()) (r any) {
	defer func() { r = recover() }()
	f()
	return
}

func main() {
	fmt.Println(NextExporterID(), NextExporterID(), exporterN.Load())
	var s stats
	s.hits.Add(3)
	s.hits.Add(4)
	fmt.Println(s.hits.Load(), s.closed.CompareAndSwap(false, true), s.closed.Load(), s.closed.Swap(false))
	c1 := &cfg{"a"}
	fmt.Println(s.cur.Load() == nil, s.cur.CompareAndSwap(nil, c1), s.cur.Load().name, s.cur.CompareAndSwap(nil, c1))
	s.last.Store("x")
	fmt.Println(s.last.Load(), try(func() { s.last.Store(1) }), try(func() { s.last.Store(nil) }))
	fmt.Println(s.last.CompareAndSwap("x", "y"), s.last.Load(), s.last.Swap("z"))

	var n32 int32 = 5
	var u64 uint64
	fmt.Println(atomic.AddInt32(&n32, -2), atomic.LoadInt32(&n32), atomic.CompareAndSwapInt32(&n32, 3, 9), n32)
	atomic.StoreUint64(&u64, 1<<63)
	fmt.Println(atomic.AddUint64(&u64, 1), atomic.SwapUint64(&u64, 7), u64)
	var i32 atomic.Int32
	i32.Store(-1)
	fmt.Println(i32.And(6), i32.Or(1), i32.Load())
	var a atomic.Int64
	a.Store(5)
	fmt.Println(a, &s.hits == &s.hits)
	fmt.Printf("%+v %v\n", s.closed, s.last.Load())
}
