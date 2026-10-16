// Escrito à mão (WIRE.md): medidas da ponte. 27 produz itens de um callback
// sob demanda sem nada do kubo no meio (tool/bench_callback.dart escolhe o
// lote padrão por ele); 28 lê e zera os contadores de sininho, as escritas no
// pipe/socket que acordam o outro lado (chamadas de sistema).
package main

import "sync/atomic"

// bells: sininhos tocados pelo host (o app dormia) e despertares do host (o
// app tocou o dele).
var bells struct{ rings, wakes atomic.Uint64 }

func init() {
	// u32 lote, i64 n, i64 bytes por item → i64 itens produzidos; o callback
	// recebe (i64 índice, bytes) e para no false
	table[27] = entry{key: "ipfs_ffi/test.CallbackBench", fn: func(q *req, r *reader, w *writer) error {
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
	// → i64 sininhos tocados pelo host, i64 despertares do host; zera os dois
	table[28] = entry{key: "ipfs_ffi/test.BellStats", fn: noArgs(func(_ *req, w *writer) error {
		w.i64(int64(bells.rings.Swap(0)))
		w.i64(int64(bells.wakes.Swap(0)))
		return nil
	})}
}
