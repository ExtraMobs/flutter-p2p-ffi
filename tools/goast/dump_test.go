package main

import (
	"encoding/json"
	"fmt"
	"go/constant"
	"sort"
	"strings"
	"testing"
)

// TestDumpHello roda o dump sobre o fixture tests/golden/hello.go e valida
// os pontos essenciais do schema consumido pelo transpilador Python.
func TestDumpHello(t *testing.T) {
	doc, err := Dump("../../tests/golden/hello")
	if err != nil {
		t.Fatalf("Dump: %v", err)
	}
	if doc.SchemaVersion != 5 {
		t.Errorf("schemaVersion = %d, esperado 5", doc.SchemaVersion)
	}
	if len(doc.Packages) != 1 {
		t.Fatalf("packages = %d, esperado 1", len(doc.Packages))
	}
	pkg := doc.Packages[0]
	if pkg.Name != "main" {
		t.Errorf("nome do pacote = %q, esperado %q", pkg.Name, "main")
	}

	// JSON válido (round-trip para árvore genérica facilita a busca).
	data, err := json.Marshal(doc)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	var root any
	if err := json.Unmarshal(data, &root); err != nil {
		t.Fatalf("JSON inválido: %v", err)
	}

	if !hasFuncDecl(root, "main") {
		t.Errorf("nó FuncDecl para main não encontrado na AST")
	}

	// A chamada g.Greet() é anotada inline com $type → basic string.
	var table []any
	for _, p := range root.(map[string]any)["packages"].([]any) {
		table = p.(map[string]any)["typeTable"].([]any)
	}
	typeName := func(n map[string]any) string {
		i, ok := n["$type"].(float64)
		if !ok {
			return ""
		}
		d := table[int(i)].(map[string]any)
		return d["kind"].(string) + ":" + fmt.Sprint(d["name"])
	}
	greet := false
	for _, c := range findNodes(root, "CallExpr") {
		if fun, ok := c["fun"].(map[string]any); ok && fun["node"] == "SelectorExpr" &&
			fun["sel"].(map[string]any)["name"] == "Greet" {
			greet = typeName(c) == "basic:string"
		}
	}
	if !greet {
		t.Errorf("primeira CallExpr (g.Greet()) sem $type string")
	}
	// Seletores com mesmo offset inicial (g e g.Name) têm anotações próprias.
	sels := findNodes(root, "SelectorExpr")
	fieldSel := false
	for _, s := range sels {
		if sel, ok := s["$sel"].(map[string]any); ok && sel["kind"] == "field" {
			fieldSel = typeName(s) == "basic:string" && typeName(s["x"].(map[string]any)) == "named:Greeter"
		}
	}
	if !fieldSel {
		t.Errorf("g.Name sem $sel field / tipos distintos de g")
	}

	found := false
	for _, s := range pkg.StdlibUsage {
		if s == "fmt.Println" {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("stdlibUsage não contém fmt.Println: %v", pkg.StdlibUsage)
	}

	if len(pkg.Imports) != 1 || pkg.Imports[0].Path != "fmt" {
		t.Errorf("imports inesperado: %+v", pkg.Imports)
	}
}

// hasFuncDecl busca recursivamente um nó {"node":"FuncDecl"} cujo campo
// "name" seja um Ident com o nome dado.
func hasFuncDecl(v any, name string) bool {
	m, ok := v.(map[string]any)
	if !ok {
		if list, ok := v.([]any); ok {
			for _, item := range list {
				if hasFuncDecl(item, name) {
					return true
				}
			}
		}
		return false
	}
	if m["node"] == "FuncDecl" {
		if ident, ok := m["name"].(map[string]any); ok && ident["name"] == name {
			return true
		}
	}
	for _, val := range m {
		if hasFuncDecl(val, name) {
			return true
		}
	}
	return false
}

// findNodes coleta, em ordem de travessia, todos os nós {"node": kind}.
func findNodes(v any, kind string) []map[string]any {
	var out []map[string]any
	var visit func(any)
	visit = func(v any) {
		switch v := v.(type) {
		case map[string]any:
			if v["node"] == kind {
				out = append(out, v)
			}
			for _, k := range sortedKeys(v) {
				visit(v[k])
			}
		case []any:
			for _, item := range v {
				visit(item)
			}
		}
	}
	visit(v)
	return out
}

func sortedKeys(m map[string]any) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func TestConstValueInvalidUTF8(t *testing.T) {
	data, err := json.Marshal(constValue(constant.MakeString("a\xff")))
	if err != nil {
		t.Fatal(err)
	}
	// "value" perde o byte inválido (U+FFFD); "bytes" preserva os originais.
	want := "{\"kind\":\"string\",\"value\":\"a\\ufffd\",\"bytes\":[97,255]}"
	if string(data) != want {
		t.Errorf("constValue = %s, esperado %s", data, want)
	}
}

func TestInitOrder(t *testing.T) {
	doc, err := Dump("../../tests/golden/inits")
	if err != nil {
		t.Fatal(err)
	}
	order := doc.Packages[0].InitOrder
	// x, y = pair() primeiro (pronta), total depois de base (dependência).
	if len(order) < 4 || len(order[0]) != 2 {
		t.Fatalf("initOrder inesperado: %v", order)
	}
	var names []string
	for _, e := range order {
		names = append(names, e[0])
	}
	idx := func(prefix string) int {
		for i, n := range names {
			if strings.HasPrefix(n, prefix) {
				return i
			}
		}
		return -1
	}
	if idx("b.go") < 0 {
		t.Errorf("fromB (b.go) ausente: %v", names)
	}
}
