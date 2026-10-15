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
// tipo (os ev* de runtime.go), dados. No anel, cada mensagem vai em um ou mais
// quadros [u32 continua][pedaço] (u32 para o pedaço ficar alinhado): a que não cabe num quadro é partida, e quem
// consome junta os pedaços (um produtor por vez, então não se misturam).
const (
	reqHeader  = 9
	respHeader = 5
	fnNoop     = 0
	fnSleep    = 1 // teste: responde depois de u32 ms, numa goroutine
	fnEcho     = 2 // teste: devolve os argumentos
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
	return h.ch.bellWait()
}

// dispatch trata um pedido; [m] só vale durante a chamada (é o anel), então
// o que segue numa goroutine copia antes.
func (h *host) dispatch(m []byte) {
	if len(m) < reqHeader {
		return
	}
	id := binary.LittleEndian.Uint32(m)
	switch fn := binary.LittleEndian.Uint32(m[4:]); fn {
	case fnNoop:
		h.reply(id, evValue, nil)
	case fnEcho:
		h.reply(id, evValue, m[reqHeader:])
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
		h.reply(id, evError, fmt.Appendf(nil, "ipfs_host: função %d desconhecida", fn))
	}
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
		}
		off += n
		if off == total {
			return
		}
	}
}
