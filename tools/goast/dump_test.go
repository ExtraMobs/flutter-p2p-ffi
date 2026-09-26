package main

import (
	"encoding/json"
	"fmt"
	"go/constant"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

// TestDumpHello roda o dump sobre o fixture tests/golden/hello.go e valida
// os pontos essenciais do schema consumido pelo transpilador Python.
func TestDumpHello(t *testing.T) {
	doc, err := Dump("", "../../tests/golden/hello")
	if err != nil {
		t.Fatalf("Dump: %v", err)
	}
	if doc.SchemaVersion != 8 {
		t.Errorf("schemaVersion = %d, esperado 8", doc.SchemaVersion)
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
	doc, err := Dump("", "../../tests/golden/inits")
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

// writeModule cria o módulo repro.local/mp num diretório temporário:
// pacotes a (com um .s) e cmd, sem .go na raiz.
func writeModule(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	files := map[string]string{
		"go.mod":      "module repro.local/mp\n\ngo 1.26\n",
		"a/a.go":      "package a\n\nvar X = 1\n",
		"a/stub.s":    "// vazio\n",
		"cmd/main.go": "package main\n\nimport \"repro.local/mp/a\"\n\nfunc main() { println(a.X) }\n",
	}
	for name, src := range files {
		path := filepath.Join(dir, filepath.FromSlash(name))
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(src), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

// TestDumpPatternDir cobre "dir/..." e "./..." num módulo sem .go na raiz
// (no Windows, os.Stat("dir\...") devolvia o próprio dir).
func TestDumpPatternDir(t *testing.T) {
	dir := writeModule(t)
	want := []string{"repro.local/mp/a", "repro.local/mp/cmd"}
	check := func(target string) {
		t.Helper()
		doc, err := Dump("", target)
		if err != nil {
			t.Fatalf("Dump(%q): %v", target, err)
		}
		var got []string
		for _, p := range doc.Packages {
			got = append(got, p.Path)
		}
		if strings.Join(got, " ") != strings.Join(want, " ") {
			t.Errorf("Dump(%q) = %v, esperado %v", target, got, want)
		}
	}
	check(filepath.ToSlash(dir) + "/...")
	t.Chdir(dir)
	check("./...")
}

// TestDumpModuleTargets cobre -C com vários alvos e os metadados de build.
func TestDumpModuleTargets(t *testing.T) {
	dir := writeModule(t)
	doc, err := Dump(dir, "repro.local/mp/cmd", "repro.local/mp/a")
	if err != nil {
		t.Fatalf("Dump: %v", err)
	}
	if len(doc.Packages) != 2 {
		t.Fatalf("packages = %d, esperado 2", len(doc.Packages))
	}
	a, cmd := doc.Packages[0], doc.Packages[1]
	if a.Path != "repro.local/mp/a" || cmd.Path != "repro.local/mp/cmd" {
		t.Fatalf("ordem = %s, %s", a.Path, cmd.Path)
	}
	if strings.Join(a.OtherFiles, " ") != "stub.s" || cmd.OtherFiles != nil {
		t.Errorf("otherFiles = %v / %v, esperado [stub.s] / []", a.OtherFiles, cmd.OtherFiles)
	}
	if a.Module == nil || a.Module.Path != "repro.local/mp" || a.Module.Version != "" {
		t.Errorf("module = %+v, esperado repro.local/mp (principal)", a.Module)
	}
	if _, err := Dump(dir, "repro.local/mp/nada"); err == nil {
		t.Errorf("alvo inexistente com -C: esperado erro (sem fallback loose)")
	}
}
