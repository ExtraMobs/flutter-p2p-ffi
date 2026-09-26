// Package a registra no init e depende de b: b inicializa antes.
package a

import (
	"fmt"

	"g2d.test/multiinit/b"
)

var Registry = map[string]int{}

var Base = b.Next("a.Base")

func init() {
	Registry["a"] = Base
	fmt.Println("init a", Base)
}
