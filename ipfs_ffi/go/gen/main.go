// Command gen gera a ponte FFI do ipfs_ffi a partir das raízes em
// gen/roots.txt (um símbolo Go por linha): go/zz_generated.go (os
// despachantes binários do ipfs_host, WIRE.md), as libraries Dart em lib/ (uma por pacote Go, sem o
// prefixo github.com/<org>/) e o API.md (checklist Go → Dart com omissões).
//
// Uso, na pasta go/: go run ./gen [-check]
package main

import (
	"bytes"
	"flag"
	"fmt"
	"go/types"
	"hash/fnv"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"golang.org/x/tools/go/packages"
)

// paramNames: nomes para parâmetros que a interface do kubo não nomeia e que
// o tipo não explica (string, []byte), como na documentação do kubo.
var paramNames = map[string][]string{
	"github.com/ipfs/kubo/core/coreiface.PubSubAPI.Publish":   {"ctx", "topic", "data"},
	"github.com/ipfs/kubo/core/coreiface.PubSubAPI.Subscribe": {"ctx", "topic", "opts"},
}

// forceAsync: funções sem context que bloqueiam (rede, desligamento).
var forceAsync = setOf(`github.com/ipfs/kubo/core.IpfsNode.Close`)

type param struct {
	name     string
	t        *tinfo
	variadic bool
}

type fn struct {
	key     string       // a linha da raiz: chave do despacho
	obj     types.Object // *types.Func, ou *types.Var de pacote (isVar)
	isVar   bool
	conv    types.Type     // variável: converter para este tipo nomeado
	pkg     *types.Package // library Dart de destino
	recv    *tinfo
	params  []param
	results []*tinfo
	hasErr  bool
	async   bool
	stream  *tinfo // elemento do canal (kChanSend em parâmetro ou kChanRecv no resultado)
	why     string // motivo da omissão
	direct  int    // ponytail: sempre -1 (os exports diretos saíram no 0.9.0); sai quando emit_dart.go/emit_api.go pararem de lê-lo
	id      int    // id da função no protocolo do serviço (WIRE.md); 0 = omitida
}

// firstID: os ids abaixo são do runtime e das funções escritas à mão (WIRE.md).
const firstID = 64

// assignIDs numera as funções expostas (sem as omitidas) em ordem de chave a
// partir de firstID e devolve o hash da tabela (FNV-1a de "id chave\n" por
// função), que o app e o host comparam no aperto de mão: os dois lados têm de
// vir do mesmo gerador.
func assignIDs(fns []*fn) uint64 {
	var live []*fn
	for _, f := range fns {
		if f.why == "" {
			live = append(live, f)
		}
	}
	sort.Slice(live, func(i, j int) bool { return live[i].key < live[j].key })
	h := fnv.New64a()
	for i, f := range live {
		f.id = firstID + i
		fmt.Fprintf(h, "%d %s\n", f.id, f.key)
	}
	return h.Sum64()
}

func main() {
	check := flag.Bool("check", false, "só compara com os arquivos commitados")
	flag.Parse()
	out, err := generate("gen/roots.txt")
	if err != nil {
		fmt.Fprintln(os.Stderr, "gen:", err)
		os.Exit(1)
	}
	stale := false
	for _, name := range sortedKeys(out) {
		old, _ := os.ReadFile(name)
		if bytes.Equal(old, out[name]) {
			continue
		}
		if *check {
			fmt.Fprintln(os.Stderr, "desatualizado:", name)
			stale = true
			continue
		}
		if err := os.MkdirAll(filepath.Dir(name), 0o755); err != nil {
			fmt.Fprintln(os.Stderr, "gen:", err)
			os.Exit(1)
		}
		if err := os.WriteFile(name, out[name], 0o644); err != nil {
			fmt.Fprintln(os.Stderr, "gen:", err)
			os.Exit(1)
		}
		fmt.Println("gerado:", name)
	}
	for _, name := range staleGenerated(out) {
		if *check {
			fmt.Fprintln(os.Stderr, "sobrando:", name)
			stale = true
			continue
		}
		if err := os.Remove(name); err != nil {
			fmt.Fprintln(os.Stderr, "gen:", err)
			os.Exit(1)
		}
		fmt.Println("removido:", name)
	}
	if stale {
		os.Exit(1)
	}
}

// generate devolve o conteúdo de cada arquivo gerado (caminho relativo a go/).
func generate(rootsFile string) (map[string][]byte, error) {
	lines, err := readRoots(rootsFile)
	if err != nil {
		return nil, err
	}
	pkgs, err := load(lines)
	if err != nil {
		return nil, err
	}
	m := newModel()
	m.load = func(path string) *types.Package {
		if p, ok := pkgs[path]; ok {
			return p
		}
		more, err := loadPaths([]string{path})
		if err != nil {
			return nil
		}
		pkgs[path] = more[path]
		return more[path]
	}
	var fns []*fn
	for _, line := range lines {
		f, err := m.resolve(pkgs, line)
		if err != nil {
			return nil, err
		}
		fns = append(fns, f)
	}
	for _, f := range fns {
		f.direct = -1
	}
	hash := assignIDs(fns) // WIRE.md: os emissores binários usam f.id e o hash
	out := map[string][]byte{}
	goSrc, err := emitGo(m, fns, hash)
	if err != nil {
		return nil, err
	}
	out["zz_generated.go"] = goSrc
	for path, src := range emitDart(m, fns, hash) {
		out[filepath.ToSlash(filepath.Join("../lib", path))] = src
	}
	out["../API.md"] = emitAPI(m, fns)
	if err := emitNamespaces(out); err != nil {
		return nil, err
	}
	return out, nil
}

func readRoots(file string) ([]string, error) {
	b, err := os.ReadFile(file)
	if err != nil {
		return nil, err
	}
	var lines []string
	for _, l := range strings.Split(string(b), "\n") {
		if l = strings.TrimSpace(l); l != "" && !strings.HasPrefix(l, "#") {
			lines = append(lines, l)
		}
	}
	return lines, nil
}

// splitRoot: "github.com/ipfs/kubo/core.IpfsNode.Close" → pacote, nome, método.
func splitRoot(line string) (pkg, name, method string) {
	slash := strings.LastIndex(line, "/")
	parts := strings.Split(line[slash+1:], ".")
	pkg = line[:slash+1] + parts[0]
	if len(parts) > 1 {
		name = parts[1]
	}
	if len(parts) > 2 {
		method = parts[2]
	}
	return
}

// load carrega os pacotes das raízes como o build do ipfs_host os vê (sem cgo).
func load(lines []string) (map[string]*types.Package, error) {
	seen := map[string]bool{}
	var paths []string
	for _, l := range lines {
		if p, _, _ := splitRoot(l); !seen[p] {
			seen[p] = true
			paths = append(paths, p)
		}
	}
	return loadPaths(paths)
}

func loadPaths(paths []string) (map[string]*types.Package, error) {
	cfg := &packages.Config{
		Mode: packages.NeedName | packages.NeedTypes,
		Env:  append(os.Environ(), "CGO_ENABLED=0"),
	}
	list, err := packages.Load(cfg, paths...)
	if err != nil {
		return nil, err
	}
	out := map[string]*types.Package{}
	for _, p := range list {
		if len(p.Errors) > 0 {
			return nil, fmt.Errorf("%s: %v", p.PkgPath, p.Errors[0])
		}
		out[p.PkgPath] = p.Types
	}
	return out, nil
}

func (m *model) resolve(pkgs map[string]*types.Package, line string) (*fn, error) {
	pkgPath, name, method := splitRoot(line)
	pkg := pkgs[pkgPath]
	if pkg == nil || name == "" {
		return nil, fmt.Errorf("raiz inválida: %s", line)
	}
	obj := pkg.Scope().Lookup(name)
	f := &fn{key: line, pkg: pkg}
	switch {
	case method == "":
		switch o := obj.(type) {
		case *types.Func:
			f.obj = o
		case *types.Var: // variável de pacote: getter sem parâmetros
			f.obj, f.isVar = o, true
			t := o.Type()
			// func sem nome (NilRouterOption = constructNilRouting) idêntica a um
			// tipo nomeado do pacote (RoutingOption): usa o tipo nomeado.
			if _, unnamed := t.(*types.Signature); unnamed {
				for _, n := range pkg.Scope().Names() {
					if tn, ok := pkg.Scope().Lookup(n).(*types.TypeName); ok && tn.Exported() && types.Identical(tn.Type().Underlying(), t) {
						t, f.conv = tn.Type(), tn.Type()
						break
					}
				}
			}
			f.results = []*tinfo{m.classify(t)}
			m.check(f)
			return f, nil
		default:
			return nil, fmt.Errorf("%s não é função nem variável", line)
		}
	default:
		tn, ok := obj.(*types.TypeName)
		if !ok {
			return nil, fmt.Errorf("%s: %s não é tipo", line, name)
		}
		recvT := tn.Type()
		if !types.IsInterface(recvT) {
			recvT = types.NewPointer(recvT)
		}
		sel := types.NewMethodSet(recvT).Lookup(pkg, method)
		if sel == nil {
			return nil, fmt.Errorf("%s: método %s não existe", line, method)
		}
		f.obj = sel.Obj().(*types.Func)
		f.recv = m.classify(recvT)
		if f.recv.k != kHandle {
			f.why = "receptor não é handle: " + f.recv.why
		}
	}
	sig := f.obj.Type().(*types.Signature)
	for i := 0; i < sig.Params().Len(); i++ {
		v := sig.Params().At(i)
		p := param{name: v.Name(), variadic: sig.Variadic() && i == sig.Params().Len()-1}
		p.t = m.classify(v.Type())
		if p.name == "" || p.name == "_" {
			p.name = paramName(p.t, i)
		}
		f.params = append(f.params, p)
	}
	if names, ok := paramNames[line]; ok && len(names) == len(f.params) {
		for i := range f.params {
			f.params[i].name = names[i]
		}
	}
	dedupParams(f.params)
	res, hasErr := splitErr(sig.Results())
	f.hasErr = hasErr
	for _, r := range res {
		f.results = append(f.results, m.classify(r))
	}
	m.check(f)
	return f, nil
}

// check decide se a função atravessa e se é assíncrona/stream.
func (m *model) check(f *fn) {
	fail := func(format string, a ...any) {
		if f.why == "" {
			f.why = fmt.Sprintf(format, a...)
		}
	}
	for _, p := range f.params {
		switch t := p.t; t.k {
		case kBasic, kBytes, kValue, kDTO, kHandle, kMap, kCtx, kWriter:
		case kSlice:
			if t.elem.k == kOpts || okElem(t.elem) {
				break
			}
			fail("parâmetro %s: %s", p.name, describe(t))
		case kChanSend:
			if f.stream != nil {
				fail("dois canais")
			}
			f.stream = t.elem
		default:
			fail("parâmetro %s: %s", p.name, describe(t))
		}
		if p.t.k == kCtx {
			f.async = true
		}
	}
	for i, r := range f.results {
		switch r.k {
		case kBasic, kBytes, kValue, kDTO, kSnap, kHandle, kSlice, kMap:
		case kChanRecv:
			if len(f.results) != 1 || f.stream != nil {
				fail("canal com outros resultados")
			}
			f.stream = r.elem
		default:
			fail("resultado %d: %s", i, describe(r))
		}
	}
	if f.stream != nil {
		if s := f.stream; !okElem(s) && s.k != kSnap {
			fail("canal de %s", describe(s))
		}
		if pc := chanParam(f); pc >= 0 && len(f.results) > 0 {
			fail("canal passado e resultados")
		}
		f.async = true
	}
	if forceAsync[f.key] {
		f.async = true
	}
}

func okElem(t *tinfo) bool {
	switch t.k {
	case kBasic, kBytes, kValue, kDTO, kSnap, kHandle, kSlice, kMap:
		return true
	}
	return false
}

func chanParam(f *fn) int {
	for i, p := range f.params {
		if p.t.k == kChanSend {
			return i
		}
	}
	return -1
}

func describe(t *tinfo) string {
	if t.why != "" {
		return t.why
	}
	return types.TypeString(t.t, nil)
}

func sortedKeys[V any](m map[string]V) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

// paramName: nome para parâmetro sem nome (as interfaces do kubo não nomeiam):
// ctx, o nome do tipo (path, node), opts ou out.
func paramName(t *tinfo, i int) string {
	switch {
	case t.k == kCtx:
		return "ctx"
	case t.k == kSlice && t.elem.k == kOpts:
		return "opts"
	case t.k == kChanSend:
		return "out"
	case t.k == kSlice && t.elem.named != nil: // []cid.Cid → cids, []Node → nodes
		return t.elem.named.Obj().Name() + "s"
	case t.named != nil:
		return t.named.Obj().Name()
	}
	return fmt.Sprintf("arg%d", i)
}

func dedupParams(ps []param) {
	seen := map[string]int{}
	for i := range ps {
		n := memberName(ps[i].name)
		if seen[n]++; seen[n] > 1 {
			ps[i].name = fmt.Sprintf("%s%d", ps[i].name, seen[n])
		}
	}
}
