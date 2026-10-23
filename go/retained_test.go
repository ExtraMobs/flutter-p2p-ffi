package main

import (
	"runtime"
	"sync"
	"testing"
	"time"
)

// A retained callback: each invocation is a one-item `callback` event to its
// id, ask waits for the verdict, and once Go drops the function the host
// sends `end` to the id.
func TestRetainedCallback(t *testing.T) {
	type ev struct {
		id   uint32
		kind byte
		data []byte
	}
	var mu sync.Mutex
	var got []ev
	ended := make(chan uint32, 1)
	send := func(id uint32, kind byte, data []byte) {
		mu.Lock()
		got = append(got, ev{id, kind, data})
		mu.Unlock()
		if kind == evEnd {
			ended <- id
		}
	}
	q := &req{id: 1, send: send}
	if newRetained(q, 0) != nil {
		t.Fatal("id 0 is nil")
	}

	func() {
		rc := newRetained(q, 9)
		var f func(int64) = func(v int64) { rc.call(func(w *writer) { encInt(w, v) }) }
		f(42)
		go func() {
			for {
				mu.Lock()
				n := len(got)
				mu.Unlock()
				if n == 2 {
					callbackAck([]byte{9, 0, 0, 0, verdictStop})
					return
				}
				time.Sleep(time.Millisecond)
			}
		}()
		if rc.ask(func(w *writer) { encInt(w, int64(7)) }) {
			t.Error("verdict 1 is false")
		}
	}()
	mu.Lock()
	if len(got) != 2 || got[0].id != 9 || got[0].kind != evCallback || got[0].data[0] != 1 {
		t.Fatalf("events %v", got)
	}
	mu.Unlock()

	for i := 0; i < 50; i++ { // the cleanup runs after a GC cycle
		runtime.GC()
		select {
		case id := <-ended:
			if id != 9 {
				t.Fatalf("end for %d", id)
			}
			if retainedAck(9, 0) {
				t.Error("still registered after the end")
			}
			return
		case <-time.After(20 * time.Millisecond):
		}
	}
	t.Fatal("no end after Go dropped the function")
}
