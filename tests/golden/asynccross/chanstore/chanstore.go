// Package chanstore implementa store.Store com uma goroutine servidora.
package chanstore

import "g2d.test/asynccross/store"

// A asserção de interface põe store.Store no implements deste pacote.
var _ store.Store = (*S)(nil)

type request struct {
	key   string
	reply chan string
}

// S responde por canais.
type S struct {
	reqs chan request
}

// New inicia a goroutine que serve os pedidos.
func New(data map[string]string) *S {
	s := &S{reqs: make(chan request)}
	go func() {
		for r := range s.reqs {
			r.reply <- data[r.key]
		}
	}()
	return s
}

// Get envia o pedido e espera a resposta.
func (s *S) Get(k string) string {
	r := request{k, make(chan string)}
	s.reqs <- r
	return <-r.reply
}
