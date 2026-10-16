// Callback sob demanda (WIRE.md, "Callback"): uma função Go com parâmetro
// func(...) recebe do despachante gerado um callback Go de verdade, que leva
// os argumentos de cada invocação ao Dart em lotes. O Dart chama a função
// dele com cada item, em ordem, e confirma o lote (fnCallbackAck); o Go só
// segue depois da confirmação, então fica no máximo um lote à frente, e com
// lote de 1 a semântica é a do Go: cada invocação devolve o veredito do Dart.
package main

import (
	"encoding/binary"
	"errors"
	"sync"
)

const (
	// evCallback: um lote de invocações do callback da chamada (u32 n + n
	// conjuntos de argumentos).
	evCallback = 4

	// fnCallbackAck: u32 id da chamada + u8 veredito; sem resposta (id 0).
	fnCallbackAck = 5

	// defaultCallbackBatch: o lote quando o Dart manda 0 (batchSize omitido).
	// Medido (tool/bench_callback.dart, ipfs_ffi/TODO.md, 0.17.0): no Windows
	// e no linux a vazão de itens pequenos sobe até 1024–2048 por lote; no
	// emulador Android segue subindo (cada ida e volta custa ms lá).
	// ponytail: falta confirmar num aparelho real.
	defaultCallbackBatch = 1024

	// maxCallbackBytes: o lote fecha neste tamanho mesmo sem completar os
	// itens. Acima de ~128 KiB a vazão cai pela metade no Windows e no linux
	// (e a espera pelo primeiro item sobe para ms).
	maxCallbackBytes = 128 << 10
)

// Vereditos do Dart para um lote (fnCallbackAck).
const (
	verdictContinue = 0
	verdictStop     = 1 // a função Dart devolveu false
	verdictThrew    = 2 // a função Dart lançou: o Dart guarda a exceção
)

// errCallbackStopped: o que um callback `func(...) error` devolve ao Go
// quando o Dart parou; a chamada termina com ele, e o Dart o troca pelo que
// aconteceu do lado dele.
var errCallbackStopped = errors.New("ipfs_ffi: the Dart callback stopped the iteration")

// callback: o lado Go de um callback do Dart numa chamada em curso.
type callback struct {
	mu    sync.Mutex // o Go pode invocar de mais de uma goroutine
	q     *req
	batch int
	buf   []byte // o lote em montagem, depois do u32 n
	n     int
	acks  chan byte
	stop  byte
}

var callbacks = struct {
	sync.Mutex
	m map[uint32]*callback
}{m: map[uint32]*callback{}}

// newCallback registra o callback da chamada [q] com lotes de [batch] itens
// (0 = defaultCallbackBatch).
func newCallback(q *req, batch uint32) *callback {
	if batch == 0 {
		batch = defaultCallbackBatch
	}
	c := &callback{q: q, batch: int(batch), acks: make(chan byte, 1)}
	callbacks.Lock()
	callbacks.m[q.id] = c
	callbacks.Unlock()
	return c
}

// item: uma invocação do callback pelo Go, com os argumentos escritos por
// [enc]. Quando o lote fecha, espera o Dart consumi-lo. Devolve false se o
// Dart parou (o callback Go devolve false ou errCallbackStopped).
func (c *callback) item(enc func(*writer)) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.stop != verdictContinue {
		return false
	}
	w := &writer{b: c.buf}
	enc(w)
	c.buf = w.b
	c.n++
	if c.n >= c.batch || len(c.buf) >= maxCallbackBytes {
		c.flush()
		waitingCallbacks.Add(1) // deadlock.go
		c.stop = <-c.acks
		waitingCallbacks.Add(-1)
	}
	return c.stop == verdictContinue
}

// flush manda o lote em montagem (se houver).
func (c *callback) flush() {
	if c.n == 0 {
		return
	}
	data := binary.LittleEndian.AppendUint32(make([]byte, 0, 4+len(c.buf)), uint32(c.n))
	c.q.send(c.q.id, evCallback, append(data, c.buf...))
	c.buf, c.n = nil, 0
}

// end: a função Go voltou. O que sobrou no lote vai sem esperar (o Dart
// consome antes de entregar o resultado da chamada) e o callback sai do
// registro; uma confirmação que chegar depois é ignorada.
func (c *callback) end() {
	c.mu.Lock()
	if c.stop == verdictContinue {
		c.flush()
	}
	c.mu.Unlock()
	callbacks.Lock()
	delete(callbacks.m, c.q.id)
	callbacks.Unlock()
}

// callbackAck entrega o veredito do Dart [args] (fnCallbackAck) ao callback
// que espera.
func callbackAck(args []byte) {
	r := &reader{b: args}
	id, verdict := r.u32(), r.u8()
	if r.err != nil {
		return
	}
	callbacks.Lock()
	c := callbacks.m[id]
	callbacks.Unlock()
	if c != nil {
		select {
		case c.acks <- verdict:
		default: // confirmação sem lote esperando (depois do fim): ignorada
		}
	}
}
