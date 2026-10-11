// O pacote context para o lib/context.dart, escrito à mão e por exports
// diretos (sem JSON): toda operação com prazo cria um contexto e o cancela.
// Os dois handles de um WithX saem por out e out2; o erro (ou panic) é o
// retorno, NULL = ok, como nos exports gerados.
package main

/*
#include <stdint.h>
*/
import "C"

import (
	"context"
	"time"
)

//export IpfsCtxBackground
func IpfsCtxBackground(out *C.int64_t) (cerr *C.char) {
	defer guardC(&cerr)
	*out = C.int64_t(hint(context.Background()))
	return nil
}

// withCtx: context.WithX sobre o pai [parent], com os handles em out e out2.
func withCtx(parent C.int64_t, out, out2 *C.int64_t, with func(context.Context) (context.Context, context.CancelFunc)) *C.char {
	p, err := hget[context.Context](int64(parent))
	if err != nil {
		return C.CString(err.Error())
	}
	ctx, cancel := with(p)
	*out, *out2 = C.int64_t(hint(ctx)), C.int64_t(hint(cancel))
	return nil
}

//export IpfsCtxWithCancel
func IpfsCtxWithCancel(parent C.int64_t, out, out2 *C.int64_t) (cerr *C.char) {
	defer guardC(&cerr)
	return withCtx(parent, out, out2, context.WithCancel)
}

// IpfsCtxWithTimeout: [timeout] em nanossegundos (time.Duration).
//
//export IpfsCtxWithTimeout
func IpfsCtxWithTimeout(parent, timeout C.int64_t, out, out2 *C.int64_t) (cerr *C.char) {
	defer guardC(&cerr)
	return withCtx(parent, out, out2, func(p context.Context) (context.Context, context.CancelFunc) {
		return context.WithTimeout(p, time.Duration(timeout))
	})
}

// IpfsCtxWithDeadline: [deadline] em nanossegundos desde a época Unix.
//
//export IpfsCtxWithDeadline
func IpfsCtxWithDeadline(parent, deadline C.int64_t, out, out2 *C.int64_t) (cerr *C.char) {
	defer guardC(&cerr)
	return withCtx(parent, out, out2, func(p context.Context) (context.Context, context.CancelFunc) {
		return context.WithDeadline(p, time.Unix(0, int64(deadline)))
	})
}

//export IpfsCtxCancel
func IpfsCtxCancel(h C.int64_t) (cerr *C.char) {
	defer guardC(&cerr)
	cancel, err := hget[context.CancelFunc](int64(h))
	if err != nil {
		return C.CString(err.Error())
	}
	cancel()
	return nil
}

// IpfsCtxErr: a mensagem de ctx.Err() em out, NULL enquanto não cancelado.
//
//export IpfsCtxErr
func IpfsCtxErr(h C.int64_t, out **C.char) (cerr *C.char) {
	defer guardC(&cerr)
	ctx, err := hget[context.Context](int64(h))
	if err != nil {
		return C.CString(err.Error())
	}
	*out = nil
	if e := ctx.Err(); e != nil {
		*out = C.CString(e.Error())
	}
	return nil
}
