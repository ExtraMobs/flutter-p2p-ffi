package both

import (
	"g2d.test/promotecross/a"
	"g2d.test/promotecross/d"
)

// Ambi: dois métodos exportados de mesmo nome, mesma profundidade,
// embutidos de pacotes diferentes → ambíguo (Go recusa amb.Kind(); só
// amb.Kinded1.Kind()/amb.Kinded2.Kind() compilam).
type Ambi struct {
	a.Kinded1
	d.Kinded2
}

// Both: método não exportado de mesmo nome em pacotes diferentes → não é
// ambíguo (identificador não exportado é por pacote); os dois são
// promovidos (cada um satisfaz a interface do seu próprio pacote de
// origem).
type Both struct {
	a.Whisperer1
	d.Whisperer2
}
