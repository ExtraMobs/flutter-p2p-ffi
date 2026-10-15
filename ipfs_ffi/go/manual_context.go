// O pacote context para o lib/context.dart, escrito à mão (WIRE.md, ids
// 16–21): toda operação com prazo cria um contexto e o cancela. Os dois
// handles de um WithX saem em ordem (ctx, cancel).
package main

import (
	"context"
	"time"
)

// withCtx: context.WithX sobre o pai (i64), com os handles do contexto e do
// cancel na resposta; [hasArg]: lê o prazo (i64) depois do pai. Pai nil é
// o panic do Go, que vira o erro da chamada.
func withCtx(with func(p context.Context, arg int64) (context.Context, context.CancelFunc), hasArg bool) func(*req, *reader, *writer) error {
	return func(_ *req, r *reader, w *writer) error {
		p, err := decH[context.Context](r)
		if err != nil {
			return err
		}
		var arg int64
		if hasArg {
			arg = r.i64()
		}
		if err := r.done(); err != nil {
			return err
		}
		ctx, cancel := with(p, arg)
		w.i64(hput(ctx))
		w.i64(hput(cancel))
		return nil
	}
}

func init() {
	table[16] = entry{key: "context.Background", fn: func(_ *req, r *reader, w *writer) error {
		if err := r.done(); err != nil {
			return err
		}
		w.i64(hput(context.Background()))
		return nil
	}}
	table[17] = entry{key: "context.WithCancel", fn: withCtx(func(p context.Context, _ int64) (context.Context, context.CancelFunc) {
		return context.WithCancel(p)
	}, false)}
	// o prazo em nanossegundos (time.Duration)
	table[18] = entry{key: "context.WithTimeout", fn: withCtx(func(p context.Context, ns int64) (context.Context, context.CancelFunc) {
		return context.WithTimeout(p, time.Duration(ns))
	}, true)}
	// o prazo em nanossegundos desde a época Unix
	table[19] = entry{key: "context.WithDeadline", fn: withCtx(func(p context.Context, ns int64) (context.Context, context.CancelFunc) {
		return context.WithDeadline(p, time.Unix(0, ns))
	}, true)}
	table[20] = entry{key: "context.CancelFunc", fn: func(_ *req, r *reader, _ *writer) error {
		cancel, err := decH[context.CancelFunc](r)
		if err != nil {
			return err
		}
		if err := r.done(); err != nil {
			return err
		}
		cancel()
		return nil
	}}
	// ctx.Err() como kError: ausente enquanto não cancelado
	table[21] = entry{key: "context.Context.Err", fn: func(_ *req, r *reader, w *writer) error {
		ctx, err := decH[context.Context](r)
		if err != nil {
			return err
		}
		if err := r.done(); err != nil {
			return err
		}
		encErr(w, ctx.Err())
		return nil
	}}
}
