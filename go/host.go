// O ipfs_host (marco 0.9.0): o kubo compilado como executável, num processo
// só dele. Um panic não tratado do kubo derruba este processo, e
// o app (lib/service.dart) recebe uma exceção e o relança. O app escreve os
// pedidos no anel 0 da região compartilhada e lê as respostas no anel 1
// (go/shmring); o socket/pipe só faz o aperto de mão, o sininho de quem
// dorme e a detecção de queda. O protocolo está em WIRE.md.
package main

import (
	"bytes"
	"encoding/binary"
	"flag"
	"fmt"
	"os"
	"runtime"
	"runtime/debug"
	"sync"
	"time"

	"github.com/ExtraMobs/transpiled_ipfs/go/shmring"
)

// Pedido: u32 id, u32 função, u8 modo, argumentos. Resposta: u32 id, u8
// tipo (os ev* de wire.go), dados. No anel, cada mensagem vai em um ou mais
// quadros [u32 continua][pedaço] (u32 para o pedaço ficar alinhado): a que não cabe num quadro é partida, e quem
// consome junta os pedaços (um produtor por vez, então não se misturam).
const (
	reqHeader  = 9
	respHeader = 5
	fnNoop     = 0
	fnSleep    = 1 // teste: responde depois de u32 ms, numa goroutine
	fnEcho     = 2 // teste: devolve os argumentos
	fnFree     = 3 // u32 n + n × i64 handles; sem resposta (id 0)
	fnHello    = 4 // u64 hash da tabela; erro se o host veio de outra tabela
	frameHead  = 4
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
	crashLog := flag.String("crash-log", "", "file for the Go crash report")
	ringSize := flag.Int("ring", 4<<20, "bytes of each ring")
	spin := flag.Int("spin", 20000, "spins before sleeping on the bell")
	flag.Parse()
	if *endpoint == "" {
		fmt.Fprintln(os.Stderr, "ipfs_host: falta -endpoint")
		os.Exit(2)
	}
	if *crashLog != "" {
		// acrescenta: o host relançado não apaga o relatório da queda anterior
		if f, err := os.OpenFile(*crashLog, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600); err == nil {
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
	var parts []byte // pedaços de uma mensagem partida
	for {
		f := h.req.Peek()
		if f == nil {
			if !h.idle() {
				return
			}
			continue
		}
		switch {
		case len(f) < frameHead:
		case f[0] == 1: // continua no próximo quadro
			parts = append(parts, f[frameHead:]...)
		case parts != nil:
			m := append(parts, f[frameHead:]...)
			parts = nil
			h.dispatch(m)
		default:
			h.dispatch(f[frameHead:]) // o caso comum, sem cópia
		}
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
	ok := h.ch.bellWait()
	bells.wakes.Add(1) // o app tocou (manual_bench.go)
	return ok
}

// dispatch trata um pedido; [m] só vale durante a chamada (é o anel), então
// o que segue numa goroutine copia antes. Síncrona responde aqui, em ordem;
// assíncrona e stream rodam numa goroutine.
func (h *host) dispatch(m []byte) {
	if len(m) < reqHeader {
		return
	}
	id := binary.LittleEndian.Uint32(m)
	fn := binary.LittleEndian.Uint32(m[4:])
	mode := m[8]
	watch := mode&modeWatch != 0 // toca um objeto em uso por um callback (deadlock.go)
	mode &^= modeWatch
	args := m[reqHeader:]
	switch fn {
	case fnNoop:
		h.reply(id, evValue, nil)
		return
	case fnEcho:
		h.reply(id, evValue, args)
		return
	case fnSleep:
		if len(args) < 4 {
			h.reply(id, evError, errText("ipfs_host: Sleep without the ms"))
			return
		}
		ms := binary.LittleEndian.Uint32(args)
		h.spawn(func() {
			time.Sleep(time.Duration(ms) * time.Millisecond)
			h.reply(id, evValue, nil)
		})
		return
	case fnFree:
		r := &reader{b: args}
		for range r.count() {
			hfree(r.i64())
		}
		return
	case fnCallbackAck: // callback.go
		callbackAck(args)
		return
	case fnHello:
		r := &reader{b: args}
		got := r.u64()
		switch {
		case r.done() != nil:
			h.reply(id, evError, errText(r.err.Error()))
		case got != tableHash:
			h.reply(id, evError, errText(fmt.Sprintf("ipfs_host: table %#x, the app expects %#x (generated from different roots.txt)", tableHash, got)))
		default:
			h.reply(id, evValue, nil)
		}
		return
	}
	e, ok := table[fn]
	switch {
	case !ok:
		h.reply(id, evError, errText(fmt.Sprintf("ipfs_host: unknown function %d", fn)))
		return
	case e.stream != (mode == modeStream):
		h.reply(id, evError, errText(fmt.Sprintf("ipfs_host: %s (%d) chamada no modo %d", e.key, fn, mode)))
		return
	case watch && mode == modeSync: // deadlock.go: o laço espera, mas o impasse o solta
		h.watch(e, id, bytes.Clone(args))
		return
	case mode == modeSync:
		kind, data := invoke(e, id, args, h.reply)
		h.reply(id, kind, data)
		return
	}
	args = bytes.Clone(args)
	h.spawn(func() {
		if watch {
			h.watch(e, id, args)
			return
		}
		kind, data := invoke(e, id, args, h.reply)
		h.reply(id, kind, data)
	})
}

// spawn roda f numa goroutine com recover: o invoke já transforma o panic
// da chamada em erro; este pega um no envio, que só vai ao stderr (não há
// mais como responder).
func (h *host) spawn(f func()) {
	go func() {
		if err := try(func() error { f(); return nil }); err != nil {
			fmt.Fprintln(os.Stderr, "ipfs_host:", err)
		}
	}()
}

// reply escreve a resposta [id] no anel 1, partida em quadros se preciso
// (esperando espaço), e toca o sininho se o app dormia.
func (h *host) reply(id uint32, kind byte, data []byte) {
	var head [respHeader]byte
	binary.LittleEndian.PutUint32(head[:], id)
	head[4] = kind
	h.mu.Lock()
	defer h.mu.Unlock()
	h.send(head[:], data)
}

// send escreve [head]+[data] no anel 1 em quadros de no máximo MaxMessage.
// Chamado com h.mu.
func (h *host) send(head, data []byte) {
	max := h.resp.MaxMessage() - frameHead
	total := len(head) + len(data)
	off := 0
	for {
		n := min(total-off, max)
		var b []byte
		for i := 0; ; i++ {
			if b = h.resp.Reserve(n + frameHead); b != nil {
				break
			}
			if i%64 == 63 {
				runtime.Gosched()
			}
		}
		more := uint32(0)
		if off+n < total {
			more = 1
		}
		binary.LittleEndian.PutUint32(b, more)
		// copia o pedaço [off, off+n) de head+data
		w := b[frameHead:]
		for k := 0; k < n; {
			pos := off + k
			if pos < len(head) {
				k += copy(w[k:], head[pos:])
			} else {
				k += copy(w[k:n], data[pos-len(head):])
			}
		}
		wake := h.resp.Commit(n + frameHead)
		if wake {
			h.ch.bellRing()
			bells.rings.Add(1)
		}
		off += n
		if off == total {
			return
		}
	}
}
