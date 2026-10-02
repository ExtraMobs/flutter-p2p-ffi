package c

import "g2d.test/promotecross/b"

// C embute b.Mid, que embute a.T3: Label() promovido em profundidade 2,
// através de dois pacotes (mixin b.Mid$Promote usa, dentro da library de b,
// o mixin a.T3$Promote).
type C struct {
	b.Mid
}
