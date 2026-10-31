// Command gen gera a ponte FFI do p2p_ffi a partir das raízes em
// gen/roots.txt (um símbolo Go por linha): go/zz_generated.go (os
// despachantes binários do p2p_host, WIRE.md), as libraries Dart em lib/ (uma por pacote Go, sem o
// prefixo github.com/<org>/) e o API.md (checklist Go → Dart com omissões).
//
// Uso, na pasta go/: go run ./gen [-check]
package main

import (
	"bytes"
	"flag"
	"fmt"
	"go/constant"
	"go/types"
	"hash/fnv"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"sort"
	"strconv"
	"strings"
	"unicode"

	"golang.org/x/tools/go/packages"
)

// paramNames: nomes para parâmetros que a interface do kubo não nomeia e que
// o tipo não explica (string, []byte), como na documentação do kubo.
var paramNames = map[string][]string{
	"github.com/ipfs/kubo/core/coreiface.PubSubAPI.Publish":            {"ctx", "topic", "data"},
	"github.com/ipfs/kubo/core/coreiface.PubSubAPI.Subscribe":          {"ctx", "topic", "opts"},
	"github.com/ipfs/kubo/core/coreiface.RoutingAPI.Get":               {"ctx", "key"},
	"github.com/ipfs/kubo/core/coreiface.RoutingAPI.Put":               {"ctx", "key", "value", "opts"},
	"github.com/ipfs/kubo/core/coreiface.ObjectAPI.Diff":               {"ctx", "before", "after"},
	"github.com/ipfs/boxo/ipld/unixfs/io.Directory.AddChild":           {"ctx", "name", "node"},
	"github.com/libp2p/go-libp2p/core/host.Host.SetStreamHandlerMatch": {"pid", "match", "handler"},
}

// cbArgNames: nomes dos argumentos de callbacks que o Go não nomeia, por
// raiz (os do Go, quando há, ficam).
var cbArgNames = map[string][]string{
	"github.com/ipld/go-car/v2/index.Index.GetAll":                                               {"offset"},
	"github.com/ipld/go-car/v2/index.IterableIndex.ForEach":                                      {"multihash", "offset"},
	"github.com/ipld/go-ipld-prime/traversal/selector/builder.SelectorSpecBuilder.ExploreFields": {"fields"},
}

// resultAs: functions that return an unexported type, and the exported
// interface (package, name) Dart sees it through.
var resultAs = map[string][2]string{
	"github.com/ipfs/boxo/ipld/merkledag.NewDAGService":             {"github.com/ipfs/go-ipld-format", "DAGService"},
	"github.com/libp2p/go-libp2p/p2p/discovery/mdns.NewMdnsService": {"github.com/libp2p/go-libp2p/p2p/discovery/mdns", "Service"},
}

// retainedFuncs: functions that keep the func they receive past the call
// (a handler): it becomes a retained callback (WIRE.md, "Retained
// callback"), called by Go for as long as it holds it.
var retainedFuncs = setOf(`github.com/libp2p/go-libp2p/core/host.Host.SetStreamHandler
github.com/libp2p/go-libp2p/core/host.Host.SetStreamHandlerMatch
github.com/libp2p/go-libp2p-pubsub.PubSub.RegisterTopicValidator`)

// anyAs: an `any` parameter that only accepts one Go type, by root and
// parameter index (the package reflects on it: pubsub takes a ValidatorEx as
// `val any`): it crosses as that type.
var anyAs = map[string]map[int][2]string{
	"github.com/libp2p/go-libp2p-pubsub.PubSub.RegisterTopicValidator": {1: {"github.com/libp2p/go-libp2p-pubsub", "ValidatorEx"}},
}

// forceAsync: funções sem context que bloqueiam (rede, desligamento). The
// pubsub methods wait on its event loop, which waits on Dart while it runs a
// subscription filter or a message ID function: synchronous, they would
// deadlock the isolate.
var forceAsync = setOf(`github.com/ipfs/kubo/core.IpfsNode.Close
github.com/libp2p/go-libp2p.New
github.com/libp2p/go-libp2p/core/host.Host.Close
github.com/libp2p/go-libp2p/core/network.Conn.Close
github.com/libp2p/go-libp2p/core/network.Stream.Read
github.com/libp2p/go-libp2p/core/network.Stream.Write
github.com/libp2p/go-libp2p/core/network.Stream.Close
github.com/libp2p/go-libp2p/core/network.Stream.CloseWrite
github.com/libp2p/go-libp2p-kad-dht.IpfsDHT.Close
github.com/libp2p/go-libp2p-pubsub.PubSub.Join
github.com/libp2p/go-libp2p-pubsub.PubSub.GetTopics
github.com/libp2p/go-libp2p-pubsub.PubSub.ListPeers
github.com/libp2p/go-libp2p-pubsub.PubSub.BlacklistPeer
github.com/libp2p/go-libp2p-pubsub.PubSub.AddDirectPeer
github.com/libp2p/go-libp2p-pubsub.PubSub.RemoveDirectPeer
github.com/libp2p/go-libp2p-pubsub.PubSub.RegisterTopicValidator
github.com/libp2p/go-libp2p-pubsub.PubSub.UnregisterTopicValidator
github.com/libp2p/go-libp2p-pubsub.Topic.Subscribe
github.com/libp2p/go-libp2p-pubsub.Topic.ListPeers
github.com/libp2p/go-libp2p-pubsub.Topic.EventHandler
github.com/libp2p/go-libp2p-pubsub.Topic.Close
github.com/libp2p/go-libp2p-pubsub.Subscription.Cancel
github.com/libp2p/go-libp2p-pubsub.TopicEventHandler.Cancel`)

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

	constLit string           // constante (obj *types.Const): o literal Dart; não vai ao host
	field    bool             // campo de struct num handle (obj é o *types.Var do campo)
	setter   bool             // field: a escrita (um parâmetro, sem resultado)
	cast     *tinfo           // type assertion do receptor (interface) para este handle concreto
	newT     bool             // construtor vazio de um tipo struct (raiz que é só o tipo): new(T)
	impl     *types.Interface // a root that is an interface type: a Dart implementation of it (params: one retained callback per method)
	outBuf   int              // índice do []byte que o Go preenche (Read, ReadAt, CtxReadFull); -1 = nenhum
	dropped  string           // a trailing variadic that does not cross, left out (Go gets none): its name and why
}

// outBufMethods: métodos no formato do io.Reader (o Go preenche o []byte e
// devolve quantos bytes): no Dart recebem o tamanho e devolvem os bytes lidos.
var outBufMethods = setOf(`Read ReadAt CtxReadFull`)

// firstID: os ids abaixo são do runtime e das funções escritas à mão (WIRE.md).
const firstID = 64

// assignIDs numera as funções expostas (sem as omitidas) em ordem de chave a
// partir de firstID e devolve o hash da tabela (FNV-1a de "id chave\n" por
// função), que o app e o host comparam no aperto de mão: os dois lados têm de
// vir do mesmo gerador.
func assignIDs(fns []*fn) uint64 {
	var live []*fn
	for _, f := range fns {
		if f.why == "" && f.constLit == "" { // constantes não vão ao host
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
	all, err := universe()
	if err != nil {
		return nil, err
	}
	lines = append(lines, all...)
	ignore, err := readRoots(filepath.Join(filepath.Dir(rootsFile), "ignore_roots.txt"))
	if err != nil && !os.IsNotExist(err) {
		return nil, err
	}
	expanded := map[string]bool{}
	if lines, err = expandRoots(lines, ignore, expanded); err != nil {
		return nil, err
	}
	pkgs, err := load(lines)
	if err != nil {
		return nil, err
	}
	m := newModel()
	m.expanded = expanded
	// the universe's packages too: a type of an ignored one (syscall) still
	// comes in through the others' signatures
	paths := sortedKeys(pkgs)
	for _, l := range all {
		if p := strings.TrimSuffix(l, ".*"); pkgs[p] == nil {
			paths = append(paths, p)
		}
	}
	if m.platform, m.platformObj, m.platformDecl, err = platformConsts(paths); err != nil {
		return nil, err
	}
	for _, k := range sortedKeys(m.platform) { // roots of their own: they go to the host
		if p, _, _ := splitRoot(k); pkgs[p] != nil && !slices.Contains(lines, k) { // not of an ignored package (runtime.GOARCH)
			lines = append(lines, k)
		}
	}
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
	// raiz que é só um tipo struct (bsadapter.Adapter): construtor vazio, e o
	// tipo é handle; marcado antes de qualquer classificação
	for _, line := range lines {
		if p, name, method := splitRoot(line); method == "" && pkgs[p] != nil {
			if tn, ok := pkgs[p].Scope().Lookup(name).(*types.TypeName); ok {
				if _, isStruct := tn.Type().Underlying().(*types.Struct); isStruct {
					m.newTypes[objKey(tn)] = true
				}
			}
		}
	}
	var fns []*fn
	for _, line := range lines {
		fs, err := m.resolve(pkgs, line)
		if err != nil && expanded[line] {
			fmt.Fprintln(os.Stderr, "skipped:", err)
			continue
		}
		if err != nil {
			return nil, err
		}
		fns = append(fns, fs...)
	}
	fns = append(fns, m.casts(fns)...)
	for _, f := range fns {
		if f.why == "" && m.platformDecl[f.key] {
			f.why = platformWhy
		}
	}
	m.leaveHand(fns)
	m.leaveCmdOutputs(fns, manualNames())
	if err := m.deprecations(fns); err != nil {
		return nil, err
	}
	if m.toks, err = m.tokens(); err != nil {
		return nil, err
	}
	for _, f := range fns {
		f.direct = -1
	}
	hash := assignIDs(fns) // WIRE.md: os emissores binários usam f.id e o hash
	out := map[string][]byte{}
	// os comandos do RPC entram nas libraries dos pacotes deles (as funções na
	// de core/commands, cada DTO na do seu pacote Go); o hash do Hello cobre o
	// esquema deles
	var cmdAPI, cmdSmoke string
	var cmdHash uint64
	dart, consts, errs := emitDart(m, fns, hash, func(de *dartEmitter) {
		cmdAPI, cmdSmoke, cmdHash = emitCommands(de, manualNames())
	})
	hf := fnv.New64a()
	fmt.Fprintf(hf, "%x %x", hash, cmdHash)
	for _, t := range m.toks { // the tokens' numbers are on the wire too
		fmt.Fprintf(hf, " %d %s", t.id, t.key)
	}
	for _, ge := range errs { // and the error classes' (WIRE.md, `error` event)
		fmt.Fprintf(hf, " e%d %s", ge.id, ge.key)
	}
	hash = hf.Sum64()
	dart["src/table.dart"] = tableDart(hash)
	goSrc, err := emitGo(m, fns, errs, hash)
	if err != nil {
		return nil, err
	}
	out["zz_generated.go"] = goSrc
	for path, src := range dart {
		out[filepath.ToSlash(filepath.Join("../lib", path))] = src
	}
	out["../API.md"] = append(append(emitAPI(m, append(fns, consts...)), errorsAPI(errs)...), cmdAPI...)
	out["../test/src/commands_smoke.dart"] = formatDart("../test/src/commands_smoke.dart", cmdSmoke)
	if err := checkPublicExports("../lib", out); err != nil {
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

// universe: a "pkg.*" root for every package of the host's build on all the
// targets (the generated code compiles for each; fuse is linux's alone), but
// the host's own module and the packages Go does not let another module
// import (under an `internal`, vendored). The generated code is left out of
// the build it looks at: what it imports came from the roots, not the host.
func universe() ([]string, error) {
	gen, err := filepath.Abs("zz_generated.go")
	if err != nil {
		return nil, err
	}
	on := map[string]int{} // package → on how many targets
	var host string
	for _, t := range targets {
		cgo := "0"
		if t[0] == "android" { // as tool/build.dart builds it (android/amd64 links only with cgo)
			cgo = "1"
		}
		cfg := &packages.Config{
			Mode:    packages.NeedName | packages.NeedImports | packages.NeedDeps,
			Env:     append(os.Environ(), "GOOS="+t[0], "GOARCH="+t[1], "CGO_ENABLED="+cgo),
			Overlay: map[string][]byte{gen: []byte("package main")},
		}
		list, err := packages.Load(cfg, ".")
		if err != nil {
			return nil, err
		}
		if len(list[0].Errors) > 0 {
			return nil, fmt.Errorf("universe on %s/%s: %v", t[0], t[1], list[0].Errors[0])
		}
		host = list[0].PkgPath
		packages.Visit(list, nil, func(p *packages.Package) { on[p.PkgPath]++ })
	}
	var out []string
	for _, p := range sortedKeys(on) {
		if on[p] == len(targets) && p != host && !strings.HasPrefix(p, host+"/") &&
			!strings.HasPrefix(p, "vendor/") && !slices.Contains(strings.Split(p, "/"), "internal") {
			out = append(out, p+".*")
		}
	}
	return out, nil
}

// expandRoots: a line "pkg.*" becomes every exported function, variable and
// method of the package (constants and errors already come with a library);
// a line it adds that matches a pattern of [ignore] ("*" matches anything) is
// dropped, an explicit one stays. The lines it adds are marked in [expanded].
func expandRoots(lines, ignore []string, expanded map[string]bool) ([]string, error) {
	var res []*regexp.Regexp
	for _, p := range ignore {
		res = append(res, regexp.MustCompile("^"+strings.ReplaceAll(regexp.QuoteMeta(p), `\*`, ".*")+"$"))
	}
	ignored := func(l string) bool {
		for _, re := range res {
			if re.MatchString(l) {
				return true
			}
		}
		return false
	}
	var wild []string
	for _, l := range lines {
		if strings.HasSuffix(l, ".*") {
			wild = append(wild, strings.TrimSuffix(l, ".*"))
		}
	}
	pkgs, err := loadPaths(wild)
	if err != nil {
		return nil, err
	}
	errIface := types.Universe.Lookup("error").Type().Underlying().(*types.Interface)
	// errValue: [f] takes or returns a concrete error type as a value
	// (corerepo.NewMultiError): in Dart an error is only an exception, and
	// the type stays its error class
	errValue := func(f *types.Func) bool {
		sig := f.Type().(*types.Signature)
		for _, tup := range []*types.Tuple{sig.Params(), sig.Results()} {
			for i := 0; i < tup.Len(); i++ {
				t := tup.At(i).Type()
				if p, ok := t.(*types.Pointer); ok {
					t = p.Elem()
				}
				if _, ok := t.(*types.Named); ok && !types.IsInterface(t) &&
					(types.Implements(t, errIface) || types.Implements(types.NewPointer(t), errIface)) {
					return true
				}
			}
		}
		return false
	}
	seen := map[string]bool{}
	var out []string
	explicit := map[string]bool{} // an explicit root wins over its "pkg.*", wherever it is
	for _, l := range lines {
		explicit[l] = true
	}
	add := func(l string, exp bool) {
		if !seen[l] && (explicit[l] || !ignored(l)) {
			seen[l] = true
			out = append(out, l)
			if exp && !explicit[l] {
				expanded[l] = true
			}
		}
	}
	for _, l := range lines {
		if !strings.HasSuffix(l, ".*") {
			add(l, false)
			continue
		}
		path := strings.TrimSuffix(l, ".*")
		sc := pkgs[path].Scope()
		for _, n := range sc.Names() {
			switch o := sc.Lookup(n).(type) {
			case *types.Func:
				if o.Exported() && o.Type().(*types.Signature).TypeParams() == nil && !errValue(o) {
					add(path+"."+n, true)
				}
			case *types.Var:
				// an error var is a sentinel: its error class (errors.go)
				if o.Exported() && !types.Implements(o.Type(), errIface) {
					add(path+"."+n, true)
				}
			case *types.TypeName:
				if !o.Exported() || o.IsAlias() {
					continue
				}
				if nt, ok := o.Type().(*types.Named); ok && nt.TypeParams() != nil {
					continue
				}
				if it, ok := o.Type().Underlying().(*types.Interface); ok {
					for i := 0; i < it.NumExplicitMethods(); i++ {
						if m := it.ExplicitMethod(i); m.Exported() && !errValue(m) {
							add(path+"."+n+"."+m.Name(), true)
						}
					}
					continue
				}
				// an error type is an error class (errors.go), its fields
				// included; its methods would make it a DTO
				if types.Implements(o.Type(), errIface) || types.Implements(types.NewPointer(o.Type()), errIface) {
					continue
				}
				ms := types.NewMethodSet(types.NewPointer(o.Type()))
				for i := 0; i < ms.Len(); i++ {
					if m := ms.At(i).Obj().(*types.Func); m.Exported() && m.Pkg() == o.Pkg() && !errValue(m) {
						add(path+"."+n+"."+m.Name(), true)
					}
				}
			}
		}
	}
	return out, nil
}

// splitRoot: "github.com/ipfs/kubo/core.IpfsNode.Close" → pacote, nome, método.
func splitRoot(line string) (pkg, name, method string) {
	slash := strings.LastIndex(line, "/")
	parts := strings.Split(line[slash+1:], ".")
	// a dot inside the path's last element (semconv/v1.26.0, yaml.v3): a root
	// names exported symbols, which start with a capital letter
	k := 1
	for k < len(parts) && parts[k] != "" && !unicode.IsUpper(rune(parts[k][0])) {
		k++
	}
	pkg = line[:slash+1] + strings.Join(parts[:k], ".")
	parts = parts[k-1:]
	if len(parts) > 1 {
		name = parts[1]
	}
	if len(parts) > 2 {
		method = parts[2]
	}
	return
}

// load carrega os pacotes das raízes como o build do p2p_host os vê (sem cgo).
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

// resolve: a linha [line] do roots.txt vira uma função (ou duas, num campo:
// leitura e escrita).
func (m *model) resolve(pkgs map[string]*types.Package, line string) ([]*fn, error) {
	pkgPath, name, method := splitRoot(line)
	pkg := pkgs[pkgPath]
	if pkg == nil || name == "" {
		return nil, fmt.Errorf("raiz inválida: %s", line)
	}
	obj := pkg.Scope().Lookup(name)
	if c, ok := m.platformObj[line]; ok && obj == nil { // a constant this machine's GOOS lacks (fuse/mount.AutomaticIno)
		obj = c
	}
	f := &fn{key: line, pkg: pkg, outBuf: -1}
	switch {
	case method == "":
		switch o := obj.(type) {
		case *types.Const: // constante: o valor vai direto no Dart
			f.obj = o
			f.results = []*tinfo{m.classify(o.Type())}
			if why, ok := m.platform[line]; ok { // its value depends on the target: the host's
				f.isVar, f.why = true, why
				f.results = []*tinfo{m.classify(types.Default(o.Type()))} // untyped rune → rune
				return []*fn{f}, nil
			}
			if f.constLit = dartConstLit(o); f.constLit == "" {
				f.why = "constant of type " + o.Type().String()
			}
			return []*fn{f}, nil
		case *types.Func:
			f.obj = o
		case *types.Var: // variável de pacote: getter sem parâmetros
			f.obj, f.isVar = o, true
			t := o.Type()
			// func sem nome (NilRouterOption = constructNilRouting) idêntica a um
			// tipo nomeado do pacote (RoutingOption) ou de um que ele importa
			// (bsfetcher.DefaultPrototypeChooser → traversal.LinkTargetNodePrototypeChooser):
			// usa o tipo nomeado.
			if _, unnamed := t.(*types.Signature); unnamed {
				if n := namedFunc(append([]*types.Package{pkg}, pkg.Imports()...), t); n != nil {
					t, f.conv = n, n
				}
			}
			f.results = []*tinfo{m.classify(t)}
			m.check(f)
			return []*fn{f}, nil
		case *types.TypeName:
			if iface, ok := o.Type().Underlying().(*types.Interface); ok {
				return []*fn{m.implRoot(f, o, iface)}, nil
			}
			if !m.newTypes[objKey(o)] {
				return nil, fmt.Errorf("%s: só tipo struct vira construtor", line)
			}
			// new(T): o construtor vazio (o Dart o vê como factory T())
			pt := types.NewPointer(o.Type())
			sig := types.NewSignatureType(nil, nil, nil, nil, types.NewTuple(types.NewVar(0, pkg, "", pt)), false)
			f.obj, f.newT = types.NewFunc(0, pkg, "New"+o.Name(), sig), true
			f.results = []*tinfo{m.classify(pt)}
			m.check(f)
			return []*fn{f}, nil
		default:
			return nil, fmt.Errorf("%s não é função, variável, constante nem tipo", line)
		}
	default:
		tn, ok := obj.(*types.TypeName)
		if !ok {
			return nil, fmt.Errorf("%s: %s não é tipo", line, name)
		}
		recvT := tn.Type()
		// a value type (cid.Cid.Version) is the receiver itself, by value
		if _, isVal := valueTypes[objKey(tn)]; !isVal && !types.IsInterface(recvT) {
			recvT = types.NewPointer(recvT)
		}
		sel, _, _ := types.LookupFieldOrMethod(recvT, true, pkg, method)
		if v, ok := sel.(*types.Var); ok && v.IsField() && v.Exported() {
			return m.fieldRoot(line, pkg, recvT, v), nil
		}
		fobj, ok := sel.(*types.Func)
		if !ok {
			return nil, fmt.Errorf("%s: método ou campo %s não existe", line, method)
		}
		f.obj = fobj
		f.recv = m.classify(recvT)
		// receptor DTO (car.Header.HasIndex, cid.Prefix.Sum): vai por valor, e
		// um método que o altera não volta ao Dart; a value type with a Dart
		// class (cid.Cid.Version) goes as its string
		isVal := f.recv.k == kValue && f.recv.val.dartClass != "" && !f.recv.val.json
		if f.recv.k != kHandle && f.recv.k != kDTO && !isVal {
			f.why = "receiver is neither a handle, a DTO nor a value type: " + f.recv.why
		}
	}
	sig := f.obj.Type().(*types.Signature)
	for i := 0; i < sig.Params().Len(); i++ {
		v := sig.Params().At(i)
		p := param{name: v.Name(), variadic: sig.Variadic() && i == sig.Params().Len()-1}
		vt := v.Type()
		if as, ok := anyAs[line][i]; ok {
			if pk := m.load(as[0]); pk != nil {
				if tn, ok := pk.Scope().Lookup(as[1]).(*types.TypeName); ok {
					vt = tn.Type()
				}
			}
		}
		p.t = m.classify(vt)
		if p.t.k != kOpts {
			// a "pkg.*" root nobody checked: called during the call or kept
			// for later? A retained callback that Go waits on serves both
			unchecked := m.expanded[line] && !retainedFuncs[line]
			if ft := m.funcParam(vt); ft != nil && (ft.fret != fretVal || retainedFuncs[line] || unchecked) {
				ft.retained = retainedFuncs[line] || unchecked
				ft.unchecked = unchecked
				p.t = ft
				if names := cbArgNames[line]; len(names) == len(ft.fnames) {
					ft.fnames = names
				}
			}
		}
		if p.name == "" || p.name == "_" {
			p.name = paramName(p.t, i)
		}
		if p.variadic && p.t.k == kUnsupported { // Go gets none (event.Bus.Subscribe's opts)
			f.dropped = p.name + ": " + p.t.why
			continue
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
	// a result of an unexported type (merkledag's *dagService): Dart sees it
	// through the exported interface in the table; on the wire it is the
	// object's handle
	if ra, ok := resultAs[line]; ok && len(f.results) == 1 {
		if p := m.load(ra[0]); p != nil {
			if tn, ok := p.Scope().Lookup(ra[1]).(*types.TypeName); ok {
				f.results[0] = m.classify(tn.Type())
			}
		}
	}
	markOutBuf(f)
	m.check(f)
	return []*fn{f}, nil
}

// namedFunc: o primeiro tipo nomeado exportado de [pkgs] cujo tipo é a
// assinatura [sig].
func namedFunc(pkgs []*types.Package, sig types.Type) types.Type {
	for _, p := range pkgs {
		for _, n := range p.Scope().Names() {
			if tn, ok := p.Scope().Lookup(n).(*types.TypeName); ok && tn.Exported() && types.Identical(tn.Type().Underlying(), sig) {
				return tn.Type()
			}
		}
	}
	return nil
}

// markOutBuf: método no formato do io.Reader (um []byte e o resultado
// `(int, error)`): o []byte é de saída (WIRE.md, "Value encoding").
func markOutBuf(f *fn) {
	if f.recv == nil || !outBufMethods[f.obj.Name()] || !f.hasErr || len(f.results) != 1 || f.results[0].k != kBasic {
		return
	}
	idx := -1
	for i, p := range f.params {
		if p.t.k == kBytes {
			if idx >= 0 {
				return
			}
			idx = i
		}
	}
	if idx >= 0 {
		f.outBuf = idx
		f.params[idx].name = "n"
	}
}

// fieldRoot: um campo exportado de struct num handle: a leitura e, se o tipo
// atravessa como parâmetro, a escrita (a mesma linha com "=").
func (m *model) fieldRoot(line string, pkg *types.Package, recvT types.Type, v *types.Var) []*fn {
	recv := m.classify(recvT)
	ft := m.classify(v.Type())
	get := &fn{key: line, pkg: pkg, obj: v, field: true, recv: recv, results: []*tinfo{ft}, outBuf: -1}
	if recv.k != kHandle {
		get.why = "receiver is not a handle: " + recv.why
	}
	m.check(get)
	set := &fn{key: line + "=", pkg: pkg, obj: v, field: true, setter: true, recv: recv,
		params: []param{{name: dartParamName(v.Name()), t: ft}}, outBuf: -1}
	set.why = get.why
	m.check(set)
	if set.why != "" {
		return []*fn{get}
	}
	return []*fn{get, set}
}

// casts: para cada interface handle usada e cada handle concreto usado que a
// implementa, a type assertion (`asBoxoMfsDirectory()` no Dart, `v.(*mfs.Directory)`
// no Go).
func (m *model) casts(fns []*fn) []*fn {
	used := map[string]*tinfo{}
	var walk func(t *tinfo)
	walk = func(t *tinfo) {
		if t == nil || used[t.key] != nil {
			return
		}
		used[t.key] = t
		walk(t.elem)
		walk(t.mkey)
		for _, a := range t.fargs {
			walk(a)
		}
		for _, fd := range t.fields {
			walk(fd.t)
		}
		for _, g := range t.gets {
			walk(g.t)
		}
	}
	for _, f := range fns {
		if f.why != "" {
			continue
		}
		walk(f.recv)
		walk(f.stream)
		for _, p := range f.params {
			walk(p.t)
		}
		for _, r := range f.results {
			walk(r)
		}
	}
	var ifaces, concretes []*tinfo
	for _, k := range sortedKeys(used) {
		t := used[k]
		if t.k != kHandle || t.reader || t.named == nil {
			continue
		}
		if types.IsInterface(t.named) {
			ifaces = append(ifaces, t)
		} else {
			concretes = append(concretes, t)
		}
	}
	var out []*fn
	for _, i := range ifaces {
		it := i.named.Underlying().(*types.Interface)
		if it.NumMethods() == 0 { // crypto.PrivateKey is an `any`: every type would be a cast
			continue
		}
		named := map[string]bool{} // T and *T are one Dart class: one cast
		// e para as interfaces que embutem esta (index.Index →
		// index.IterableIndex): o `x.(Maior)` do Go; entre interfaces sem
		// relação, não (seria um cast para cada par)
		targets := concretes
		for _, j := range ifaces {
			if j != i && embeds(j.named, i.named) {
				targets = append(targets, j)
			}
		}
		for _, c := range targets {
			if !types.IsInterface(c.named) && !types.Implements(c.t, it) {
				continue
			}
			// named after the Dart class, unique by construction: two types of
			// the same Go name (noise.Transport, tls.Transport) never collide
			name := "As" + className(m, c)
			if named[name] {
				continue
			}
			named[name] = true
			sig := types.NewSignatureType(nil, nil, nil, nil, types.NewTuple(types.NewVar(0, nil, "", c.t)), false)
			out = append(out, &fn{key: "cast " + i.key + " " + c.key, pkg: i.named.Obj().Pkg(),
				obj: types.NewFunc(0, i.named.Obj().Pkg(), name, sig), recv: i, results: []*tinfo{c}, cast: c, outBuf: -1})
		}
	}
	return out
}

// embeds: a interface [outer] embute [inner], direta ou indiretamente.
func embeds(outer, inner *types.Named) bool {
	u, ok := outer.Underlying().(*types.Interface)
	if !ok {
		return false
	}
	for k := 0; k < u.NumEmbeddeds(); k++ {
		if e, ok := types.Unalias(u.EmbeddedType(k)).(*types.Named); ok && (e.Obj() == inner.Obj() || embeds(e, inner)) {
			return true
		}
	}
	return false
}

// dartConstLit: o literal Dart de uma constante Go de tipo básico.
func dartConstLit(c *types.Const) string {
	v := c.Val()
	// time.Duration (nanossegundos) vira o Duration do Dart, que guarda
	// microssegundos: o resto abaixo de 1 µs se perde
	if n, ok := c.Type().(*types.Named); ok && n.Obj().Pkg() != nil && n.Obj().Pkg().Path() == "time" && n.Obj().Name() == "Duration" {
		if i, ok := constant.Int64Val(v); ok {
			return fmt.Sprintf("Duration(microseconds: %d)", i/1000)
		}
		return ""
	}
	switch v.Kind() {
	case constant.Bool:
		return strconv.FormatBool(constant.BoolVal(v))
	case constant.Int:
		if i, ok := constant.Int64Val(v); ok {
			return strconv.FormatInt(i, 10)
		}
	case constant.Float:
		f, _ := constant.Float64Val(v)
		s := strconv.FormatFloat(f, 'g', -1, 64)
		if !strings.ContainsAny(s, ".eEn") {
			s += ".0"
		}
		return s
	case constant.String:
		return strings.ReplaceAll(strconv.Quote(constant.StringVal(v)), "$", `\$`)
	}
	return ""
}

// check decide se a função atravessa e se é assíncrona/stream.
func (m *model) check(f *fn) {
	fail := func(format string, a ...any) {
		if f.why == "" {
			f.why = fmt.Sprintf(format, a...)
		}
	}
	for i, p := range f.params {
		switch t := p.t; t.k {
		case kBasic, kBytes, kValue, kHandle, kCtx, kWriter, kAny:
		case kDTO, kSnap, kMap: // Go decodes options only as the variadic itself
			if !decodable(t) {
				fail("parameter %s: %s with an option inside", p.name, describe(t))
			}
		case kSlice:
			if t.elem.k == kOpts || decodable(t) {
				break
			}
			fail("parameter %s: %s", p.name, describe(t))
		case kChanSend:
			if f.stream != nil {
				fail("two channels")
			}
			f.stream = t.elem
		case kFunc: // callback sob demanda: a chamada espera o Dart consumir
			if t.retained { // kept by Go: invoked later, not during the call
				f.async = f.async || t.unchecked // or during it: Dart must be free to run it
				break
			}
			if funcParamIdx(f) != i {
				fail("two callbacks")
			}
			f.async = true
		default:
			fail("parameter %s: %s", p.name, describe(t))
		}
		if p.t.k == kCtx {
			f.async = true
		}
	}
	for i, r := range f.results {
		switch r.k {
		case kBasic, kBytes, kValue, kHandle, kAny:
		case kSlice, kMap, kDTO, kSnap: // what comes back has to decode, all the way down
			if !decodable(r) {
				fail("result %d: %s", i, describe(r))
			}
		case kChanRecv:
			if len(f.results) != 1 || f.stream != nil {
				fail("channel with other results")
			}
			f.stream = r.elem
		default:
			fail("result %d: %s", i, describe(r))
		}
	}
	if f.stream != nil && funcParamIdx(f) >= 0 {
		fail("channel and callback")
	}
	if f.stream != nil {
		if s := f.stream; !okElem(s) && s.k != kSnap {
			fail("channel of %s", describe(s))
		}
		if pc := chanParam(f); pc >= 0 && len(f.results) > 0 {
			fail("channel passed and results")
		}
		f.async = true
	}
	if forceAsync[f.key] {
		f.async = true
	}
}

// decodable: a result Dart can decode (a slice of options, or a DTO with
// one in a field, cannot).
func decodable(t *tinfo) bool { return decodableIn(t, map[*tinfo]bool{}) }

func decodableIn(t *tinfo, seen map[*tinfo]bool) bool {
	if seen[t] {
		return true
	}
	seen[t] = true
	switch t.k {
	case kSlice:
		return decodableIn(t.elem, seen)
	case kMap:
		return decodableIn(t.elem, seen) && (t.mkey == nil || decodableIn(t.mkey, seen))
	case kDTO, kSnap:
		for _, f := range t.fields {
			if f.skipped == "" && !decodableIn(f.t, seen) {
				return false
			}
		}
		for _, g := range t.gets {
			if !decodableIn(g.t, seen) {
				return false
			}
		}
		return true
	case kError:
		return true
	}
	return okElem(t)
}

func okElem(t *tinfo) bool {
	switch t.k {
	case kBasic, kBytes, kValue, kDTO, kSnap, kHandle, kSlice, kMap, kAny:
		return true
	}
	return false
}

// funcParamIdx: o índice do primeiro parâmetro callback (kFunc), ou -1.
func funcParamIdx(f *fn) int {
	for i, p := range f.params {
		if p.t.k == kFunc && !p.t.retained {
			return i
		}
	}
	return -1
}

// implRoot: a root that is an interface type (mdns.Notifee): Dart implements
// it with one function per method, each a retained callback; the Dart
// factory builds the Go object (a struct of the generator) that calls them.
func (m *model) implRoot(f *fn, tn *types.TypeName, iface *types.Interface) *fn {
	it := m.classify(tn.Type())
	sig := types.NewSignatureType(nil, nil, nil, nil, types.NewTuple(types.NewVar(0, f.pkg, "", tn.Type())), false)
	f.obj, f.impl, f.results = types.NewFunc(0, f.pkg, "New"+tn.Name(), sig), iface, []*tinfo{it}
	if it.k != kHandle {
		f.why = "interface is not a handle: " + describe(it)
	}
	for i := 0; i < iface.NumMethods(); i++ {
		meth := iface.Method(i)
		ft := m.funcParam(meth.Type())
		switch {
		case !meth.Exported():
			f.why = "unexported method " + meth.Name()
		case ft == nil:
			f.why = "method " + meth.Name() + ": results other than nothing, bool or error"
		case ft.k == kUnsupported:
			f.why = "method " + meth.Name() + ": " + ft.why
		}
		if f.why != "" {
			break
		}
		ft.retained = true
		f.params = append(f.params, param{name: meth.Name(), t: ft})
	}
	m.check(f)
	return f
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
	case t.k == kFunc:
		return "callback"
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
		n := dartParamName(ps[i].name)
		if seen[n]++; seen[n] > 1 {
			ps[i].name = fmt.Sprintf("%s%d", ps[i].name, seen[n])
		}
	}
}
