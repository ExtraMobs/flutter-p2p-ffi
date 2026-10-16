// Impasse com callback (WIRE.md, "Callback"): enquanto o Go espera o Dart
// consumir um lote, a função Dart pode chamar a ponte de novo, e chamar um
// objeto que a função Go do callback trava (um mutex) para até o fim. O Dart
// marca (modeWatch) o pedido que toca um objeto em uso por uma chamada com
// callback; o host roda esse pedido numa goroutine com o id dele nos labels
// do pprof e o vigia. Parado num mutex por deadlockAfter enquanto um callback
// espera o Dart, é impasse: o pedido responde errDeadlock na hora, o Dart
// lança IpfsDeadlockException dentro da função dele, o callback Go para, a
// função Go volta e solta a trava; a goroutine presa termina depois, e a
// resposta tardia dela é descartada.
package main

import (
	"bytes"
	"context"
	"runtime/pprof"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

const (
	// modeWatch: bit do modo do pedido (WIRE.md).
	modeWatch = 0x80

	// deadlockAfter: quanto tempo parado num mutex conta como impasse.
	// ponytail: fixo; vira argumento se aparecer trava legítima mais longa.
	deadlockAfter = time.Second
)

// waitingCallbacks: callbacks Go esperando a confirmação do Dart agora.
var waitingCallbacks atomic.Int32

// watch roda o pedido [id] vigiado e volta quando ele termina ou quando o
// impasse é confirmado (a resposta de erro já foi mandada).
func (h *host) watch(e entry, id uint32, args []byte) {
	var abandoned atomic.Bool
	var once sync.Once
	final := func(kind byte, data []byte) { once.Do(func() { h.reply(id, kind, data) }) }
	send := func(sid uint32, kind byte, data []byte) { // itens e sinks, enquanto vale
		if !abandoned.Load() {
			h.reply(sid, kind, data)
		}
	}
	done := make(chan struct{})
	label := strconv.FormatUint(uint64(id), 10)
	go func() {
		defer close(done)
		pprof.Do(context.Background(), pprof.Labels("ipfs_call", label), func(context.Context) {
			kind, data := invoke(e, id, args, send)
			if !abandoned.Load() {
				final(kind, data)
			}
		})
	}()
	t := time.NewTicker(deadlockAfter / 4)
	defer t.Stop()
	start := time.Now()
	for {
		select {
		case <-done:
			return
		case <-t.C:
			if time.Since(start) < deadlockAfter || waitingCallbacks.Load() == 0 {
				continue
			}
			if stack, ok := blockedOnLock(label); ok {
				abandoned.Store(true)
				final(evError, append([]byte{errDeadlock}, "ipfs_host: deadlock: "+e.key+
					" waits for a lock held by a Go call whose Dart callback is running; Go stack:\n"+stack...))
				return
			}
		}
	}
}

// blockedOnLock: a goroutine do pedido [label] (ou uma filha dela, que herda
// os labels) está parada num mutex; devolve a pilha dela.
func blockedOnLock(label string) (string, bool) {
	var buf bytes.Buffer
	if err := pprof.Lookup("goroutine").WriteTo(&buf, 1); err != nil {
		return "", false
	}
	want := `"ipfs_call":"` + label + `"`
	for _, g := range strings.Split(buf.String(), "\n\n") {
		if strings.Contains(g, want) && (strings.Contains(g, "SemacquireMutex") || strings.Contains(g, "SemacquireRWMutex")) {
			return g, true
		}
	}
	return "", false
}
