// Package z não depende de a: na ordem do Go (≥ 1.21) vem depois de a,
// que é menor em import path, mas o main o importa primeiro.
package z

import (
	"fmt"

	"g2d.test/multiinit/b"
)

var Mark = b.Next("z.Mark")

func init() { fmt.Println("init z", Mark) }
