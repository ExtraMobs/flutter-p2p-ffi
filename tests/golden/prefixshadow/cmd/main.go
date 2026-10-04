package main

import (
	"fmt"

	"g2d.test/prefixshadow/atlas"
	"g2d.test/prefixshadow/obj"
	"g2d.test/prefixshadow/tok"
)

func main() {
	t := &tok.Token{Type: tok.TString, Str: "x"}
	fmt.Println(obj.Reset(t), t.Type == tok.TNull, obj.Reset(t))
	fmt.Println(obj.NewSlab(atlas.Build("a")).Name(), obj.Empty().Name() == "")
}
