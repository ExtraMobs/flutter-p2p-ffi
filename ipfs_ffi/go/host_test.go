package main

import (
	"strings"
	"sync"
	"testing"

	"github.com/ExtraMobs/transpiled_ipfs/ipfs_ffi/go/shmring"
)

// ev: um evento mandado durante uma chamada (item de stream, ou de sink).
type ev struct {
	id   uint32
	kind byte
	data []byte
}

// call roda em processo, sem canal, a entrada de chave [key] com os
// argumentos de [args]; devolve a resposta final e os eventos anteriores.
func call(t *testing.T, key string, args func(w *writer)) (byte, []byte, []ev) {
	t.Helper()
	for _, e := range table {
		if e.key != key {
			continue
		}
		w := &writer{}
		if args != nil {
			args(w)
		}
		var mu sync.Mutex
		var evs []ev
		kind, data := invoke(e, 1, w.b, func(id uint32, kind byte, data []byte) {
			mu.Lock()
			evs = append(evs, ev{id, kind, append([]byte{}, data...)})
			mu.Unlock()
		})
		return kind, data, evs
	}
	t.Fatalf("%s não está na tabela", key)
	return 0, nil, nil
}

// value: a resposta de uma chamada que tem de dar certo.
func value(t *testing.T, key string, args func(w *writer)) *reader {
	t.Helper()
	kind, data, _ := call(t, key, args)
	if kind != evValue {
		t.Fatalf("%s: tipo %d: %s", key, kind, data)
	}
	return &reader{b: data}
}

// O fluxo de criar e abrir um repositório pela tabela gerada, com os bytes
// de cada resposta passados adiante como o app faria.
func TestTableRepoFlow(t *testing.T) {
	const kubo = "github.com/ipfs/kubo/"
	pl := value(t, kubo+"plugin/loader.NewPluginLoader", func(w *writer) { w.str("") }).i64()
	value(t, kubo+"plugin/loader.PluginLoader.Initialize", func(w *writer) { w.i64(pl) })
	value(t, kubo+"plugin/loader.PluginLoader.Inject", func(w *writer) { w.i64(pl) })

	ident := value(t, kubo+"config.CreateIdentity", func(w *writer) { w.i32(0) }) // sem opções
	identity := ident.b
	if !ident.present() || ident.str() == "" { // PeerID
		t.Fatalf("Identity inesperada: %x", identity)
	}
	cfg := value(t, kubo+"config.InitWithIdentity", func(w *writer) { w.b = append(w.b, identity...) }).b
	dir := t.TempDir()
	value(t, kubo+"repo/fsrepo.Init", func(w *writer) { w.str(dir); w.b = append(w.b, cfg...) })
	if !value(t, kubo+"repo/fsrepo.IsInitialized", func(w *writer) { w.str(dir) }).bool() {
		t.Fatal("IsInitialized = false depois do Init")
	}
	repo := value(t, kubo+"repo/fsrepo.Open", func(w *writer) { w.str(dir) }).i64()
	if repo == 0 {
		t.Fatal("Open devolveu nil")
	}
	got := value(t, kubo+"repo.Repo.Config", func(w *writer) { w.i64(repo) })
	if !got.present() || !strings.Contains(got.str(), `"Identity"`) {
		t.Fatal("Repo.Config sem o JSON do config")
	}
	r, _ := hget[interface{ Close() error }](repo)
	if err := r.Close(); err != nil {
		t.Fatal(err)
	}
	hfree(repo)

	// argumentos errados: erro, não panic
	if kind, data, _ := call(t, kubo+"repo/fsrepo.Open", nil); kind != evError || !strings.Contains(string(data), "curtos") {
		t.Fatalf("pedido curto: %d %s", kind, data)
	}
}

func TestPanicHooks(t *testing.T) {
	// stream: item 1 e o panic como erro
	kind, data, evs := call(t, "ipfs_ffi/test.PanicInChanFunc", nil)
	if kind != evError || !strings.Contains(string(data), "panic") || len(evs) != 1 || evs[0].kind != evItem {
		t.Fatalf("PanicInChanFunc: %d %s %v", kind, data, evs)
	}
	// sink 9: item 1 e o erro, antes da resposta vazia
	kind, data, evs = call(t, "ipfs_ffi/test.PanicInSink", func(w *writer) { w.u32(9) })
	if kind != evValue || len(data) != 0 || len(evs) != 2 {
		t.Fatalf("PanicInSink: %d %s %v", kind, data, evs)
	}
	if e := evs[0]; e.id != 9 || e.kind != evItem || (&reader{b: e.data}).i64() != 1 {
		t.Fatalf("1º evento do sink: %+v", e)
	}
	if e := evs[1]; e.id != 9 || e.kind != evError || !strings.Contains(string(e.data), "panic") {
		t.Fatalf("2º evento do sink: %+v", e)
	}
}

func TestContextAndProfiles(t *testing.T) {
	ctx := value(t, "context.Background", nil).i64()
	r := value(t, "context.WithCancel", func(w *writer) { w.i64(ctx) })
	child, cancel := r.i64(), r.i64()
	if value(t, "context.Context.Err", func(w *writer) { w.i64(child) }).present() {
		t.Fatal("Err antes do cancel")
	}
	value(t, "context.CancelFunc", func(w *writer) { w.i64(cancel) })
	if e := value(t, "context.Context.Err", func(w *writer) { w.i64(child) }); !e.present() || e.str() != "context canceled" {
		t.Fatal("Err depois do cancel")
	}

	p := value(t, "config.Profiles", nil)
	n := int(p.i32())
	names := map[string]bool{}
	for range n {
		names[p.str()] = true
	}
	if !names["test"] || !names["server"] {
		t.Fatalf("perfis: %v", names)
	}
	out := value(t, "config.Profile.Transform", func(w *writer) { w.str("test"); w.str("{}") }).str()
	if !strings.Contains(out, "127.0.0.1") {
		t.Fatalf("perfil test não aplicado: %s", out)
	}
}

// nullChan: um canal sem sininho, para o despacho do host em processo.
type nullChan struct{ mem []byte }

func (c nullChan) region() []byte { return c.mem }
func (c nullChan) bellWait() bool { return false }
func (c nullChan) bellRing()      {}

// O despacho do host (Hello, Free, modo errado) sobre um anel de verdade.
func TestHostDispatch(t *testing.T) {
	const size = 1 << 16
	mem := make([]byte, shmring.RegionSize(size))
	shmring.Init(mem, size)
	h := &host{ch: nullChan{mem}}
	h.resp, _ = shmring.Open(mem, 1)
	ask := func(id, fn uint32, mode byte, args func(w *writer)) (uint32, byte, string) {
		t.Helper()
		w := &writer{}
		w.u32(id)
		w.u32(fn)
		w.u8(mode)
		if args != nil {
			args(w)
		}
		h.dispatch(w.b)
		f := h.resp.Peek()
		if f == nil {
			return 0, 0, ""
		}
		defer h.resp.Advance()
		r := &reader{b: f[frameHead:]}
		return r.u32(), r.u8(), string(r.b)
	}
	if id, kind, _ := ask(5, fnHello, modeSync, func(w *writer) { w.u64(tableHash) }); id != 5 || kind != evValue {
		t.Fatalf("Hello certo: %d %d", id, kind)
	}
	if _, kind, msg := ask(6, fnHello, modeSync, func(w *writer) { w.u64(tableHash + 1) }); kind != evError || !strings.Contains(msg, "tabela") {
		t.Fatalf("Hello errado: %d %s", kind, msg)
	}
	hd := hput(t)
	if id, _, _ := ask(0, fnFree, modeSync, func(w *writer) { w.i32(1); w.i64(hd) }); id != 0 {
		t.Fatal("Free respondeu")
	}
	if _, err := hget[*testing.T](hd); err == nil {
		t.Fatal("Free não soltou o handle")
	}
	if _, kind, msg := ask(7, 25, modeSync, nil); kind != evError || !strings.Contains(msg, "modo") {
		t.Fatalf("stream em modo síncrono: %d %s", kind, msg)
	}
	if _, kind, msg := ask(8, 40, modeSync, nil); kind != evValue || len(msg) < 4 {
		t.Fatalf("config.Profiles: %d %q", kind, msg)
	}
}
