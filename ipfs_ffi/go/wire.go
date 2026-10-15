// A codificação binária do protocolo do serviço (WIRE.md): leitor e escritor
// little-endian dos valores, a tabela de handles do host, o despacho de uma
// entrada (invoke) e as conversões dos tipos-valor (CID, path, peer ID...).
// O que o gerador emite (zz_generated.go) e as funções escritas à mão
// (manual_*.go) só usam o que está aqui.
package main

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"reflect"
	"sync"
	"time"

	"github.com/ipfs/boxo/ipns"
	"github.com/ipfs/boxo/path"
	"github.com/ipfs/go-cid"
	"github.com/ipfs/kubo/config"
	"github.com/libp2p/go-libp2p/core/peer"
	ma "github.com/multiformats/go-multiaddr"
)

// Modos do pedido e tipos de resposta/evento (WIRE.md, "Mensagens").
const (
	modeSync   = 0
	modeAsync  = 1
	modeStream = 2

	evValue = 0
	evItem  = 1
	evEnd   = 2
	evError = 3
)

// entry: uma função da tabela (as geradas a partir do id 64, as escritas à
// mão abaixo dele). fn lê os argumentos de r e escreve os resultados em w;
// uma stream escreve cada item por q.item (w fica vazio).
type entry struct {
	key    string // a chave do gerador (raiz em gen/roots.txt), para mensagens e testes
	fn     func(q *req, r *reader, w *writer) error
	stream bool
}

// sendFn manda uma resposta/evento ao app (o host.reply, ou um gravador nos testes).
type sendFn func(id uint32, kind byte, data []byte)

// req: a chamada em curso, para os itens de stream e os eventos de sink.
type req struct {
	id   uint32
	send sendFn
}

// item manda um item da stream [q.id] codificado por [enc].
func (q *req) item(enc func(*writer)) {
	w := &writer{}
	enc(w)
	q.send(q.id, evItem, w.b)
}

// invoke roda a entrada [e] sobre [args] e devolve a resposta final (valor,
// fim ou erro); os itens e os eventos de sink saem por [send] antes dela. Um
// panic da chamada vira o erro.
func invoke(e entry, id uint32, args []byte, send sendFn) (byte, []byte) {
	w := &writer{}
	err := try(func() error { return e.fn(&req{id: id, send: send}, &reader{b: args}, w) })
	switch {
	case err != nil:
		return evError, []byte(err.Error())
	case e.stream:
		return evEnd, nil
	}
	return evValue, w.b
}

// guard transforma um panic da chamada em erro, em vez de derrubar o
// host. Toda goroutine do host passa por ele (try/goTry); só um panic em
// goroutine interna do kubo derruba o processo (e o app o relança).
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

// reader lê os argumentos de um pedido. O erro é "pegajoso": uma leitura
// curta devolve zero e marca o erro, que done confere depois do último
// argumento (e também sobra de bytes).
type reader struct {
	b   []byte
	err error
}

var errShort = errors.New("ipfs_host: argumentos curtos")

func (r *reader) take(n int) []byte {
	if r.err != nil {
		return nil
	}
	if n < 0 || len(r.b) < n {
		r.err, r.b = errShort, nil
		return nil
	}
	p := r.b[:n]
	r.b = r.b[n:]
	return p
}

func (r *reader) u8() uint8 {
	if p := r.take(1); p != nil {
		return p[0]
	}
	return 0
}

func (r *reader) u32() uint32 {
	if p := r.take(4); p != nil {
		return binary.LittleEndian.Uint32(p)
	}
	return 0
}

func (r *reader) u64() uint64 {
	if p := r.take(8); p != nil {
		return binary.LittleEndian.Uint64(p)
	}
	return 0
}

func (r *reader) i32() int32   { return int32(r.u32()) }
func (r *reader) i64() int64   { return int64(r.u64()) }
func (r *reader) f64() float64 { return math.Float64frombits(r.u64()) }
func (r *reader) bool() bool   { return r.u8() != 0 }

// present: o byte de presença (WIRE.md: kValue, kDTO, kSnap, kError).
func (r *reader) present() bool { return r.u8() != 0 }

// absent consome o byte de presença só se for 0 (ponteiros: *T nil).
func (r *reader) absent() bool {
	if r.err == nil && len(r.b) > 0 && r.b[0] == 0 {
		r.b = r.b[1:]
		return true
	}
	return false
}

func (r *reader) str() string { return string(r.take(int(r.u32()))) }

// bytes: `i32 n` + bytes, -1 = nil; sempre uma cópia (o pedido mora no anel).
func (r *reader) bytes() []byte {
	n := r.i32()
	if n < 0 {
		return nil
	}
	p := r.take(int(n))
	if r.err != nil {
		return nil
	}
	return append([]byte{}, p...) // não nil, mesmo vazio
}

// count: o `i32 n` de um kSlice/kMap/kOpts (-1 = nil). Todo elemento ocupa
// ao menos um byte, então n maior que o resto é pedido curto (sem alocar n).
func (r *reader) count() int {
	n := int(r.i32())
	if n > len(r.b) && r.err == nil {
		r.err, r.b = errShort, nil
	}
	if r.err != nil {
		return 0
	}
	return n
}

// done: o erro pegajoso, ou bytes que sobraram depois do último argumento.
func (r *reader) done() error {
	if r.err == nil && len(r.b) > 0 {
		r.err = fmt.Errorf("ipfs_host: %d bytes sobrando nos argumentos", len(r.b))
	}
	return r.err
}

// writer escreve os resultados de uma resposta.
type writer struct{ b []byte }

func (w *writer) u8(v uint8)     { w.b = append(w.b, v) }
func (w *writer) u32(v uint32)   { w.b = binary.LittleEndian.AppendUint32(w.b, v) }
func (w *writer) u64(v uint64)   { w.b = binary.LittleEndian.AppendUint64(w.b, v) }
func (w *writer) i32(v int32)    { w.u32(uint32(v)) }
func (w *writer) i64(v int64)    { w.u64(uint64(v)) }
func (w *writer) f64(v float64)  { w.u64(math.Float64bits(v)) }
func (w *writer) str(s string)   { w.u32(uint32(len(s))); w.b = append(w.b, s...) }
func (w *writer) present(p bool) { w.bool(p) }

func (w *writer) bool(v bool) {
	if v {
		w.u8(1)
	} else {
		w.u8(0)
	}
}

func (w *writer) bytes(b []byte) {
	if b == nil {
		w.i32(-1)
		return
	}
	w.i32(int32(len(b)))
	w.b = append(w.b, b...)
}

// Básicos (e nomeados sobre eles: os enums do kubo vão como o básico), na
// forma que o gerador chama: dec*(r) (T, error) e enc*(w, v).

type integer interface {
	~int | ~int8 | ~int16 | ~int32 | ~int64 | ~uint | ~uint8 | ~uint16 | ~uint32 | ~uint64
}

func decInt[T integer](r *reader) (T, error)               { return T(r.i64()), nil }
func encInt[T integer](w *writer, v T)                     { w.i64(int64(v)) }
func decFloat[T ~float32 | ~float64](r *reader) (T, error) { return T(r.f64()), nil }
func encFloat[T ~float32 | ~float64](w *writer, v T)       { w.f64(float64(v)) }
func decBool[T ~bool](r *reader) (T, error)                { return T(r.bool()), nil }
func encBool[T ~bool](w *writer, v T)                      { w.bool(bool(v)) }
func decStr[T ~string](r *reader) (T, error)               { return T(r.str()), nil }
func encStr[T ~string](w *writer, v T)                     { w.str(string(v)) }
func decBytes(r *reader) ([]byte, error)                   { return r.bytes(), nil }
func encBytes(w *writer, b []byte)                         { w.bytes(b) }

// error dentro de um valor (PinStatus.Err(), gc.Result.Error): presença + a mensagem.
func decErr(r *reader) (error, error) {
	if !r.present() {
		return nil, nil
	}
	return errors.New(r.str()), nil
}

func encErr(w *writer, err error) {
	w.present(err != nil)
	if err != nil {
		w.str(err.Error())
	}
}

// Handles: os objetos ficam no host; o app guarda o número (a partir de 1;
// 0 = nil) e os solta com Free.
var handles = struct {
	sync.Mutex
	m    map[int64]any
	next int64
}{m: map[int64]any{}}

// hput guarda [v] e devolve o handle; nil (inclusive ponteiro ou interface
// nil dentro do any) vira 0.
func hput(v any) int64 {
	if v == nil {
		return 0
	}
	switch rv := reflect.ValueOf(v); rv.Kind() {
	case reflect.Pointer, reflect.Interface, reflect.Map, reflect.Slice, reflect.Func, reflect.Chan:
		if rv.IsNil() {
			return 0
		}
	}
	handles.Lock()
	defer handles.Unlock()
	handles.next++
	handles.m[handles.next] = v
	return handles.next
}

// hget: o valor do handle [id] como T (0 = o zero de T).
func hget[T any](id int64) (T, error) {
	var zero T
	if id == 0 {
		return zero, nil
	}
	handles.Lock()
	v, ok := handles.m[id]
	handles.Unlock()
	if !ok {
		return zero, fmt.Errorf("ipfs_host: handle %d não existe (já solto, ou de outro serviço)", id)
	}
	t, ok := v.(T)
	if !ok {
		return zero, fmt.Errorf("ipfs_host: handle %d é %T, não %v", id, v, reflect.TypeFor[T]())
	}
	return t, nil
}

func hfree(id int64) {
	handles.Lock()
	delete(handles.m, id)
	handles.Unlock()
}

func decH[T any](r *reader) (T, error) { return hget[T](r.i64()) }
func encH(w *writer, v any)            { w.i64(hput(v)) }

// decReader: io.Reader em parâmetro: `u8 0` + bytes, ou `u8 1` + handle.
func decReader(r *reader) (io.Reader, error) {
	if r.u8() == 0 {
		return bytes.NewReader(r.bytes()), nil
	}
	return decH[io.Reader](r)
}

// chanSink: canal que o chamador passa numa opção (options.Unixfs.Events),
// ligado ao sink [sid] do app: cada item do tipo T vai como evento `item` com
// o id do sink. O kubo não fecha esse canal (quem fecha é o `ipfs add`): done
// o fecha quando a chamada volta e espera o último item e o `fim`/`erro` do
// sink saírem, antes da resposta da chamada.
func chanSink[T any](q *req, sid uint32, enc func(*writer, T)) (chan any, func()) {
	ch := make(chan any, 8) // como o `ipfs add` (adderOutChanSize)
	fin := make(chan struct{})
	go func() {
		defer close(fin)
		// um panic ao codificar encerra o sink com erro; o canal segue sendo
		// esvaziado para o kubo não travar escrevendo nele
		var perr error
		for v := range ch {
			if t, ok := v.(T); ok && perr == nil {
				perr = try(func() error {
					w := &writer{}
					enc(w, t)
					q.send(sid, evItem, w.b)
					return nil
				})
			}
		}
		if perr != nil {
			q.send(sid, evError, []byte(perr.Error()))
		} else {
			q.send(sid, evEnd, nil)
		}
	}()
	var once sync.Once
	return ch, func() { once.Do(func() { close(ch); <-fin }) }
}

// Tipos-valor (tabela valueTypes em gen/model.go): `u8 presente` + a forma de
// texto do Go (time: Unix em ns; config: o JSON do próprio kubo).

// optStr: a string de um valor presente; ok = false se ausente.
func (r *reader) optStr() (string, bool) {
	if !r.present() {
		return "", false
	}
	return r.str(), true
}

// optStr escreve a presença e, se presente, [s].
func (w *writer) optStr(ok bool, s func() string) {
	w.present(ok)
	if ok {
		w.str(s())
	}
}

func decCid(r *reader) (cid.Cid, error) {
	if s, ok := r.optStr(); ok {
		return cid.Decode(s)
	}
	return cid.Undef, nil
}

func encCid(w *writer, c cid.Cid) { w.optStr(c.Defined(), c.String) }

func decPath(r *reader) (path.Path, error) {
	if s, ok := r.optStr(); ok {
		return path.NewPath(s)
	}
	return nil, nil
}

func encPath(w *writer, p path.Path) {
	w.optStr(p != nil, func() string { return p.String() })
}

func decImmutablePath(r *reader) (path.ImmutablePath, error) {
	p, err := decPath(r)
	if err != nil || p == nil {
		return path.ImmutablePath{}, err
	}
	return path.NewImmutablePath(p)
}

func encImmutablePath(w *writer, p path.ImmutablePath) {
	w.optStr(p.RootCid().Defined(), p.String) // zero value: ausente
}

func decPeerID(r *reader) (peer.ID, error) {
	if s, ok := r.optStr(); ok {
		return parsePeerID(s)
	}
	return "", nil
}

// parsePeerID: chave de mapa tipo-valor (map[peer.ID]...), sem presença; o
// gerador chama parse<Nome> para o dec<Nome> da tabela.
func parsePeerID(s string) (peer.ID, error) { return peer.Decode(s) }

func encPeerID(w *writer, id peer.ID) { w.optStr(id != "", id.String) }

func decMultiaddr(r *reader) (ma.Multiaddr, error) {
	if s, ok := r.optStr(); ok {
		return ma.NewMultiaddr(s)
	}
	return nil, nil
}

func encMultiaddr(w *writer, m ma.Multiaddr) { w.optStr(len(m) > 0, m.String) }

func decTime(r *reader) (time.Time, error) {
	if !r.present() {
		return time.Time{}, nil
	}
	return time.Unix(0, r.i64()), nil
}

func encTime(w *writer, t time.Time) {
	w.present(!t.IsZero())
	if !t.IsZero() {
		w.i64(t.UnixNano())
	}
}

func decIpnsName(r *reader) (ipns.Name, error) {
	if s, ok := r.optStr(); ok {
		return ipns.NameFromString(s)
	}
	return ipns.Name{}, nil
}

func encIpnsName(w *writer, n ipns.Name) { w.optStr(n != (ipns.Name{}), n.String) }

// config.Config atravessa no JSON do próprio kubo (o do arquivo config).
func decConfig(r *reader) (config.Config, error) {
	var c config.Config
	s, ok := r.optStr()
	if !ok {
		return c, nil
	}
	err := json.Unmarshal([]byte(s), &c)
	return c, err
}

func encConfig(w *writer, c config.Config) {
	b, err := json.Marshal(c)
	if err != nil {
		panic(err) // vira o erro da chamada (guard)
	}
	w.u8(1)
	w.str(string(b))
}
