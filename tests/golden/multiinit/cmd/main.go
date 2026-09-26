package main

import (
	"fmt"

	z "g2d.test/multiinit/z"

	"g2d.test/multiinit/a"
	"g2d.test/multiinit/b"
)

var local = b.Next("main.local")

func main() {
	fmt.Println(a.Registry["a"], len(a.Registry), z.Mark, local)
	fmt.Println(b.Order)
}
