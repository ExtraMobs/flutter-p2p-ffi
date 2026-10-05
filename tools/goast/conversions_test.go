package main

import (
	"slices"
	"testing"
)

// typeName: nome curto (`a.T`, `*a.P`, `interface`) de um índice da tabela.
func typeName(tt []jobject, ref any) string {
	d := tt[ref.(int)]
	get := func(k string) any {
		for _, p := range d {
			if p.key == k {
				return p.val
			}
		}
		return nil
	}
	switch get("kind") {
	case "named":
		pkg := get("pkg").(string)
		for i := len(pkg) - 1; i >= 0; i-- {
			if pkg[i] == '/' {
				pkg = pkg[i+1:]
				break
			}
		}
		return pkg + "." + get("name").(string)
	case "pointer":
		return "*" + typeName(tt, get("elem"))
	}
	return get("kind").(string)
}

// TestConversions: as conversões tipo concreto → interface e os alvos
// dinâmicos do fixture ifacecross (D8).
func TestConversions(t *testing.T) {
	doc, err := Dump("../../tests/golden/ifacecross", "./...")
	if err != nil {
		t.Fatal(err)
	}
	got := map[string][]string{}
	asserts := map[string][]string{}
	for _, p := range doc.Packages {
		for _, c := range p.Conversions {
			got[p.Path] = append(got[p.Path], typeName(p.TypeTable, c[0].val)+" → "+typeName(p.TypeTable, c[1].val))
		}
		for _, a := range p.Asserts {
			asserts[p.Path] = append(asserts[p.Path], typeName(p.TypeTable, a))
		}
	}
	cmd := got["g2d.test/ifacecross/cmd"]
	for _, want := range []string{"a.T → b.Namer", "*a.P → b.Namer", "a.Ints → sort.Interface",
		"a.U → interface", "tok.Token → interface"} {
		if !slices.Contains(cmd, want) {
			t.Errorf("conversão %q ausente em cmd: %v", want, cmd)
		}
	}
	if b := asserts["g2d.test/ifacecross/b"]; !slices.Contains(b, "b.Namer") || !slices.Contains(b, "interface") {
		t.Errorf("asserts de b: %v", b)
	}
	if a := got["g2d.test/ifacecross/a"]; !slices.Equal(a, []string{"a.doneErr → .error"}) {
		t.Errorf("a só converte doneErr para error: %v", a)
	}
}
