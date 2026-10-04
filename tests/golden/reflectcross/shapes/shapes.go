// Package shapes declara os tipos que o main inspeciona por reflexão: os
// descritores atravessam a fronteira de pacote, e o PkgPath dos campos não
// exportados é o deste pacote.
package shapes

import "fmt"

type Base struct {
	ID   int    `json:"id"`
	note string // não exportado
}

func (b Base) Describe() string { return fmt.Sprintf("base %d", b.ID) }

type Shape interface {
	Area() float64
}

type Rect struct {
	Base
	W, H  float64 `json:"w,omitempty" xml:"width"`
	Tags  []string
	Props map[string]int
	next  *Rect
}

func (r *Rect) Area() float64 { return r.W * r.H }

func New(w, h float64) *Rect { return &Rect{Base: Base{ID: 7, note: "n"}, W: w, H: h} }

type Unit int

func (u Unit) String() string { return fmt.Sprintf("%du", int(u)) }
