// Escrito à mão (WIRE.md): os ganchos de teste (24–26) e os perfis de config
// (40–41; config.Profiles é um mapa de funções, ver API.md).
package main

import (
	"encoding/json"
	"fmt"
	"sort"

	"github.com/ipfs/kubo/config"
)

// noArgs: entrada sem argumentos.
func noArgs(f func(q *req, w *writer) error) func(*req, *reader, *writer) error {
	return func(q *req, r *reader, w *writer) error {
		if err := r.done(); err != nil {
			return err
		}
		return f(q, w)
	}
}

func init() {
	// test/crash_child.dart: panic numa goroutine fora de qualquer chamada,
	// como um bug interno do kubo; o guard não o alcança e o host cai.
	table[24] = entry{key: "ipfs_ffi/test.PanicInGoroutine", fn: noArgs(func(*req, *writer) error {
		go func() { panic("ipfs_ffi: panic de teste numa goroutine") }()
		return nil
	})}
	// Como uma função do kubo com chan<- (gerada com goTry): item 1 e o
	// panic vira o erro da stream.
	table[25] = entry{key: "ipfs_ffi/test.PanicInChanFunc", stream: true, fn: noArgs(func(q *req, _ *writer) error {
		ch, errc := make(chan int), make(chan error, 1)
		goTry(errc, func() error { ch <- 1; panic("ipfs_ffi: panic de teste numa função com canal") })
		v := <-ch
		q.item(func(w *writer) { w.i64(int64(v)) })
		return <-errc
	})}
	// O codificador do sink entra em panic no 2º item de 3: o sink recebe o
	// item 1 e o erro; a chamada responde vazio.
	table[26] = entry{key: "ipfs_ffi/test.PanicInSink", fn: func(q *req, r *reader, _ *writer) error {
		sid := r.u32()
		if err := r.done(); err != nil {
			return err
		}
		ch, done := chanSink(q, sid, func(w *writer, i int) {
			if i == 2 {
				panic("ipfs_ffi: panic de teste no sink")
			}
			w.i64(int64(i))
		})
		for i := 1; i <= 3; i++ {
			ch <- i
		}
		done()
		return nil
	}}

	// os nomes dos perfis em ordem
	table[40] = entry{key: "config.Profiles", fn: noArgs(func(_ *req, w *writer) error {
		names := make([]string, 0, len(config.Profiles))
		for name := range config.Profiles {
			names = append(names, name)
		}
		sort.Strings(names)
		w.i32(int32(len(names)))
		for _, n := range names {
			w.str(n)
		}
		return nil
	})}
	// nome, JSON do config → JSON do config transformado
	table[41] = entry{key: "config.Profile.Transform", fn: func(_ *req, r *reader, w *writer) error {
		name, js := r.str(), r.str()
		if err := r.done(); err != nil {
			return err
		}
		p, ok := config.Profiles[name]
		if !ok {
			return fmt.Errorf("perfil de config desconhecido: %q", name)
		}
		var c config.Config
		if err := json.Unmarshal([]byte(js), &c); err != nil {
			return err
		}
		if err := p.Transform(&c); err != nil {
			return err
		}
		b, err := json.Marshal(c)
		if err != nil {
			return err
		}
		w.str(string(b))
		return nil
	}}
}
