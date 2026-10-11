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
	"fmt"
	"io"
	"reflect"
	"runtime/cgo"
	"sort"
	"time"
	"unsafe"

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
		if mode == modeStream {
			err := invokeStream(name, raw, func(v any) { send(evItem, mustJSON(v)) })
			if err != nil {
				send(evError, err.Error())
			} else {
				send(evEnd, "null")
			}
			return
		}
		v, err := invoke(name, raw)
		if err != nil {
			send(evError, err.Error())
			return
		}
		send(evValue, mustJSON(v))
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
// processo Dart. ponytail: panic em goroutine interna do kubo continua fatal.
func guard(err *error) {
	if r := recover(); r != nil {
		*err = fmt.Errorf("panic: %v", r)
	}
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
	var zero T
	var h int64
	if err := json.Unmarshal(raw, &h); err != nil || h == 0 {
		return zero, err
	}
	v, ok := cgo.Handle(h).Value().(T)
	if !ok {
		return zero, fmt.Errorf("ipfs_ffi: handle %d não é %v", h, reflect.TypeFor[T]())
	}
	return v, nil
}

//export IpfsHandleFree
func IpfsHandleFree(p unsafe.Pointer) {
	defer func() { _ = recover() }() // handle já solto: nada a fazer
	cgo.Handle(uintptr(p)).Delete()
}

// jdec decodifica tipos que o encoding/json já entende (básicos, []byte em
// base64, mapas e slices deles).
func jdec[T any](raw json.RawMessage) (T, error) {
	var v T
	err := json.Unmarshal(raw, &v)
	return v, err
}

// decReader aceita bytes (string base64) ou um handle de io.Reader.
func decReader(raw json.RawMessage) (io.Reader, error) {
	if len(raw) > 0 && raw[0] == '"' {
		b, err := jdec[[]byte](raw)
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
