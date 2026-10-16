// Package shmring: os dois anéis da região de memória compartilhada entre o
// app (shm/ipfs_shm.c) e o ipfs_host. O layout abaixo é o contrato com o C;
// mudar aqui exige mudar lá (e o Version).
//
// Região (tamanho = HeaderSize + 2*ringSize):
//
//	0     u32 magic, u32 version, u64 ringSize
//	64    controle do anel 0 (pedidos, app → host)
//	320   controle do anel 1 (respostas e eventos, host → app)
//	4096  dados do anel 0; depois os do anel 1
//
// Controle de cada anel (uma linha de cache por campo, sem falso
// compartilhamento): +0 head u64 (do consumidor), +64 tail u64 (do
// produtor), +128 sleeping u32 (1 = o consumidor vai dormir no sininho).
//
// Mensagem: u32 tamanho + corpo, alinhada a 8. Um tamanho Wrap no lugar de
// uma mensagem manda o consumidor para o começo do anel. head e tail só
// crescem; o índice é pos % ringSize.
package shmring

import (
	"errors"
	"sync/atomic"
	"unsafe"
)

const (
	Magic      = 0x49504653 // "IPFS"
	Version    = 1
	HeaderSize = 4096
	ctlBase    = 64
	ctlSize    = 256
	offHead    = 0
	offTail    = 64
	offSleep   = 128
	Wrap       = 0xFFFFFFFF
)

// RegionSize é o tamanho da região para anéis de [ringSize] bytes cada.
func RegionSize(ringSize int) int { return HeaderSize + 2*ringSize }

// Init escreve o cabeçalho numa região nova (zerada).
func Init(mem []byte, ringSize int) {
	*(*uint64)(unsafe.Pointer(&mem[8])) = uint64(ringSize)
	*(*uint32)(unsafe.Pointer(&mem[4])) = Version
	atomic.StoreUint32((*uint32)(unsafe.Pointer(&mem[0])), Magic)
}

// Ring é um dos dois anéis da região. Um só produtor e um só consumidor por
// vez (quem tem vários produtores serializa por fora).
type Ring struct {
	ctl  unsafe.Pointer
	data []byte
	size uint64
}

// Open devolve o anel [i] (0 = pedidos, 1 = respostas) de uma região já
// iniciada.
func Open(mem []byte, i int) (*Ring, error) {
	if len(mem) < HeaderSize || atomic.LoadUint32((*uint32)(unsafe.Pointer(&mem[0]))) != Magic {
		return nil, errors.New("shmring: região sem cabeçalho")
	}
	if v := *(*uint32)(unsafe.Pointer(&mem[4])); v != Version {
		return nil, errors.New("shmring: versão diferente")
	}
	size := *(*uint64)(unsafe.Pointer(&mem[8]))
	if size == 0 || size%8 != 0 || uint64(len(mem)) < HeaderSize+2*size {
		return nil, errors.New("shmring: tamanho inválido")
	}
	start := HeaderSize + uint64(i)*size
	return &Ring{
		ctl:  unsafe.Pointer(&mem[ctlBase+i*ctlSize]),
		data: mem[start : start+size : start+size],
		size: size,
	}, nil
}

func (r *Ring) u64(off uintptr) *uint64 { return (*uint64)(unsafe.Add(r.ctl, off)) }
func (r *Ring) sleep() *uint32          { return (*uint32)(unsafe.Add(r.ctl, offSleep)) }
func (r *Ring) word(idx uint64) *uint32 {
	return (*uint32)(unsafe.Pointer(&r.data[idx]))
}

func align8(n uint64) uint64 { return (n + 7) &^ 7 }

// MaxMessage é o maior corpo que cabe numa mensagem.
func (r *Ring) MaxMessage() int { return int(r.size/2) - 4 }

// Reserve devolve o espaço para um corpo de [n] bytes, ou nil se o anel está
// cheio agora (o produtor tenta de novo). Commit publica.
func (r *Ring) Reserve(n int) []byte {
	if n > r.MaxMessage() {
		panic("shmring: mensagem maior que o anel")
	}
	tail := atomic.LoadUint64(r.u64(offTail))
	head := atomic.LoadUint64(r.u64(offHead))
	need := align8(4 + uint64(n))
	idx := tail % r.size
	skip := uint64(0)
	if idx+need > r.size {
		skip = r.size - idx
	}
	if tail+skip+need-head > r.size {
		return nil
	}
	if skip > 0 {
		*r.word(idx) = Wrap
		idx = 0
	}
	*r.word(idx) = uint32(n)
	return r.data[idx+4 : idx+4+uint64(n) : idx+4+uint64(n)]
}

// Commit publica a mensagem reservada (de [n] bytes) e diz se o consumidor
// estava dormindo, ou seja, se é preciso tocar o sininho.
func (r *Ring) Commit(n int) (wake bool) {
	tail := atomic.LoadUint64(r.u64(offTail))
	idx := tail % r.size
	need := align8(4 + uint64(n))
	if idx+need > r.size {
		tail += r.size - idx
	}
	atomic.StoreUint64(r.u64(offTail), tail+need)
	return atomic.LoadUint32(r.sleep()) == 1 && atomic.CompareAndSwapUint32(r.sleep(), 1, 0)
}

// Peek devolve o corpo da próxima mensagem, ou nil se o anel está vazio. O
// corpo vale até o Advance.
func (r *Ring) Peek() []byte {
	for {
		head := atomic.LoadUint64(r.u64(offHead))
		if head == atomic.LoadUint64(r.u64(offTail)) {
			return nil
		}
		idx := head % r.size
		n := *r.word(idx)
		if n == Wrap {
			atomic.StoreUint64(r.u64(offHead), head+r.size-idx)
			continue
		}
		return r.data[idx+4 : idx+4+uint64(n) : idx+4+uint64(n)]
	}
}

// Advance libera a mensagem devolvida pelo último Peek.
func (r *Ring) Advance() {
	head := atomic.LoadUint64(r.u64(offHead))
	n := *r.word(head % r.size)
	atomic.StoreUint64(r.u64(offHead), head+align8(4+uint64(n)))
}

// Empty diz se não há mensagem.
func (r *Ring) Empty() bool {
	return atomic.LoadUint64(r.u64(offHead)) == atomic.LoadUint64(r.u64(offTail))
}

// PrepareSleep marca o consumidor como dormindo e diz se pode dormir mesmo
// (false: chegou mensagem nesse meio-tempo, e ele segue consumindo). Quem
// dorme espera o sininho; um toque a mais só causa uma volta à toa.
func (r *Ring) PrepareSleep() bool {
	atomic.StoreUint32(r.sleep(), 1)
	if !r.Empty() {
		atomic.CompareAndSwapUint32(r.sleep(), 1, 0)
		return false
	}
	return true
}
