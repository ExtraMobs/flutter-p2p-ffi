// Retained callback (WIRE.md, "Retained callback"): a Dart function that Go
// keeps past the call that received it (host.SetStreamHandler, a Dart
// implementation of mdns.Notifee). The Dart side gives it an id of its own;
// each invocation goes to that id as a `callback` event of one item, and when
// Go no longer holds the function (the garbage collector freed it), an `end`
// to the same id lets Dart drop its side.
package main

import (
	"encoding/binary"
	"runtime"
	"sync"
)

type retained struct {
	id   uint32
	send sendFn
	mu   sync.Mutex // one invocation waits for its verdict at a time
	acks chan byte
}

// retainedAcks: the verdict channel of each live retained callback, for
// callbackAck. It holds the channel, not the callback, so the cleanup can run.
var retainedAcks = struct {
	sync.Mutex
	m map[uint32]chan byte
}{m: map[uint32]chan byte{}}

// newRetained: the retained callback [id] of the call [q], or nil for id 0
// (a method a Dart implementation leaves out).
func newRetained(q *req, id uint32) *retained {
	if id == 0 {
		return nil
	}
	rc := &retained{id: id, send: q.send, acks: make(chan byte, 1)}
	retainedAcks.Lock()
	retainedAcks.m[id] = rc.acks
	retainedAcks.Unlock()
	send := q.send
	runtime.AddCleanup(rc, func(id uint32) {
		retainedAcks.Lock()
		delete(retainedAcks.m, id)
		retainedAcks.Unlock()
		send(id, evEnd, nil)
	}, id)
	return rc
}

// call: an invocation whose verdict Go does not need (a func without
// results): Dart runs it on its event loop, and Go goes on.
func (rc *retained) call(enc func(*writer)) {
	w := &writer{b: binary.LittleEndian.AppendUint32(nil, 1)}
	enc(w)
	rc.send(rc.id, evCallback, w.b)
}

// ask: an invocation whose result Go needs (bool or error): waits for the
// Dart verdict; true = go on (Dart returned true, or nothing).
func (rc *retained) ask(enc func(*writer)) bool {
	rc.mu.Lock()
	defer rc.mu.Unlock()
	rc.call(enc)
	waitingCallbacks.Add(1) // deadlock.go
	v := <-rc.acks
	waitingCallbacks.Add(-1)
	return v == verdictContinue
}

// retainedAck: the verdict [verdict] for the retained callback [id]; false if
// [id] is not one.
func retainedAck(id uint32, verdict byte) bool {
	retainedAcks.Lock()
	acks, ok := retainedAcks.m[id]
	retainedAcks.Unlock()
	if ok {
		select {
		case acks <- verdict:
		default:
		}
	}
	return ok
}
