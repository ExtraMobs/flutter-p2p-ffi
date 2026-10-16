package shmring

import (
	"bytes"
	"encoding/binary"
	"sync"
	"testing"
)

func newRegion(t *testing.T, ringSize int) (prod, cons *Ring) {
	t.Helper()
	mem := make([]byte, RegionSize(ringSize))
	Init(mem, ringSize)
	p, err := Open(mem, 0)
	if err != nil {
		t.Fatal(err)
	}
	c, err := Open(mem, 0)
	if err != nil {
		t.Fatal(err)
	}
	return p, c
}

func TestOpenRejectsBadRegion(t *testing.T) {
	if _, err := Open(make([]byte, RegionSize(64)), 0); err == nil {
		t.Fatal("região sem cabeçalho aceita")
	}
}

func TestEmptyFullAndWrap(t *testing.T) {
	p, c := newRegion(t, 64)
	if c.Peek() != nil || !c.Empty() {
		t.Fatal("anel novo não está vazio")
	}
	// 3 mensagens de 12 bytes ocupam 16 cada: a 4ª não cabe (48+16 = 64 cabe;
	// a 5ª não)
	for i := range 4 {
		b := p.Reserve(12)
		if b == nil {
			t.Fatalf("cheio cedo demais na %d", i)
		}
		b[0] = byte(i)
		p.Commit(12)
	}
	if p.Reserve(12) != nil {
		t.Fatal("aceitou além da capacidade")
	}
	for i := range 4 {
		m := c.Peek()
		if m == nil || m[0] != byte(i) {
			t.Fatalf("mensagem %d errada: %v", i, m)
		}
		c.Advance()
	}
	if c.Peek() != nil {
		t.Fatal("sobrou mensagem")
	}
	// tail em 64 = índice 0; uma de 20 (24 com o tamanho) e outra de 28 (32):
	// a 3ª, de 12, não cabe no fim (8 livres) e dá a volta com Wrap
	for _, n := range []int{20, 28} {
		p.Reserve(n)
		p.Commit(n)
	}
	c.Peek()
	c.Advance()
	c.Peek()
	c.Advance()
	b := p.Reserve(12)
	if b == nil {
		t.Fatal("não deu a volta")
	}
	copy(b, "dá a volta!!")
	p.Commit(12)
	if m := c.Peek(); string(m) != "dá a volta!!"[:12] {
		t.Fatalf("depois da volta: %q", m)
	}
}

func TestSleepAndWake(t *testing.T) {
	p, c := newRegion(t, 64)
	if !c.PrepareSleep() {
		t.Fatal("vazio e não pode dormir")
	}
	p.Reserve(1)
	if !p.Commit(1) {
		t.Fatal("consumidor dormindo e o produtor não tocou o sininho")
	}
	p.Reserve(1)
	if p.Commit(1) {
		t.Fatal("tocou duas vezes")
	}
	if c.PrepareSleep() {
		t.Fatal("dormiu com mensagem no anel")
	}
}

// Produtores concorrentes (serializados por mutex, como no host) e um
// consumidor: tudo chega, em ordem por produtor, sem corromper (rodar com -race).
func TestConcurrent(t *testing.T) {
	p, c := newRegion(t, 1<<12)
	const producers, per = 4, 20000
	var mu sync.Mutex
	var wg sync.WaitGroup
	for id := range producers {
		wg.Go(func() {
			for seq := range per {
				n := 8 + seq%40
				for {
					mu.Lock()
					b := p.Reserve(n)
					if b != nil {
						binary.LittleEndian.PutUint32(b, uint32(id))
						binary.LittleEndian.PutUint32(b[4:], uint32(seq))
						for k := 8; k < n; k++ {
							b[k] = byte(seq)
						}
						p.Commit(n)
						mu.Unlock()
						break
					}
					mu.Unlock()
				}
			}
		})
	}
	next := make([]int, producers)
	for got := 0; got < producers*per; {
		m := c.Peek()
		if m == nil {
			continue
		}
		id := binary.LittleEndian.Uint32(m)
		seq := int(binary.LittleEndian.Uint32(m[4:]))
		if seq != next[id] || len(m) != 8+seq%40 || !bytes.Equal(m[8:], bytes.Repeat([]byte{byte(seq)}, len(m)-8)) {
			t.Fatalf("produtor %d: esperava seq %d, veio %d (%d bytes)", id, next[id], seq, len(m))
		}
		next[id]++
		c.Advance()
		got++
	}
	wg.Wait()
}
