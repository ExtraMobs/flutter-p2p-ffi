// Tipo nomeado sobre array (type Hash [4]byte, DoNotCompare [0]func() do
// protobuf pragma): valor, métodos de valor e ponteiro, conversões, chave de map.
package main

import "fmt"

type Hash [4]byte

func (h Hash) Hex() string { return fmt.Sprintf("%x", h[:]) }

func (h *Hash) Reset() { *h = Hash{} }

func (h *Hash) Set(i int, b byte) { h[i] = b }

type DoNotCompare [0]func()

type Msg struct {
	_    DoNotCompare
	ID   Hash
	Name string
}

type Grid [2][2]int

func main() {
	var h Hash
	h.Set(0, 0xab)
	h[3] = 1
	g := h // cópia
	g.Set(1, 0xff)
	fmt.Println(h.Hex(), g.Hex(), h == g, h, len(h))
	a := [4]byte(h)
	a[0] = 0
	h2 := Hash(a)
	fmt.Println(a, h2, h2 == Hash{0, 0, 0, 1})
	m := map[Hash]string{h: "h", g: "g"}
	fmt.Println(m[h], m[g], len(m))
	msg := Msg{ID: Hash{1, 2, 3, 4}, Name: "x"}
	p := &msg.ID
	p.Reset()
	fmt.Println(msg, msg.ID.Hex())
	var gr Grid
	gr[1][0] = 7
	fmt.Printf("%v %T %T\n", gr, h, gr)
	var i any = h
	_, isHash := i.(Hash)
	fmt.Println(isHash, i == any(h), i == any([4]byte(h)))
}
