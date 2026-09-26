// import _: pacote do grafo importado só pelo init, e pacote da stdlib
// (golang.org/x/crypto/ocsp: _ "crypto/sha256").
package main

import (
	_ "crypto/sha256"
	"fmt"

	_ "g2d.test/blankimport/plug"
	"g2d.test/blankimport/registry"
)

func init() { registry.Register("main") }

func main() {
	fmt.Println(registry.Names)
}
