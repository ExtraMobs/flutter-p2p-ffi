// Package a exercita tipo não exportado nomeado por outro pacote por
// inferência: ponteiro (TODO/P1-design-tipos-nao-exportados-entre-libraries),
// valor, assinatura de função exportada, campo exportado de struct exportada,
// slice/go.Elem e tipo não exportado sobre básico com N$Ptr.
package a

type impl struct{ n int }

func (i *impl) Get() int  { return i.n }
func (i *impl) Set(v int) { i.n = v }

// New: tipo não exportado por ponteiro (o repro original do artefato).
func New() *impl { return &impl{7} }

// Double: o tipo não exportado também aparece na assinatura (parâmetro e
// retorno) de uma função exportada.
func Double(i *impl) *impl {
	i.Set(i.Get() * 2)
	return i
}

// pair: tipo não exportado por valor (não ponteiro).
type pair struct{ a, b int }

func NewPair(a, b int) pair { return pair{a, b} }

func (p pair) Sum() int { return p.a + p.b }

// Box: struct exportada com campo exportado de tipo não exportado.
type Box struct{ Impl *impl }

func NewBox() Box { return Box{Impl: New()} }

// All: slice de ponteiros para o tipo não exportado (go.Elem entre pacotes).
func All() []*impl { return []*impl{New(), New()} }

// counter: tipo não exportado sobre básico com método de receptor ponteiro
// (gera N$Ptr, usado dentro do próprio pacote com *counter e devolvido).
type counter int

func (c *counter) Inc()      { *c++ }
func (c counter) Value() int { return int(c) }

func NewCounter() *counter {
	var c counter
	p := &c
	p.Inc()
	return p
}
