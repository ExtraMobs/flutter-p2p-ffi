package b

import "g2d.test/promotecross/a"

// W: embedding por valor, method set inteiro promovido (usa o mixin
// a.T$Promote, que carrega o `secret` privado da library de a).
type W struct {
	a.T
	Extra int
}

// WPtr: embedding por ponteiro (*a.T2).
type WPtr struct {
	*a.T2
}

// Mid: primeiro nível da promoção em profundidade 2 (a.T3 → c.C).
type Mid struct {
	a.T3
}
