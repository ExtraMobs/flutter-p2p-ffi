package c

import (
	"g2d.test/promotedeep/a"
	"g2d.test/promotedeep/b"
)

// X: secret promovido em profundidade 2 (a.T → b.W → c.X).
type X struct{ b.W }

// Y: o mesmo por ponteiro no meio do caminho (*b.W).
type Y struct{ *b.W }

// Z: bump/peek de a.Cnt em profundidade 2 (a.Cnt → b.H → c.Z).
type Z struct{ b.H }

// RevealX força a.I no implements de X (import direto de a).
func RevealX(x X) string { return a.Reveal(x) }

func RevealY(y Y) string { return a.Reveal(y) }

func RevealS(s b.S) string { return a.Reveal(s) }

func BumpZ(z *Z) int { return a.Bump(z) }
