// Runtime da ponte gerada (gen/ → zz_generated.go): um só export, IpfsCall,
// despacha pelo nome do símbolo Go com os argumentos em JSON. Objetos com
// estado atravessam como handle (runtime/cgo.Handle); valores (CID, path,
// peer, multiaddr, tempo, config) como string/JSON.
package main

/*
#include <stdint.h>
#include <stdlib.h>
#include "bridge.h"
*/
import "C"

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"reflect"
	"runtime/cgo"
	"sort"
	"sync"
	"time"
	"unsafe"

	"github.com/ipfs/boxo/ipns"
	"github.com/ipfs/boxo/path"
	"github.com/ipfs/go-cid"
	"github.com/ipfs/kubo/config"
	"github.com/libp2p/go-libp2p/core/peer"
	ma "github.com/multiformats/go-multiaddr"
)

// entry é uma função exposta: call devolve um valor (síncrona ou assíncrona,
// quem decide é o Dart); stream emite itens até terminar (canais do Go).
type entry struct {
	call   func(a []json.RawMessage) (any, error)
	stream func(a []json.RawMessage, emit func(any)) error
}

var reg = map[string]entry{}

// Modos de IpfsCall e tipos de evento do callback (espelhados em runtime.dart).
const (
	modeSync   = 0
	modeAsync  = 1
	modeStream = 2

	evValue = 0
	evItem  = 1
	evEnd   = 2
	evError = 3
)

// IpfsCall chama a função [method] com [args] (array JSON).
//   - modo síncrono: devolve {"v": resultado} ou {"e": "erro"} (liberar com GoFree);
//   - assíncrono/stream: devolve NULL e responde por [cb] numa goroutine, com
//     [id]: evValue/evError uma vez, ou evItem... e evEnd/evError. O texto de
//     cada evento é liberado pelo Dart com GoFree.
//
//export IpfsCall
func IpfsCall(method, args *C.char, mode C.int, cb C.ipfs_cb, id C.int64_t) *C.char {
	name, raw := C.GoString(method), C.GoString(args)
	if mode == modeSync {
		v, err := invoke(name, raw)
		if err != nil {
			return C.CString(mustJSON(map[string]any{"e": err.Error()}))
		}
		return C.CString(mustJSON(map[string]any{"v": v}))
	}
	go func() {
		send := func(kind int, s string) { C.ipfs_invoke(cb, id, C.int32_t(kind), C.CString(s)) }
		// o invoke já tem guard; este pega um panic no envio (mustJSON)
		err := try(func() error {
			if mode == modeStream {
				err := invokeStream(name, raw, func(v any) { send(evItem, mustJSON(v)) })
				if err == nil {
					send(evEnd, "null")
				}
				return err
			}
			v, err := invoke(name, raw)
			if err == nil {
				send(evValue, mustJSON(v))
			}
			return err
		})
		if err != nil {
			send(evError, err.Error())
		}
	}()
	return nil
}

func lookup(name, raw string, stream bool) (entry, []json.RawMessage, error) {
	e, ok := reg[name]
	if !ok || (stream && e.stream == nil) || (!stream && e.call == nil) {
		return e, nil, fmt.Errorf("ipfs_ffi: função desconhecida %q", name)
	}
	var a []json.RawMessage
	err := json.Unmarshal([]byte(raw), &a)
	return e, a, err
}

func invoke(name, raw string) (v any, err error) {
	defer guard(&err)
	e, a, err := lookup(name, raw, false)
	if err != nil {
		return nil, err
	}
	v, err = e.call(a)
	if err == nil {
		_, err = json.Marshal(v) // erro de codificação vira erro da chamada
	}
	return v, err
}

func invokeStream(name, raw string, emit func(any)) (err error) {
	defer guard(&err)
	e, a, err := lookup(name, raw, true)
	if err != nil {
		return err
	}
	return e.stream(a, emit)
}

// guard transforma um panic da chamada em erro, em vez de derrubar o
// processo Dart. Toda goroutine do ipfs_ffi passa por ele (try/goTry);
// ponytail: panic em goroutine interna do kubo continua fatal (o Go não tem
// tratador global; só um processo separado isolaria).
func guard(err *error) {
	if r := recover(); r != nil {
		*err = fmt.Errorf("panic: %v", r)
	}
}

// try roda f; um panic vira o erro devolvido.
func try(f func() error) (err error) {
	defer guard(&err)
	return f()
}

// goTry roda f numa goroutine e entrega em errc o erro, ou o panic como erro
// (as funções do kubo que recebem um chan<-, como Pin.Ls).
func goTry(errc chan<- error, f func() error) {
	go func() { errc <- try(f) }()
}

func mustJSON(v any) string {
	b, err := json.Marshal(v)
	if err != nil {
		b, _ = json.Marshal(map[string]any{"e": err.Error()})
	}
	return string(b)
}

// Handles: o valor fica no Go; o Dart guarda o número e o solta com
// IpfsHandleFree (NativeFinalizer). nil vira null.
func henc(v any) any {
	if v == nil {
		return nil
	}
	switch rv := reflect.ValueOf(v); rv.Kind() {
	case reflect.Pointer, reflect.Interface, reflect.Map, reflect.Slice, reflect.Func, reflect.Chan:
		if rv.IsNil() {
			return nil
		}
	}
	return int64(cgo.NewHandle(v))
}

func hdec[T any](raw json.RawMessage) (T, error) {
	var h int64
	if err := json.Unmarshal(raw, &h); err != nil {
		var zero T
		return zero, err
	}
	return hget[T](h)
}

// hget: o valor do handle [h] (0 = nil), para o JSON e os exports diretos.
func hget[T any](h int64) (T, error) {
	var zero T
	if h == 0 {
		return zero, nil
	}
	v, ok := cgo.Handle(h).Value().(T)
	if !ok {
		return zero, fmt.Errorf("ipfs_ffi: handle %d não é %v", h, reflect.TypeFor[T]())
	}
	return v, nil
}

// hint: handle novo de [v] como inteiro (0 = nil), para os exports diretos.
func hint(v any) int64 {
	h, _ := henc(v).(int64)
	return h
}

// guardC: o guard dos exports diretos (gen: funções síncronas só com número,
// bool, string e handle): panic vira a mensagem de erro devolvida.
func guardC(cerr **C.char) {
	if r := recover(); r != nil {
		*cerr = C.CString(fmt.Sprintf("panic: %v", r))
	}
}

//export IpfsHandleFree
func IpfsHandleFree(p unsafe.Pointer) {
	defer func() { _ = recover() }() // handle já solto: nada a fazer
	cgo.Handle(uintptr(p)).Delete()
}

// jdec decodifica tipos que o encoding/json já entende (básicos, mapas e
// slices deles).
func jdec[T any](raw json.RawMessage) (T, error) {
	var v T
	err := json.Unmarshal(raw, &v)
	return v, err
}

// []byte não vai no JSON: vai {"$p": endereço, "$n": tamanho} de um buffer
// C. O do Dart é do Dart (o Go copia); o devolvido pelo Go é solto pelo Dart.
// Endereços cruzam como int64 (o int do Dart): no arm64 do Android o alocador
// marca o byte mais alto do ponteiro (0xB4...), que vira um número negativo.
type cbuf struct {
	P int64 `json:"$p"`
	N int   `json:"$n"`
}

func decBytes(raw json.RawMessage) ([]byte, error) {
	var b *cbuf
	if err := json.Unmarshal(raw, &b); err != nil || b == nil {
		return nil, err
	}
	addr := uintptr(b.P)
	p := *(*unsafe.Pointer)(unsafe.Pointer(&addr)) // endereço de memória C, fora do GC
	return bytes.Clone(unsafe.Slice((*byte)(p), b.N)), nil
}

func encBytes(b []byte) any {
	if b == nil {
		return nil
	}
	return cbuf{P: int64(uintptr(C.CBytes(b))), N: len(b)}
}

// chanSink: canal que o chamador passa numa opção (options.Unixfs.Events). O
// Dart manda {"$s": id, "$cb": listener}; cada item do tipo T vai ao
// StreamSink dele. O kubo não fecha esse canal (quem fecha é o `ipfs add`):
// done o fecha quando a chamada volta e espera o último item sair, para o
// Dart receber tudo antes do resultado.
func chanSink[T any](raw json.RawMessage, enc func(T) any) (chan any, func(), error) {
	var s struct {
		S  int64 `json:"$s"`
		CB int64 `json:"$cb"` // int64 como o $p do cbuf
	}
	if err := json.Unmarshal(raw, &s); err != nil {
		return nil, nil, err
	}
	cbAddr := uintptr(s.CB)
	cb := *(*C.ipfs_cb)(unsafe.Pointer(&cbAddr))
	send := func(kind int, text string) { C.ipfs_invoke(cb, C.int64_t(s.S), C.int32_t(kind), C.CString(text)) }
	ch := make(chan any, 8) // como o `ipfs add` (adderOutChanSize)
	fin := make(chan struct{})
	go func() {
		defer close(fin)
		// um panic ao codificar encerra o sink com erro; o canal segue sendo
		// esvaziado para o kubo não travar escrevendo nele
		var perr error
		for v := range ch {
			if t, ok := v.(T); ok && perr == nil {
				perr = try(func() error { send(evItem, mustJSON(enc(t))); return nil })
			}
		}
		if perr != nil {
			send(evError, perr.Error())
		} else {
			send(evEnd, "null")
		}
	}()
	var once sync.Once
	return ch, func() { once.Do(func() { close(ch); <-fin }) }, nil
}

// error dentro de um valor (PinStatus.Err(), gc.Result.Error): a mensagem.
func encErr(err error) any {
	if err == nil {
		return nil
	}
	return err.Error()
}

func decErr(raw json.RawMessage) (error, error) {
	s, err := jdec[*string](raw)
	if err != nil || s == nil {
		return nil, err
	}
	return errors.New(*s), nil
}

// decReader aceita bytes ou um handle de io.Reader.
func decReader(raw json.RawMessage) (io.Reader, error) {
	if len(raw) > 0 && raw[0] == '{' {
		b, err := decBytes(raw)
		return bytes.NewReader(b), err
	}
	return hdec[io.Reader](raw)
}

// Tipos-valor (tabela valueTypes em gen/model.go).

func decCid(raw json.RawMessage) (cid.Cid, error) {
	s, err := jdec[string](raw)
	if err != nil || s == "" {
		return cid.Undef, err
	}
	return cid.Decode(s)
}

func encCid(c cid.Cid) any {
	if !c.Defined() {
		return nil
	}
	return c.String()
}

func decPath(raw json.RawMessage) (path.Path, error) {
	s, err := jdec[string](raw)
	if err != nil || s == "" {
		return nil, err
	}
	return path.NewPath(s)
}

func encPath(p path.Path) any {
	if p == nil {
		return nil
	}
	return p.String()
}

func decImmutablePath(raw json.RawMessage) (path.ImmutablePath, error) {
	p, err := decPath(raw)
	if err != nil || p == nil {
		return path.ImmutablePath{}, err
	}
	return path.NewImmutablePath(p)
}

func encImmutablePath(p path.ImmutablePath) any {
	if !p.RootCid().Defined() { // zero value
		return nil
	}
	return p.String()
}

func decPeerID(raw json.RawMessage) (peer.ID, error) {
	s, err := jdec[string](raw)
	if err != nil || s == "" {
		return "", err
	}
	return peer.Decode(s)
}

func encPeerID(id peer.ID) any {
	if id == "" {
		return nil
	}
	return id.String()
}

func decMultiaddr(raw json.RawMessage) (ma.Multiaddr, error) {
	s, err := jdec[string](raw)
	if err != nil || s == "" {
		return nil, err
	}
	return ma.NewMultiaddr(s)
}

func encMultiaddr(m ma.Multiaddr) any {
	if len(m) == 0 {
		return nil
	}
	return m.String()
}

func decTime(raw json.RawMessage) (time.Time, error) {
	s, err := jdec[string](raw)
	if err != nil || s == "" {
		return time.Time{}, err
	}
	return time.Parse(time.RFC3339Nano, s)
}

func encTime(t time.Time) any {
	if t.IsZero() {
		return nil
	}
	return t.UTC().Format(time.RFC3339Nano)
}

func decIpnsName(raw json.RawMessage) (ipns.Name, error) {
	s, err := jdec[string](raw)
	if err != nil || s == "" {
		return ipns.Name{}, err
	}
	return ipns.NameFromString(s)
}

func encIpnsName(n ipns.Name) any {
	if n == (ipns.Name{}) {
		return nil
	}
	return n.String()
}

// Mapa com chave tipo-valor (map[peer.ID]...): a chave do JSON é a string do
// conversor.
func quoteRaw(s string) json.RawMessage {
	b, _ := json.Marshal(s)
	return b
}

func keyStr(v any) string {
	s, _ := v.(string)
	return s
}

// config.Config atravessa no JSON do próprio kubo (o do arquivo config).
func decConfig(raw json.RawMessage) (config.Config, error) { return jdec[config.Config](raw) }

func encConfig(c config.Config) any {
	b, err := json.Marshal(c)
	if err != nil {
		panic(err)
	}
	return json.RawMessage(b)
}

// Escrito à mão: context (o Dart espelha o pacote em lib/context.dart) e os
// perfis de config (config.Profiles é um mapa de funções; ver API.md).
func init() {
	reg["context.Background"] = entry{call: func([]json.RawMessage) (any, error) {
		return henc(context.Background()), nil
	}}
	withCancel := func(ctx context.Context, cancel context.CancelFunc) (any, error) {
		return []any{henc(ctx), henc(cancel)}, nil
	}
	reg["context.WithCancel"] = entry{call: func(a []json.RawMessage) (any, error) {
		parent, err := hdec[context.Context](a[0])
		if err != nil {
			return nil, err
		}
		return withCancel(context.WithCancel(parent))
	}}
	reg["context.WithTimeout"] = entry{call: func(a []json.RawMessage) (any, error) {
		parent, err := hdec[context.Context](a[0])
		if err != nil {
			return nil, err
		}
		d, err := jdec[time.Duration](a[1])
		if err != nil {
			return nil, err
		}
		return withCancel(context.WithTimeout(parent, d))
	}}
	reg["context.WithDeadline"] = entry{call: func(a []json.RawMessage) (any, error) {
		parent, err := hdec[context.Context](a[0])
		if err != nil {
			return nil, err
		}
		t, err := decTime(a[1])
		if err != nil {
			return nil, err
		}
		return withCancel(context.WithDeadline(parent, t))
	}}
	reg["context.CancelFunc"] = entry{call: func(a []json.RawMessage) (any, error) {
		cancel, err := hdec[context.CancelFunc](a[0])
		if err == nil {
			cancel()
		}
		return nil, err
	}}
	reg["context.Context.Err"] = entry{call: func(a []json.RawMessage) (any, error) {
		ctx, err := hdec[context.Context](a[0])
		if err != nil || ctx.Err() == nil {
			return nil, err
		}
		return ctx.Err().Error(), nil
	}}

	// Gancho de teste (test/crash_child.dart): panic numa goroutine fora de
	// qualquer chamada, como um bug interno do kubo; o guard não o alcança.
	reg["ipfs_ffi/test.PanicInGoroutine"] = entry{call: func([]json.RawMessage) (any, error) {
		go func() { panic("ipfs_ffi: panic de teste numa goroutine") }()
		return nil, nil
	}}
	// Ganchos de teste das goroutines do ipfs_ffi: o panic vira erro.
	// PanicInChanFunc: como uma função do kubo com chan<- (gerado com goTry).
	reg["ipfs_ffi/test.PanicInChanFunc"] = entry{stream: func(_ []json.RawMessage, emit func(any)) error {
		ch, errc := make(chan int), make(chan error, 1)
		goTry(errc, func() error { ch <- 1; panic("ipfs_ffi: panic de teste numa função com canal") })
		emit(<-ch)
		return <-errc
	}}
	// PanicInSink: o encoder do chanSink entra em panic no 2º item de 3.
	reg["ipfs_ffi/test.PanicInSink"] = entry{call: func(a []json.RawMessage) (any, error) {
		ch, done, err := chanSink(a[0], func(i int) any {
			if i == 2 {
				panic("ipfs_ffi: panic de teste no sink")
			}
			return i
		})
		if err != nil {
			return nil, err
		}
		for i := 1; i <= 3; i++ {
			ch <- i
		}
		done()
		return nil, nil
	}}

	reg["config.Profiles"] = entry{call: func([]json.RawMessage) (any, error) {
		names := make([]any, 0, len(config.Profiles))
		for name := range config.Profiles {
			names = append(names, name)
		}
		sort.Slice(names, func(i, j int) bool { return names[i].(string) < names[j].(string) })
		return names, nil
	}}
	reg["config.Profile.Transform"] = entry{call: func(a []json.RawMessage) (any, error) {
		name, err := jdec[string](a[0])
		if err != nil {
			return nil, err
		}
		p, ok := config.Profiles[name]
		if !ok {
			return nil, fmt.Errorf("perfil de config desconhecido: %q", name)
		}
		c, err := decConfig(a[1])
		if err != nil {
			return nil, err
		}
		if err := p.Transform(&c); err != nil {
			return nil, err
		}
		return encConfig(c), nil
	}}
}
