// Escrito à mão (WIRE.md): medidas e testes da ponte. 27 produz itens de um
// callback sob demanda sem nada do kubo no meio (tool/bench_callback.dart
// escolhe o lote padrão por ele); 28 lê e zera os contadores de sininho, as
// escritas no pipe/socket que acordam o outro lado (chamadas de sistema);
// 29–31 montam um impasse de verdade (deadlock.go): um objeto com mutex, um
// Iterate que o segura enquanto chama o callback e um Touch que o pede.
package main

import (
	"sync"
	"sync/atomic"
)

// testLocker: o objeto com trava dos testes de impasse.
type testLocker struct{ mu sync.Mutex }

// bells: sininhos tocados pelo host (o app dormia) e despertares do host (o
// app tocou o dele).
var bells struct{ rings, wakes atomic.Uint64 }

func init() {
	// u32 lote, i64 n, i64 bytes por item → i64 itens produzidos; o callback
	// recebe (i64 índice, bytes) e para no false
	table[27] = entry{key: "p2p_ffi/test.CallbackBench", fn: func(q *req, r *reader, w *writer) error {
		batch, n, size := r.u32(), r.i64(), r.i64()
		if err := r.done(); err != nil {
			return err
		}
		cb := newCallback(q, batch)
		defer cb.end()
		payload := make([]byte, size)
		var made int64
		for i := range n {
			made++
			if !cb.item(func(w *writer) { w.i64(i); w.bytes(payload) }) {
				break
			}
		}
		w.i64(made)
		return nil
	}}
	table[29] = entry{key: "p2p_ffi/test.NewLocker", fn: noArgs(func(_ *req, w *writer) error {
		encH(w, &testLocker{})
		return nil
	})}
	// i64 locker, u32 lote, i64 n → vazio; o callback recebe (i64 índice)
	// com a trava presa
	table[30] = entry{key: "p2p_ffi/test.Locker.Iterate", fn: func(q *req, r *reader, _ *writer) error {
		l, err := decH[*testLocker](r)
		if err != nil {
			return err
		}
		batch, n := r.u32(), r.i64()
		if err := r.done(); err != nil {
			return err
		}
		l.mu.Lock()
		defer l.mu.Unlock()
		cb := newCallback(q, batch)
		defer cb.end()
		for i := range n {
			if !cb.item(func(w *writer) { w.i64(i) }) {
				return errCallbackStopped
			}
		}
		return nil
	}}
	// i64 locker → vazio, depois de pegar e soltar a trava
	table[31] = entry{key: "p2p_ffi/test.Locker.Touch", fn: func(_ *req, r *reader, _ *writer) error {
		l, err := decH[*testLocker](r)
		if err != nil {
			return err
		}
		if err := r.done(); err != nil {
			return err
		}
		l.mu.Lock()
		l.mu.Unlock()
		return nil
	}}
	// → i64 sininhos tocados pelo host, i64 despertares do host; zera os dois
	table[28] = entry{key: "p2p_ffi/test.BellStats", fn: noArgs(func(_ *req, w *writer) error {
		w.i64(int64(bells.rings.Swap(0)))
		w.i64(int64(bells.wakes.Swap(0)))
		return nil
	})}
}
