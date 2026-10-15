// O ipfs_host (marco 0.9.0): o mesmo Go da lib, compilado como executável,
// num processo só dele. Um panic não tratado do kubo derruba este processo, e
// o app (lib/service.dart) recebe uma exceção e o relança. O app escreve os
// pedidos no anel 0 da região compartilhada e lê as respostas no anel 1
// (go/shmring); o socket/pipe só faz o aperto de mão, o sininho de quem
// dorme e a detecção de queda. No c-shared o main() nunca roda.
package main

import (
	"encoding/binary"
	"flag"
	"fmt"
	"os"
	"runtime"
	"runtime/debug"
	"sync"
	"time"

	"github.com/ExtraMobs/transpiled_ipfs/ipfs_ffi/go/shmring"
)

// Pedido: u32 id, u32 função, u8 modo, argumentos. Resposta: u32 id, u8
// tipo (os ev* de runtime.go), dados.
const (
	reqHeader  = 9
	respHeader = 5
	fnNoop     = 0
	fnSleep    = 1 // teste: responde depois de u32 ms, numa goroutine
)

// hostChan: a parte de cada sistema (host_unix.go, host_windows.go).
type hostChan interface {
	region() []byte
	bellWait() bool // bloqueia até o app tocar; false = o app fechou
	bellRing()
}

type host struct {
	ch        hostChan
	req, resp *shmring.Ring
	spin      int
	mu        sync.Mutex // um produtor por vez no anel de respostas
}

func runHost() {
	endpoint := flag.String("endpoint", "", "Unix socket (linux/Android) ou nome base dos pipes (Windows)")
	crashLog := flag.String("crash-log", "", "arquivo do relatório de crash do Go")
	ringSize := flag.Int("ring", 4<<20, "bytes de cada anel")
	spin := flag.Int("spin", 20000, "voltas antes de dormir no sininho")
	flag.Parse()
	if *endpoint == "" {
		fmt.Fprintln(os.Stderr, "ipfs_host: falta -endpoint")
		os.Exit(2)
	}
	if *crashLog != "" {
		if f, err := os.Create(*crashLog); err == nil {
			_ = debug.SetCrashOutput(f, debug.CrashOptions{})
			f.Close()
		}
	}
	ch, err := listen(*endpoint, shmring.RegionSize(*ringSize), func(mem []byte) {
		shmring.Init(mem, *ringSize)
	})
	if err != nil {
		fmt.Fprintln(os.Stderr, "ipfs_host:", err)
		os.Exit(1)
	}
	h := &host{ch: ch, spin: *spin}
	h.req, _ = shmring.Open(ch.region(), 0)
	h.resp, _ = shmring.Open(ch.region(), 1)
	h.serve()
	os.Exit(0) // o app fechou o canal
}

// serve consome os pedidos até o app fechar o canal.
func (h *host) serve() {
	for {
		m := h.req.Peek()
		if m == nil {
			if !h.idle() {
				return
			}
			continue
		}
		h.dispatch(m)
		h.req.Advance()
	}
}

// idle gira um pouco e depois dorme no sininho; false = o app fechou.
func (h *host) idle() bool {
	for i := 0; i < h.spin; i++ {
		if !h.req.Empty() {
			return true
		}
		if i%64 == 63 {
			runtime.Gosched()
		}
	}
	if !h.req.PrepareSleep() {
		return true
	}
	return h.ch.bellWait()
}

func (h *host) dispatch(m []byte) {
	if len(m) < reqHeader {
		return
	}
	id := binary.LittleEndian.Uint32(m)
	switch fn := binary.LittleEndian.Uint32(m[4:]); fn {
	case fnNoop:
		h.reply(id, evValue, nil)
	case fnSleep:
		if len(m) < reqHeader+4 {
			h.reply(id, evError, []byte("ipfs_host: Sleep sem os ms"))
			return
		}
		ms := binary.LittleEndian.Uint32(m[reqHeader:])
		go func() {
			time.Sleep(time.Duration(ms) * time.Millisecond)
			h.reply(id, evValue, nil)
		}()
	default:
		h.reply(id, evError, []byte(fmt.Sprintf("ipfs_host: função %d desconhecida", fn)))
	}
}

// reply escreve a resposta [id] no anel 1 (esperando espaço) e toca o
// sininho se o app dormia.
func (h *host) reply(id uint32, kind byte, data []byte) {
	n := respHeader + len(data)
	h.mu.Lock()
	var b []byte
	for i := 0; ; i++ {
		if b = h.resp.Reserve(n); b != nil {
			break
		}
		if i%64 == 63 {
			runtime.Gosched()
		}
	}
	binary.LittleEndian.PutUint32(b, id)
	b[4] = kind
	copy(b[respHeader:], data)
	wake := h.resp.Commit(n)
	h.mu.Unlock()
	if wake {
		h.ch.bellRing()
	}
}
