// sync sem goroutines: Pool (pebble/zap), [0]sync.Mutex (protobuf pragma), Mutex
// e RWMutex com defer, Once, OnceValue/OnceFunc, WaitGroup, Map, Locker, Cond.
package main

import (
	"fmt"
	"sync"
)

// pebble/internal/intern e zap/internal/pool: sync.Pool com New.
var bufPool = sync.Pool{New: func() any { return new([]byte) }}

type DoNotCopy [0]sync.Mutex // protobuf/internal/pragma

type counter struct {
	_  DoNotCopy
	mu sync.Mutex
	n  map[string]int
}

func (c *counter) inc(k string) int {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.n[k]++
	return c.n[k]
}

type cache struct {
	rw sync.RWMutex
	m  map[int]string
}

func (c *cache) get(k int) (string, bool) {
	c.rw.RLock()
	defer c.rw.RUnlock()
	v, ok := c.m[k]
	return v, ok
}

func main() {
	b := bufPool.Get().(*[]byte)
	*b = append(*b, 'x')
	bufPool.Put(b)
	b2 := bufPool.Get().(*[]byte)
	fmt.Println(string(*b2), b == b2, len(*bufPool.Get().(*[]byte)))

	c := &counter{n: map[string]int{}}
	c.inc("a")
	fmt.Println(c.inc("a"), c.mu.TryLock(), c.mu.TryLock())
	c.mu.Unlock()

	ca := &cache{m: map[int]string{1: "um"}}
	fmt.Println(ca.get(1))
	fmt.Println(ca.rw.TryRLock(), ca.rw.TryLock())
	ca.rw.RUnlock()
	fmt.Println(ca.rw.TryLock())
	ca.rw.Unlock()

	var once sync.Once
	for i := 0; i < 3; i++ {
		once.Do(func() { fmt.Println("uma vez", i) })
	}
	calls := 0
	v := sync.OnceValue(func() int { calls++; return 42 })
	fmt.Println(v(), v(), calls)
	f := sync.OnceFunc(func() { panic("boom") })
	for i := 0; i < 2; i++ {
		func() {
			defer func() { fmt.Println("recover:", recover()) }()
			f()
		}()
	}

	var wg sync.WaitGroup
	wg.Add(2)
	wg.Done()
	wg.Done()
	wg.Wait()
	fmt.Println("wg ok")

	var m sync.Map
	m.Store("a", 1)
	m.Store("b", 2)
	act, loaded := m.LoadOrStore("a", 9)
	fmt.Println(act, loaded)
	sum := 0
	m.Range(func(k, v any) bool { sum += v.(int); return true })
	fmt.Println("soma", sum)
	m.Delete("a")
	_, ok := m.Load("a")
	fmt.Println(ok, m.CompareAndSwap("b", 2, 3))
	x, _ := m.Load("b")
	fmt.Println(x)

	var mu sync.Mutex
	var l sync.Locker = &mu
	l.Lock()
	fmt.Println(mu)
	l.Unlock()
	cond := sync.NewCond(&mu)
	cond.Signal()
	cond.Broadcast()
	fmt.Println(mu, once)
}
