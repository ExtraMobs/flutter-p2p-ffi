package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"math"
	"strings"
	"testing"
	"time"

	"github.com/ipfs/boxo/path"
	"github.com/ipfs/go-cid"
	format "github.com/ipfs/go-ipld-format"
	carindex "github.com/ipld/go-car/v2/index"
	"github.com/libp2p/go-libp2p/core/peer"
	ma "github.com/multiformats/go-multiaddr"
)

func TestWireRoundTrip(t *testing.T) {
	c, _ := cid.Decode("bafkqaaa")
	p := path.FromCid(c)
	id, _ := peer.Decode("12D3KooWD3eckifWpRn9wQpMG9R9hX3sD158z7EqHWmweQAJU5SA")
	m, _ := ma.NewMultiaddr("/ip4/127.0.0.1/tcp/4001")
	now := time.Unix(1700000000, 123456789)

	w := &writer{}
	w.u8(7)
	w.bool(true)
	encInt(w, int64(math.MinInt64))
	encInt(w, uint32(math.MaxUint32))
	encInt(w, uint64(math.MaxUint64)) // i64 com os mesmos bits: o Dart lê -1
	encFloat(w, 1.5)
	encStr(w, "olá")
	encBytes(w, nil)
	encBytes(w, []byte{})
	encBytes(w, []byte{1, 2, 3})
	encErr(w, nil)
	encErr(w, errors.New("falhou"))
	encCid(w, c)
	encCid(w, cid.Undef)
	encPath(w, p)
	encPath(w, nil)
	encPeerID(w, id)
	encMultiaddr(w, m)
	encTime(w, now)
	encTime(w, time.Time{})
	w.u64(0xfeedface)

	r := &reader{b: w.b}
	check := func(name string, ok bool) {
		t.Helper()
		if !ok {
			t.Errorf("%s: diferente", name)
		}
	}
	check("u8", r.u8() == 7)
	check("bool", r.bool())
	i, _ := decInt[int64](r)
	check("int64", i == math.MinInt64)
	u, _ := decInt[uint32](r)
	check("uint32", u == math.MaxUint32)
	u64, _ := decInt[uint64](r)
	check("uint64 máximo", u64 == math.MaxUint64)
	f, _ := decFloat[float64](r)
	check("f64", f == 1.5)
	s, _ := decStr[string](r)
	check("str", s == "olá")
	b, _ := decBytes(r)
	check("bytes nil", b == nil)
	b, _ = decBytes(r)
	check("bytes vazio", b != nil && len(b) == 0)
	b, _ = decBytes(r)
	check("bytes", bytes.Equal(b, []byte{1, 2, 3}))
	e, _ := decErr(r)
	check("err nil", e == nil)
	e, _ = decErr(r)
	check("err", e != nil && e.Error() == "falhou")
	gc, err := decCid(r)
	check("cid", err == nil && gc.Equals(c))
	gc, _ = decCid(r)
	check("cid indefinido", !gc.Defined())
	gp, err := decPath(r)
	check("path", err == nil && gp.String() == p.String())
	gp, _ = decPath(r)
	check("path nil", gp == nil)
	gid, err := decPeerID(r)
	check("peer", err == nil && gid == id)
	gm, err := decMultiaddr(r)
	check("multiaddr", err == nil && gm.Equal(m))
	gt, _ := decTime(r)
	check("time", gt.Equal(now))
	gt, _ = decTime(r)
	check("time zero", gt.IsZero())
	check("u64", r.u64() == 0xfeedface)
	if err := r.done(); err != nil {
		t.Fatal(err)
	}
}

func TestReaderShort(t *testing.T) {
	r := &reader{b: []byte{1, 2}}
	if r.u32() != 0 || r.i64() != 0 || r.str() != "" || r.bytes() != nil {
		t.Fatal("leitura curta devolveu valor")
	}
	if err := r.done(); !errors.Is(err, errShort) {
		t.Fatalf("done = %v, esperava errShort", err)
	}
	// n maior que o resto: curto, sem alocar
	w := &writer{}
	w.i32(1 << 30)
	r = &reader{b: w.b}
	if n := r.count(); n != 0 || r.done() == nil {
		t.Fatal("count aceitou n além do pedido")
	}
	// sobra de bytes também é erro
	r = &reader{b: []byte{1, 2}}
	r.u8()
	if err := r.done(); err == nil || !strings.Contains(err.Error(), "sobrando") {
		t.Fatalf("done = %v, esperava sobra", err)
	}
}

func TestHandles(t *testing.T) {
	var nilPtr *bytes.Buffer
	if hput(nil) != 0 || hput(nilPtr) != 0 {
		t.Fatal("nil virou handle")
	}
	buf := &bytes.Buffer{}
	h := hput(buf)
	if got, err := hget[*bytes.Buffer](h); err != nil || got != buf {
		t.Fatal(got, err)
	}
	if _, err := hget[*strings.Builder](h); err == nil {
		t.Fatal("tipo errado aceito")
	}
	hfree(h)
	if _, err := hget[*bytes.Buffer](h); err == nil {
		t.Fatal("handle solto ainda vale")
	}
}

// Interface de E/S em parâmetro (decIO): bytes valem onde o bytes.Reader
// serve (io.ReaderAt), não onde não serve (io.WriterAt); handle vale pelo
// tipo do objeto. io.Writer (decWriter): handle 0 é o io.Discard.
func TestDecIO(t *testing.T) {
	w := &writer{}
	w.u8(0)
	w.bytes([]byte("abc"))
	ra, err := decIO[io.ReaderAt](&reader{b: w.b})
	if err != nil {
		t.Fatal(err)
	}
	p := make([]byte, 2)
	if n, _ := ra.ReadAt(p, 1); n != 2 || string(p) != "bc" {
		t.Fatalf("ReadAt: %q", p)
	}
	if _, err := decIO[io.WriterAt](&reader{b: w.b}); err == nil {
		t.Fatal("bytes aceitos como io.WriterAt")
	}

	buf := &bytes.Buffer{}
	h := hput(buf)
	defer hfree(h)
	w = &writer{}
	w.u8(1)
	w.i64(h)
	if got, err := decIO[io.ReadWriter](&reader{b: w.b}); err != nil || got != buf {
		t.Fatal(got, err)
	}
	w = &writer{}
	w.i64(0)
	if got, err := decWriter(&reader{b: w.b}); err != nil || got != io.Discard {
		t.Fatal(got, err)
	}
}

// O código de sentinela do evento `erro` acha o sentinela embrulhado, como o
// errors.Is.
func TestErrData(t *testing.T) {
	for _, c := range []struct {
		err  error
		code byte
	}{
		{io.EOF, errEOF},
		{fmt.Errorf("lendo: %w", io.EOF), errEOF},
		{io.ErrUnexpectedEOF, errUnexpectedEOF},
		{context.Canceled, errCanceled},
		{fmt.Errorf("x: %w", context.DeadlineExceeded), errDeadline},
		{format.ErrNotFound{}, errNotFound},
		{carindex.ErrNotFound, errNotFound},
		{errors.New("outro"), 0},
	} {
		d := errData(c.err)
		if d[0] != c.code || string(d[1:]) != c.err.Error() {
			t.Errorf("%v: código %d, mensagem %q", c.err, d[0], d[1:])
		}
	}
}

// O mesmo objeto por referência dá o mesmo handle, e ele só sai da tabela
// quando todos os objetos Dart o soltam.
func TestHandleDedup(t *testing.T) {
	buf := &bytes.Buffer{}
	a, b := hput(buf), hput(io.Writer(buf))
	if a != b {
		t.Fatalf("o mesmo ponteiro deu handles %d e %d", a, b)
	}
	if c := hput(&bytes.Buffer{}); c == a {
		t.Fatal("objetos diferentes com o mesmo handle")
	}
	hfree(a)
	if got, err := hget[*bytes.Buffer](a); err != nil || got != buf {
		t.Fatal("o handle saiu com um objeto Dart ainda segurando:", err)
	}
	hfree(b)
	if _, err := hget[*bytes.Buffer](a); err == nil {
		t.Fatal("o handle ficou depois do último hfree")
	}
}
