// Membro com o nome de um tipo não exportado (golang.org/x/crypto/internal/poly1305:
// type mac struct{ macGeneric }): o tipo vira `_t$`, o membro `_t`.
package main

import "fmt"

type macGeneric struct{ n int }

func (h *macGeneric) Write(p []byte) int { h.n += len(p); return h.n }

type mac struct{ macGeneric }

type buf []byte

type state struct {
	buf buf // campo com o nome do tipo
}

func (s *state) state() int { return len(s.buf) } // método com o nome do tipo

func main() {
	var m mac
	m.Write([]byte("abc"))
	fmt.Println(m.Write([]byte("de")), m.n, m.macGeneric)
	s := state{buf: buf("xyz")}
	fmt.Println(s.state(), string(s.buf), s)
}
