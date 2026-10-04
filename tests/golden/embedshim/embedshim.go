// Struct que embute um tipo de shim (time.Time): os métodos que o shim tem
// são promovidos; os que ele não tem (GobEncode...) ficam sem forwarder.
package main

import (
	"fmt"
	"time"
)

type T struct{ time.Time }

type P struct{ *time.Time }

func main() {
	t := T{time.Unix(0, 0).UTC()}
	fmt.Println(t.Year(), t.Format(time.RFC3339))
	var s fmt.Stringer = t
	fmt.Println(s)
	u := time.Unix(86400, 0).UTC()
	p := P{&u}
	fmt.Println(p.Day(), p.Add(time.Hour).Hour())
}
