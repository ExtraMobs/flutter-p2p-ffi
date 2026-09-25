// Package main exercita embedding: promoção de campos e métodos (valor e
// ponteiro), sombreamento por profundidade, método promovido satisfazendo
// interface e embedding de *T nil.
package main

import "fmt"

type Named interface{ Title() string }

type Base struct {
	ID   int
	Tags []string
}

func (b Base) Title() string   { return fmt.Sprint("base#", b.ID) }
func (b *Base) Tag(t string)   { b.Tags = append(b.Tags, t) }
func (b Base) Describe() string { return fmt.Sprint("id=", b.ID, " tags=", len(b.Tags)) }

type Logger struct{ Prefix string }

func (l *Logger) Log(msg string) string { return l.Prefix + msg }

type Doc struct {
	Base
	*Logger
	Body string
}

func (d Doc) Describe() string { return "doc: " + d.Base.Describe() } // sombreia

func show(n Named) string { return n.Title() }

func main() {
	d := Doc{Base: Base{ID: 7}, Logger: &Logger{Prefix: "> "}, Body: "texto"}
	d.Tag("a")
	d.Tag("b")
	d.ID++
	fmt.Println(d.ID, d.Tags, d.Title(), d.Describe(), d.Base.Describe())
	fmt.Println(d.Log("oi"), d.Prefix, show(d), show(&d))

	e := d // cópia: Base copiado, Logger compartilhado
	e.ID = 100
	e.Prefix = "# "
	fmt.Println(d.ID, e.ID, d.Log("x"), e.Log("y"))

	var empty Doc
	defer func() { fmt.Println("recuperado:", recover()) }()
	fmt.Println(empty.Title())
	fmt.Println(empty.Log("nil logger"))
}
