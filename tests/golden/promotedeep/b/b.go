package b

import "g2d.test/promotedeep/a"

// W: um salto (a.T → b.W), mixin a.T$Promote inteiro.
type W struct{ a.T }

// S sombreia Hello: o a.T vai por forwarders inline, e o secret (não
// exportado de a) entra pelo mixin extra do dono de fato.
type S struct{ a.T }

func (s S) Hello() string { return "S:" + s.Name }

// H embute o não-struct a.Cnt (método não exportado de receptor ponteiro).
type H struct{ a.Cnt }
