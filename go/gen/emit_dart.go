package main

import (
	"bytes"
	"fmt"
	"go/types"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
)

type dartLib struct {
	path    string
	goPath  string
	prefix  map[string]string // library importada → prefixo
	classes map[string]*dclass
	funcs   []*fn
	extra   []string // código de outro emissor (os DTOs dos comandos, as classes de erro)
	members []string // the namespace's members (commands, function tokens): in the library's extension
	bytes   bool     // usa Uint8List
	async   bool     // usa StreamSink (dart:async)
	ns      bool     // has members: an extension on its namespace class (lib/src/go.dart)
	layers  []string // the layers it has (consts, enums, options): an extension on each
}

type dclass struct {
	t         *tinfo
	methods   []*fn
	factories []*fn
	token     int // tokens.go: the type's token (static const $type); 0 = none
	// mixins: the other exposed interfaces Go accepts this type as, besides
	// its base class's chain (linkMixins); mixed in and implemented
	mixins []*dclass
}

type dartEmitter struct {
	m           *model
	libs        map[string]*dartLib
	paramIfaces map[string]bool // interfaces usadas como parâmetro (linkConcrete)
	ifaces      []*dclass       // the interfaces a handle can extend or mix in (linkConcrete)
	optIfaces   map[string]bool // interfaces only an option constructor takes: the last choice of linkConcrete
}

func (e *dartEmitter) lib(goPath string) *dartLib {
	path := dartPath(goPath)
	l, ok := e.libs[path]
	if !ok {
		l = &dartLib{path: path, goPath: goPath, prefix: map[string]string{}, classes: map[string]*dclass{}}
		e.libs[path] = l
	} else if l.goPath != goPath {
		panic(fmt.Sprintf("gen: %s e %s caem na mesma library %s", l.goPath, goPath, path))
	}
	return l
}

func classKey(t *tinfo) string { return objKey(t.named.Obj()) }

// collect registra as classes alcançáveis a partir de [t].
func (e *dartEmitter) collect(t *tinfo) {
	if t == nil {
		return
	}
	switch t.k {
	case kSlice, kMap, kChanSend, kChanRecv:
		e.collect(t.elem)
		return
	case kFunc:
		for _, a := range t.fargs {
			e.collect(a)
		}
		return
	case kValue:
		if t.val.dartClass == "" {
			return
		}
	case kDTO, kSnap, kHandle, kOpts:
	default:
		return
	}
	l := e.lib(e.m.home(t.named.Obj().Pkg()).Path())
	if _, ok := l.classes[classKey(t)]; ok {
		return
	}
	plain := *t
	plain.ptr = false
	l.classes[classKey(t)] = &dclass{t: &plain}
	for _, f := range t.fields {
		if f.skipped == "" {
			e.collect(f.t)
		}
	}
	for _, g := range t.gets {
		e.collect(g.t)
	}
	e.collect(t.super)
	for _, c := range usableCtors(t) {
		e.lib(e.m.home(c.pkg).Path()) // the constructors live in their package's library
		for _, p := range c.params {
			e.collect(p)
			if p.k == kHandle && p.named != nil && types.IsInterface(p.named) { // libp2p.Muxer's network.Multiplexer
				e.optIfaces[classKey(p)] = true
			}
		}
	}
	if t.val.dartExtend != "" { // ImmutablePath extends Path: a base vem junto
		for k, ti := range e.m.types {
			if ti.k == kValue && ti.val.dartClass == t.val.dartExtend && !ti.ptr && strings.HasPrefix(k, t.named.Obj().Pkg().Path()) {
				e.collect(ti)
			}
		}
	}
}

// emitDart: as libraries de [fns]; [more] acrescenta código às libraries dos
// pacotes (os comandos do RPC e os DTOs deles) antes de serem escritas. Devolve
// também as constantes que entraram sozinhas (consts), para o API.md.
func emitDart(m *model, fns []*fn, hash uint64, more func(*dartEmitter)) (map[string][]byte, []*fn, []*goError) {
	e := &dartEmitter{m: m, libs: map[string]*dartLib{}, paramIfaces: map[string]bool{}, optIfaces: map[string]bool{}}
	for _, f := range fns {
		if f.why != "" {
			continue
		}
		e.collect(f.recv)
		for _, p := range f.params {
			e.collect(p.t)
			if p.t.k == kHandle && p.t.named != nil && types.IsInterface(p.t.named) {
				e.paramIfaces[classKey(p.t)] = true
			}
		}
		for _, r := range f.results {
			e.collect(r)
		}
		e.collect(f.stream)
		switch {
		case f.recv != nil:
			// the class lives in its home library (an alias's package)
			c := e.lib(e.m.home(f.recv.named.Obj().Pkg()).Path()).classes[classKey(f.recv)]
			c.methods = append(c.methods, f)
		case isFactory(f):
			c := e.lib(f.pkg.Path()).classes[classKey(f.results[0])]
			c.factories = append(c.factories, f)
		default:
			l := e.lib(f.pkg.Path())
			l.funcs = append(l.funcs, f)
		}
	}
	var classes [][2]string
	for _, l := range e.libs {
		for _, c := range l.classes {
			classes = append(classes, [2]string{l.path, classGoName(c.t)})
		}
	}
	markClasses(classes)
	e.linkInterfaces()
	e.linkConcrete()
	e.linkMixins()
	e.alignOverrides()
	anyTypes := e.tokens()
	if more != nil {
		more(e)
	}
	consts := e.constants()
	errs := e.errorClasses()
	errorTypes := e.emitErrorClasses(errs)
	out := map[string][]byte{}
	for path, l := range e.libs {
		// o pacote já tem uma library escrita à mão (o porte do `ipfs dag`): o
		// gerado vai num part dela, para o pacote Go seguir com uma library só
		if hand, err := os.ReadFile(filepath.Join("..", "lib", path)); err == nil && !bytes.HasPrefix(hand, []byte(generatedHeader)) {
			part, src := e.emitPart(l, hand)
			out[part] = formatDart(part, src)
			continue
		}
		src := e.emitLib(l)
		// Código escrito à mão que o gerador não exprime (ex. config.Profiles).
		if extra, err := os.ReadFile(filepath.Join("gen", "extra", path+".extra")); err == nil {
			src += "\n" + string(extra)
		}
		out[path] = formatDart(path, src)
	}
	tree, err := goTree(publicLibs(out), e.goPaths(), runtimeNames())
	if err != nil {
		panic("gen: " + err.Error())
	}
	out["src/go.dart"] = tree
	out["src/any_types.dart"] = formatDart("src/any_types.dart", anyTypes)
	out["src/error_types.dart"] = formatDart("src/error_types.dart", errorTypes)
	// O hash da tabela vai no Hello do P2pService (WIRE.md): app e host têm de
	// vir do mesmo gerador.
	out["src/table.dart"] = tableDart(hash)
	return out, consts, errs
}

// publicLibs: every library under lib/go/ (relative to lib/) → its source:
// the generated ones in [out] and the hand-written ones, each with its
// generated part.
func publicLibs(out map[string][]byte) map[string][]byte {
	libs := map[string][]byte{}
	for path, src := range out {
		if strings.HasPrefix(path, "go/") && !strings.HasSuffix(path, ".g.dart") {
			libs[path] = src
		}
	}
	_ = filepath.WalkDir("../lib/go", func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(p, ".dart") || strings.HasSuffix(p, ".g.dart") {
			return err
		}
		rel := filepath.ToSlash(strings.TrimPrefix(p, filepath.Clean("../lib")+string(filepath.Separator)))
		if _, ok := libs[rel]; ok {
			return nil
		}
		src, err := os.ReadFile(p)
		if err != nil || bytes.HasPrefix(src, []byte(generatedHeader)) { // a stale generated one
			return err
		}
		libs[rel] = append(src, out[strings.TrimSuffix(rel, ".dart")+".g.dart"]...)
		return nil
	})
	return libs
}

// goPaths: the Go package of each library.
func (e *dartEmitter) goPaths() map[string]string {
	m := map[string]string{}
	for path, l := range e.libs {
		m[path] = l.goPath
	}
	return m
}

// runtimeNames: what lib/p2p_ffi.dart exports from lib/src/ (its `show` lists).
func runtimeNames() []string {
	src, err := os.ReadFile("../lib/" + dartPkg + ".dart")
	if err != nil {
		panic("gen: " + err.Error())
	}
	var out []string
	for _, m := range regexp.MustCompile(`(?s)\bshow\s+([^;]*);`).FindAllSubmatch(src, -1) {
		for _, n := range strings.Split(string(m[1]), ",") {
			out = append(out, strings.TrimSpace(n))
		}
	}
	return out
}

// tokens: the classes of the type tokens get `static const $type`, the
// function tokens a `<name>Func` constant in their library (tokens.go);
// returns src/any_types.dart, the decoders of the types a dynamic value
// carries (WIRE.md, tag 8), which the runtime imports.
func (e *dartEmitter) tokens() string {
	src := &dartLib{path: "src/any_types.dart", prefix: map[string]string{}, classes: map[string]*dclass{}}
	var decs []string
	for _, t := range e.m.toks {
		if t.fn != nil {
			l := e.lib(t.fn.Pkg().Path())
			l.members = append(l.members, fmt.Sprintf("/// Go: the function `%s.%s` as a value (a token: Go gets the function\n/// itself, as in `libp2p.Transport(tcp.NewTCPTransport)`).\nGoToken get %sFunc => const GoToken(%d);\n",
				t.fn.Pkg().Name(), t.fn.Name(), strings.TrimSuffix(memberName(t.fn.Name()), "$"), t.id))
			continue
		}
		e.collect(t.t)
		e.lib(e.m.home(t.t.named.Obj().Pkg()).Path()).classes[classKey(t.t)].token = t.id
		decs = append(decs, fmt.Sprintf("  %d: (r) => %s,", t.id, e.dec(t.t, "r", src, true)))
	}
	var b strings.Builder
	b.WriteString("// Generated by go/gen from go/gen/tokens.go; do not edit.\n\n/// The decoders of the types a Go dynamic value carries (WIRE.md, tag 8), by\n/// token.\nlibrary;\n\n")
	b.WriteString("import '" + pkgPrefix + "src/runtime.dart';\n")
	for _, uri := range sortedKeys(src.prefix) {
		fmt.Fprintf(&b, "import '%s' as %s;\n", uri, src.prefix[uri])
	}
	fmt.Fprintf(&b, "\nfinal $anyTypes = <int, Object? Function($R r)>{\n%s\n};\n", strings.Join(decs, "\n"))
	return b.String()
}

// constants: toda constante exportada de tipo básico do pacote de cada library
// entra nela sozinha (sem linha no roots.txt): é só um `const` no Dart, que não
// vai ao host. A que não tem literal Dart, ou cujo nome Dart já é de outro
// membro da library, fica de fora com o motivo (API.md).
func (e *dartEmitter) constants() []*fn {
	var out []*fn
	for _, path := range sortedKeys(e.libs) {
		l := e.libs[path]
		pkg := e.m.load(l.goPath)
		if pkg == nil {
			continue
		}
		taken, rooted := map[string]bool{}, map[string]bool{}
		for _, f := range l.funcs {
			taken[memberName(f.obj.Name())] = true
			rooted[f.key] = true
		}
		for _, name := range pkg.Scope().Names() {
			c, ok := pkg.Scope().Lookup(name).(*types.Const)
			if !ok || !c.Exported() || rooted[l.goPath+"."+name] {
				continue
			}
			f := &fn{key: l.goPath + "." + name, pkg: pkg, obj: c, outBuf: -1, constLit: dartConstLit(c)}
			n := memberName(name)
			switch {
			case f.constLit == "":
				f.why = "constant of type " + c.Type().String()
			case taken[n]:
				f.why = "constant whose Dart name `" + n + "` another member of the library has"
			default:
				taken[n] = true
				l.funcs = append(l.funcs, f)
			}
			out = append(out, f)
		}
	}
	return out
}

// tableDart: o hash da tabela no Dart (o mesmo do zz_generated.go).
func tableDart(hash uint64) []byte {
	return formatDart("src/table.dart", fmt.Sprintf(`// Generated by go/gen from go/gen/roots.txt; do not edit.

/// Hash of the generated function table (FNV-1a 64 of "id key" per line, one
/// per function) and of the kubo command schema (WIRE.md): sent in the Hello
/// right after connecting to the p2p_host.
const p2pTableHash = 0x%016x;
`, hash))
}

var (
	langOnce sync.Once
	langVer  string
)

// languageVersion: a versão mínima do SDK no pubspec.yaml (`sdk: ^3.5.0` →
// 3.5). Passada ao dart format: sem ela, ele a procura pelo pacote a partir do
// caminho, e num arquivo novo (pasta ainda inexistente) não acha e formata no
// estilo da versão mais nova.
func languageVersion() string {
	langOnce.Do(func() {
		src, err := os.ReadFile("../pubspec.yaml")
		m := regexp.MustCompile(`(?m)^\s*sdk:\s*["']?\^?(\d+\.\d+)`).FindSubmatch(src)
		if err != nil || m == nil {
			panic("gen: sem a versão do SDK no pubspec.yaml")
		}
		langVer = string(m[1])
	})
	return langVer
}

// formatDart passa a library pelo dart format (estilo da versão do pubspec).
func formatDart(path, src string) []byte {
	cmd := exec.Command("dart", "format", "--output=show", "--language-version="+languageVersion(), "--stdin-name=lib/"+path)
	cmd.Dir = ".."
	cmd.Stdin = strings.NewReader(src)
	var out, errb bytes.Buffer
	cmd.Stdout, cmd.Stderr = &out, &errb
	if err := cmd.Run(); err != nil {
		panic(fmt.Sprintf("gen: dart format %s: %v\n%s\n%s", path, err, errb.String(), src))
	}
	return out.Bytes()
}

// isFactory: NewX síncrono que devolve o handle X do mesmo pacote vira
// `factory X(...)`.
func isFactory(f *fn) bool {
	if f.async || len(f.results) != 1 {
		return false
	}
	r := f.results[0]
	// DTO não: o construtor dele é o dos campos (car.NewHeader fica função)
	if r.k != kHandle || r.named == nil || r.reader {
		return false
	}
	return r.named.Obj().Pkg() == f.pkg && f.obj.Name() == "New"+r.named.Obj().Name()
}

// ref: nome (qualificado, se de outra library) da classe de [t].
func (e *dartEmitter) ref(t *tinfo, from *dartLib) string {
	name := className(e.m, t)
	l := e.lib(e.m.home(t.named.Obj().Pkg()).Path())
	if l == from {
		return name
	}
	return e.imp(from, pkgPrefix+l.path) + "." + name
}

func (e *dartEmitter) imp(from *dartLib, uri string) string {
	if p, ok := from.prefix[uri]; ok {
		return p
	}
	base := uri[strings.LastIndex(uri, "/")+1:]
	base = "$" + strings.TrimSuffix(base, ".dart")
	p := base
	for i := 2; ; i++ {
		taken := false
		for _, q := range from.prefix {
			taken = taken || q == p
		}
		if !taken {
			break
		}
		p = fmt.Sprintf("%s%d", base, i)
	}
	from.prefix[uri] = p
	return p
}

// className: the Dart class of [t], named after its library (qualType).
func className(m *model, t *tinfo) string {
	return qualType(dartPath(m.home(t.named.Obj().Pkg()).Path()), classGoName(t))
}

// classGoName: the Go name a class is named after.
func classGoName(t *tinfo) string {
	if t.k == kValue {
		return t.val.dartClass
	}
	return t.named.Obj().Name()
}

func basicDart(t *tinfo) string {
	tt := t.t
	if p, ok := tt.(*types.Pointer); ok { // *int64: o tipo do básico
		tt = p.Elem()
	}
	b := tt.Underlying().(*types.Basic)
	switch {
	case t.dur:
		return "Duration"
	case b.Info()&types.IsBoolean != 0:
		return "bool"
	case b.Info()&types.IsInteger != 0:
		return "int"
	case b.Info()&types.IsFloat != 0:
		return "double"
	}
	return "String"
}

// dt: tipo Dart de [t] vista de [from].
func (e *dartEmitter) dt(t *tinfo, from *dartLib) string {
	switch t.k {
	case kBasic:
		return basicDart(t)
	case kError:
		return "String" // a mensagem; null = sem erro
	case kBytes:
		from.bytes = true
		return "Uint8List"
	case kValue:
		if t.val.dartClass == "" {
			return "DateTime"
		}
		return e.ref(t, from)
	case kHandle, kDTO, kSnap, kOpts:
		return e.ref(t, from)
	case kSlice:
		return "List<" + e.dt(t.elem, from) + ">"
	case kMap:
		key := "String"
		if t.mkey != nil {
			key = e.dt(t.mkey, from)
		}
		return "Map<" + key + ", " + e.dt(t.elem, from) + ">"
	case kCtx:
		return e.imp(from, pkgPrefix+"go/context.dart") + ".Context"
	case kChanSend, kChanRecv:
		return "Stream<" + e.dt(t.elem, from) + ">"
	case kAny:
		return "Object?"
	}
	panic("gen: sem tipo Dart para " + t.key)
}

func nullable(t *tinfo) bool {
	if t.k == kBasic {
		return t.ptr // *int64: null = nil
	}
	switch t.k {
	case kValue, kDTO, kSnap, kHandle, kBytes, kError:
		return true
	}
	return false
}

// enc: a chamada do escritor ($W do runtime) que codifica [x] do tipo [t]
// como no WIRE.md, sem o receptor (`str(x)`, `list(x, ...)`): quem chama põe
// `..` (cascata) ou `w.` na frente. Elementos de lista e de mapa vão por
// closures (w<n>, e<n>) que recebem o mesmo escritor.
func (e *dartEmitter) enc(t *tinfo, x string, depth int) string {
	if t.k == kBasic && t.ptr { // *int64: presença + o básico
		in := *t
		in.ptr = false
		w, v := fmt.Sprintf("w%d", depth), fmt.Sprintf("v%d", depth)
		return fmt.Sprintf("ptr(%s, (%s, %s) => %s.%s)", x, w, v, w, e.enc(&in, v, depth+1))
	}
	switch t.k {
	case kBasic:
		switch basicDart(t) {
		case "bool":
			return "b(" + x + ")"
		case "int":
			return "i64(" + x + ")"
		case "Duration": // nanoseconds on the wire
			return "i64((" + x + ").inMicroseconds * 1000)"
		case "double":
			return "f64(" + x + ")"
		}
		return "str(" + x + ")"
	case kBytes:
		return "bytes(" + x + ")"
	case kError:
		return "err(" + x + ")"
	case kValue:
		switch {
		case t.val.dartClass == "": // time.Time
			return "time(" + x + ")"
		case t.val.json: // config.Config
			return "json(" + x + ")"
		}
		return "val(" + x + ")"
	case kHandle, kCtx:
		return "h(" + x + ")"
	case kDTO, kSnap:
		return "dto(" + x + ")"
	case kOpts:
		return "opt(" + x + ")"
	case kAny:
		return "any(" + x + ")"
	case kSlice:
		w, v := fmt.Sprintf("w%d", depth), fmt.Sprintf("e%d", depth)
		return fmt.Sprintf("list(%s, (%s, %s) => %s.%s)", x, w, v, w, e.enc(t.elem, v, depth+1))
	case kMap:
		w, k, v := fmt.Sprintf("w%d", depth), fmt.Sprintf("k%d", depth), fmt.Sprintf("v%d", depth)
		key := "str(" + k + ")" // chave sem byte de presença, também a tipo-valor
		switch {
		case t.mkey != nil && t.mkey.k == kBasic: // chave inteira
			key = e.enc(t.mkey, k, depth+1)
		case t.mkey != nil:
			key = "str(" + k + ".value)"
		}
		return fmt.Sprintf("map(%s, (%s, %s) => %s.%s, (%s, %s) => %s.%s)", x, w, k, w, key, w, v, w, e.enc(t.elem, v, depth+1))
	}
	panic("gen: sem codificação Dart para " + t.key)
}

// dec: expressão que lê um [t] do leitor [r] ($R do runtime), como no
// WIRE.md. [opt]: o Dart aceita null (campo de DTO, getter); senão o nil do Go
// vira GolangException ($nil) e bytes nil viram vazio.
func (e *dartEmitter) dec(t *tinfo, r string, from *dartLib, opt bool) string {
	absent := "$nil()"
	if opt {
		absent = "null"
	}
	if t.k == kBasic && t.ptr { // *int64: presença + o básico
		in := *t
		in.ptr = false
		return fmt.Sprintf("%s.p() ? %s : %s", r, e.dec(&in, r, from, false), absent)
	}
	switch t.k {
	case kBasic:
		switch basicDart(t) {
		case "bool":
			return r + ".b()"
		case "int":
			return r + ".i64()"
		case "Duration":
			return "Duration(microseconds: " + r + ".i64() ~/ 1000)"
		case "double":
			return r + ".f64()"
		}
		return r + ".str()"
	case kBytes:
		if opt {
			return r + ".bytes()"
		}
		from.bytes = true
		return r + ".bytes() ?? Uint8List(0)"
	case kError:
		return r + ".err()"
	case kAny:
		return r + ".any()"
	case kCtx: // a callback's context (pubsub's validators): its handle
		return r + ".hnn(" + e.imp(from, pkgPrefix+"go/context.dart") + ".Context.$h)"
	case kValue:
		var inner string
		switch {
		case t.val.dartClass == "": // time.Time: DateTime, sem classe
			inner = r + ".time()"
		case t.val.json:
			inner = e.ref(t, from) + "(" + r + ".json())"
		default:
			inner = e.ref(t, from) + "(" + r + ".str())"
		}
		return fmt.Sprintf("%s.p() ? %s : %s", r, inner, absent)
	case kDTO, kSnap:
		return fmt.Sprintf("%s.p() ? %s.$dec(%s) : %s", r, e.ref(t, from), r, absent)
	case kHandle:
		if opt {
			return fmt.Sprintf("%s.hn(%s.$h)", r, e.ref(t, from))
		}
		return fmt.Sprintf("%s.hnn(%s.$h)", r, e.ref(t, from))
	case kSlice:
		return fmt.Sprintf("%s.list(() => %s)", r, e.decElem(t.elem, r, from))
	case kMap:
		key := r + ".str()"
		switch {
		case t.mkey != nil && t.mkey.k == kBasic: // chave inteira
			key = e.dec(t.mkey, r, from, false)
		case t.mkey != nil:
			key = e.ref(t.mkey, from) + "(" + r + ".str())"
		}
		return fmt.Sprintf("%s.map(() => %s, () => %s)", r, key, e.decElem(t.elem, r, from))
	}
	panic("gen: sem decodificação Dart para " + t.key)
}

// decElem: an element of a list or map is not nullable; a nil one (a nil
// error in a []error, like a nil pointer) throws.
func (e *dartEmitter) decElem(t *tinfo, r string, from *dartLib) string {
	if t.k == kError {
		return r + ".err() ?? $nil()"
	}
	return e.dec(t, r, from, false)
}

func goDoc(o types.Object) string {
	return types.ObjectString(o, func(p *types.Package) string { return p.Name() })
}

func (e *dartEmitter) body(l *dartLib) string {
	var body strings.Builder
	for _, k := range sortedKeys(l.classes) {
		body.WriteString(e.class(l, l.classes[k]))
	}
	members, ctors := e.holders(l, &body)
	layered := map[string][]string{"options": ctors}
	for _, f := range l.funcs {
		if layer := constLayer(f.obj); layer != "" {
			layered[layer] = append(layered[layer], e.function(l, f, "", false))
			continue
		}
		members = append(members, e.function(l, f, "", false))
	}
	members = append(members, l.members...)
	for _, x := range l.extra {
		body.WriteString(x)
	}
	if len(members) > 0 {
		ns := nsClass(l.path)
		fmt.Fprintf(&body, "/// Go: the package-level members of `%s` (`%s`).\nextension %sApi on %s {\n%s}\n", l.goPath, nsPath(l.path), ns, ns, strings.Join(members, "\n"))
		l.ns = true
	}
	l.layers = nil
	for _, layer := range layers {
		if ms := layered[layer]; len(ms) > 0 {
			ns := nsClass(layerPath(l.path, layer))
			fmt.Fprintf(&body, "/// Go: the %s of `%s` (`%s`).\nextension %sApi on %s {\n%s}\n", layerDoc[layer], l.goPath, nsPath(layerPath(l.path, layer)), ns, ns, strings.Join(ms, "\n"))
			l.layers = append(l.layers, layer)
		}
	}
	return body.String()
}

// emitPart: o gerado de [l] como part da library escrita à mão [hand] do mesmo
// pacote (`<nome>.g.dart`). Um part não importa nada: [hand] tem de declarar o
// part e os imports, com os prefixos, que o gerado usa.
func (e *dartEmitter) emitPart(l *dartLib, hand []byte) (string, string) {
	body := e.body(l)
	base := l.path[strings.LastIndex(l.path, "/")+1:]
	part := strings.TrimSuffix(l.path, ".dart") + ".g.dart"
	partName := strings.TrimSuffix(base, ".dart") + ".g.dart"
	src := string(hand)
	var missing []string
	if !strings.Contains(src, "part '"+partName+"';") {
		missing = append(missing, "part '"+partName+"';")
	}
	need := map[string]bool{}
	if l.bytes {
		need["import 'dart:typed_data';"] = true
	}
	if l.async {
		need["import 'dart:async';"] = true
	}
	if usesRuntime(body) {
		need["import '"+pkgPrefix+"src/runtime.dart';"] = true
	}
	if l.ns || len(l.layers) > 0 {
		need[nsImport(l)] = true
	}
	for uri, p := range l.prefix {
		need[fmt.Sprintf("import '%s' as %s;", uri, p)] = true
	}
	for _, line := range sortedKeys(need) {
		if !strings.Contains(src, line) {
			missing = append(missing, line)
		}
	}
	if len(missing) > 0 {
		panic(fmt.Sprintf("gen: lib/%s (escrita à mão) recebe o gerado de %s em %s e precisa de:\n  %s", l.path, l.goPath, partName, strings.Join(missing, "\n  ")))
	}
	return part, fmt.Sprintf("// Generated by go/gen; do not edit.\n// Go: %s (generated part)\npart of '%s';\n\n%s", l.goPath, base, body)
}

func (e *dartEmitter) emitLib(l *dartLib) string {
	body := e.body(l)
	var b strings.Builder
	fmt.Fprintf(&b, "// Generated by go/gen from go/gen/roots.txt; do not edit.\n// Go: %s\nlibrary;\n\n", l.goPath)
	if l.async {
		b.WriteString("import 'dart:async';\n")
	}
	if l.bytes {
		b.WriteString("import 'dart:typed_data';\n")
	}
	if l.async || l.bytes {
		b.WriteString("\n")
	}
	if l.ns || len(l.layers) > 0 {
		b.WriteString(nsImport(l) + "\n")
	}
	if usesRuntime(body) {
		b.WriteString("import '" + pkgPrefix + "src/runtime.dart';\n")
	}
	uris := sortedKeys(l.prefix)
	for _, uri := range uris {
		fmt.Fprintf(&b, "import '%s' as %s;\n", uri, l.prefix[uri])
	}
	b.WriteString("\n" + body)
	return strings.TrimRight(b.String(), "\n") + "\n"
}

// nsImport: the import of the library's namespace classes (its own, when it
// has members, and its layers').
func nsImport(l *dartLib) string {
	var show []string
	if l.ns {
		show = append(show, nsClass(l.path))
	}
	for _, layer := range l.layers {
		show = append(show, nsClass(layerPath(l.path, layer)))
	}
	return "import '" + pkgPrefix + "src/go.dart' show " + strings.Join(show, ", ") + ";"
}

func (e *dartEmitter) class(l *dartLib, c *dclass) string {
	msg := ""
	if c.t.named != nil {
		msg = e.m.deprecated[depKey(c.t.named.Obj())]
	}
	return ignoreMarked(deprecate(e.classBody(l, c), msg))
}

// ignoreMarked: a marked class (classMarks, Grpc_BackoffConfig) and its mixin
// are declared under `// ignore: camel_case_types`.
func ignoreMarked(src string) string {
	lines := strings.SplitAfter(src, "\n")
	for i, line := range lines {
		if m := declRE.FindStringSubmatch(line); m != nil && strings.Contains(m[1], "_") {
			lines[i] = "// ignore: camel_case_types\n" + line
		}
	}
	return strings.Join(lines, "")
}

func (e *dartEmitter) classBody(l *dartLib, c *dclass) string {
	t := c.t
	name := className(e.m, t)
	var b strings.Builder
	switch t.k {
	case kValue:
		base := "GoValue"
		if t.val.json {
			base = "GoJsonValue"
		} else if t.val.dartExtend != "" {
			base = qualType(l.path, t.val.dartExtend)
		}
		fmt.Fprintf(&b, "/// Go: `%s` (valor).\nclass %s extends %s {\n", docType(t), name, base)
		if t.val.json {
			fmt.Fprintf(&b, "  %s(super.json);\n}\n\n", name)
		} else {
			fmt.Fprintf(&b, "  const %s(super.value);\n", name)
			for _, f := range c.methods {
				b.WriteString("\n" + e.function(l, f, name, false))
			}
			b.WriteString("}\n\n")
		}
	case kOpts:
		fmt.Fprintf(&b, "/// Go: `%s` (functional option; constructors in the package).\nfinal class %s extends GoOption {\n  %s.$(super.$i, super.$a);\n}\n\n", docType(t), name, name)
	case kDTO:
		e.dto(l, &b, t, name)
		if c.token > 0 {
			fmt.Fprintf(&b, "\n  /// The Go type as a token, for a parameter that takes the type by example:\n  /// Go gets `new(%s)` (`bus.subscribe(%s.$type)`).\n  static const $type = GoToken(%d);\n", t.named.Obj().Name(), name, c.token)
		}
		for _, f := range c.methods {
			b.WriteString("\n" + e.function(l, f, name, false))
		}
		b.WriteString("}\n\n")
	case kSnap:
		// o Go devolve os valores; o Dart os monta para mandar de volta (um
		// parâmetro do tipo da interface: o Go recebe uma struct com eles)
		fmt.Fprintf(&b, "/// Go: `%s` (values read from the methods; built in Dart, it\n/// crosses as a Go value that returns them).\nfinal class %s implements GoDto {\n", docType(t), name)
		var params, inits, decs, encs []string
		for _, g := range t.gets {
			n, dartT := memberName(g.name), e.dt(g.t, l)
			params = append(params, dartT+"? "+n)
			if z := zero(g.t, dartT); z != "" && !g.hasErr {
				inits = append(inits, fmt.Sprintf("%s = %s ?? %s", n, n, z))
			} else {
				inits = append(inits, fmt.Sprintf("%s = %s", n, n))
			}
			decs = append(decs, fmt.Sprintf("%s = %s", n, e.snapDec(l, g)))
			x := n
			if z := zero(g.t, dartT); z != "" && g.hasErr { // valor (zero se o Go deu erro) e o erro
				x = n + " ?? " + z
			}
			encs = append(encs, ".."+e.enc(g.t, x, 0))
			if g.hasErr {
				encs = append(encs, "..err(null)")
			}
		}
		if len(params) == 0 {
			fmt.Fprintf(&b, "  %s();\n  %s.$dec($R r);\n", name, name)
		} else {
			fmt.Fprintf(&b, "  %s({%s})\n    : %s;\n\n", name, strings.Join(params, ", "), strings.Join(inits, ",\n      "))
			fmt.Fprintf(&b, "  %s.$dec($R r)\n    : %s;\n", name, strings.Join(decs, ",\n      "))
		}
		for _, g := range t.gets {
			q := ""
			if nullable(g.t) || g.hasErr {
				q = "?"
			}
			fmt.Fprintf(&b, "\n  /// Go: `%s()`.\n  final %s%s %s;\n", g.name, e.dt(g.t, l), q, memberName(g.name))
		}
		if len(encs) == 0 {
			b.WriteString("\n  @override\n  void $enc($W w) {}\n}\n\n")
		} else {
			fmt.Fprintf(&b, "\n  @override\n  void $enc($W w) {\n    w%s;\n  }\n}\n\n", strings.Join(encs, ""))
		}
	case kHandle:
		base := "GoHandle"
		if t.super != nil {
			base = e.ref(t.super, l)
		}
		ctor := name + ".$h(super.$h);"
		if base != "GoHandle" {
			ctor = name + ".$h(super.$h) : super.$h();"
		}
		// an interface's methods are its mixin (linkMixins), its class mixes it in
		mixin := types.IsInterface(t.named) && !t.reader
		var with, impl []string
		for _, mx := range c.mixins {
			with = append(with, e.ref(mx.t, l)+"$")
			impl = append(impl, e.ref(mx.t, l))
		}
		if mixin {
			with = append(with, name+"$")
		}
		head := ""
		if len(with) > 0 {
			head += " with " + strings.Join(with, ", ")
		}
		if len(impl) > 0 {
			head += " implements " + strings.Join(impl, ", ")
		}
		fmt.Fprintf(&b, "/// Go: `%s` (handle).\nclass %s extends %s%s {\n  %s\n", docType(t), name, base, head, ctor)
		for _, f := range c.factories {
			b.WriteString("\n" + e.function(l, f, name, true))
		}
		if mixin {
			fmt.Fprintf(&b, "}\n\n/// The methods of [%s], mixed into every class Go also accepts as one.\nmixin %s$ on GoHandle {\n", name, name)
		}
		for i, f := range c.methods {
			if mixin && i == 0 {
				b.WriteString(e.function(l, f, name, false))
				continue
			}
			b.WriteString("\n" + e.function(l, f, name, false))
		}
		b.WriteString("}\n\n")
	}
	return b.String()
}

func shortQual(p *types.Package) string { return p.Name() }

// snapDec: um getter do instantâneo; com erro, o valor vem seguido de um
// kError (WIRE.md) e o campo fica null quando o Go deu erro.
func (e *dartEmitter) snapDec(l *dartLib, g getter) string {
	if g.hasErr {
		return fmt.Sprintf("$orErr(%s, r.err())", e.dec(g.t, "r", l, true))
	}
	return e.dec(g.t, "r", l, nullable(g.t))
}

func zero(t *tinfo, dartT string) string {
	if t.ptr {
		return "" // *int64: null fica null
	}
	switch t.k {
	case kBasic:
		switch dartT {
		case "bool":
			return "false"
		case "int":
			return "0"
		case "Duration":
			return "Duration.zero"
		case "double":
			return "0.0"
		}
		return "''"
	case kSlice:
		return "[]"
	case kMap:
		return "{}"
	}
	return ""
}

func (e *dartEmitter) dto(l *dartLib, b *strings.Builder, t *tinfo, name string) {
	fmt.Fprintf(b, "/// Go: `%s`.\n", docType(t))
	var skipped []string
	for _, f := range t.fields {
		if f.skipped != "" {
			skipped = append(skipped, fmt.Sprintf("`%s` (%s)", f.name, f.skipped))
		}
	}
	if len(skipped) > 0 {
		fmt.Fprintf(b, "///\n/// Fields that do not cross the bridge: %s.\n", strings.Join(skipped, ", "))
	}
	fmt.Fprintf(b, "final class %s implements GoDto {\n", name)
	var params, inits, decs, encs []string
	dec := decodable(t) // a DTO with options inside only goes to Go
	for _, f := range t.fields {
		if f.skipped != "" {
			continue
		}
		n, dartT := memberName(f.name), e.dt(f.t, l)
		params = append(params, dartT+"? "+n)
		if z := zero(f.t, dartT); z != "" {
			inits = append(inits, fmt.Sprintf("%s = %s ?? %s", n, n, z))
		} else {
			inits = append(inits, fmt.Sprintf("%s = %s", n, n))
		}
		if dec {
			decs = append(decs, fmt.Sprintf("%s = %s", n, e.dec(f.t, "r", l, nullable(f.t))))
		}
		encs = append(encs, ".."+e.enc(f.t, n, 0))
	}
	// $dec lê os campos na ordem de tinfo.fields (o initializer list roda em
	// ordem); a presença do DTO é de quem o contém.
	switch {
	case len(params) == 0:
		fmt.Fprintf(b, "  %s();\n  %s.$dec($R r);\n", name, name)
	case !dec:
		fmt.Fprintf(b, "  %s({%s})\n    : %s;\n", name, strings.Join(params, ", "), strings.Join(inits, ",\n      "))
	default:
		fmt.Fprintf(b, "  %s({%s})\n    : %s;\n\n", name, strings.Join(params, ", "), strings.Join(inits, ",\n      "))
		fmt.Fprintf(b, "  %s.$dec($R r)\n    : %s;\n", name, strings.Join(decs, ",\n      "))
	}
	for _, f := range t.fields {
		if f.skipped != "" {
			continue
		}
		q := ""
		if nullable(f.t) {
			q = "?"
		}
		fmt.Fprintf(b, "\n  /// Go: `%s`.%s\n  %s%s %s;\n", f.name, u64Doc(isU64(f.t.t)), e.dt(f.t, l), q, memberName(f.name))
	}
	// sem a chave final: quem chama acrescenta os métodos (receptor DTO)
	if len(encs) == 0 {
		b.WriteString("\n  @override\n  void $enc($W w) {}\n")
	} else {
		fmt.Fprintf(b, "\n  @override\n  void $enc($W w) {\n    w%s;\n  }\n", strings.Join(encs, ""))
	}
}

// u64Doc: o aviso dos campos uint64 (WIRE.md: inteiros vão como i64; o Dart
// só tem int com sinal, então acima de 2^63 o mesmo padrão de bits sai negativo,
// a convenção do Uint64List do dart:typed_data).
func u64Doc(u bool) string {
	if !u {
		return ""
	}
	return "\n  ///\n  /// Go `uint64`: values from 2^63 up arrive negative (same 64 bits);\n  /// `BigInt.from(v).toUnsigned(64)` reads them unsigned."
}

func isU64(t types.Type) bool {
	b, ok := types.Unalias(t).Underlying().(*types.Basic)
	return ok && (b.Kind() == types.Uint || b.Kind() == types.Uint64 || b.Kind() == types.Uintptr)
}

// holders: as variáveis de opções do pacote (options.Unixfs, options.Pin.Ls...),
// com os construtores das opções usadas ([members]), e as funções e variáveis
// do pacote que são opções ([ctors], a camada options).
func (e *dartEmitter) holders(l *dartLib, b *strings.Builder) (members, ctors []string) {
	type node struct {
		kids  map[string]*node
		ctors []string
	}
	root := &node{kids: map[string]*node{}}
	// the option types of every library: a constructor goes to the library
	// of its package (libp2p.ListenAddrStrings builds a config.Option)
	var opts []*tinfo
	for _, path := range sortedKeys(e.libs) {
		for _, k := range sortedKeys(e.libs[path].classes) {
			if t := e.libs[path].classes[k].t; t.k == kOpts {
				opts = append(opts, t)
			}
		}
	}
	for _, t := range opts {
		for _, c := range usableCtors(t) {
			if e.m.home(c.pkg).Path() != l.goPath {
				continue
			}
			n := root
			for _, seg := range c.path[:len(c.path)-1] {
				if n.kids[seg] == nil {
					n.kids[seg] = &node{kids: map[string]*node{}}
				}
				n = n.kids[seg]
			}
			var ps, segs []string
			for i, p := range c.params {
				pn := memberName(c.pnames[i])
				if pn == "" || pn == "_" {
					pn = fmt.Sprintf("arg%d", i)
				}
				if p.k == kChanSend { // canal do chamador: StreamSink, registrado pelo runtime
					l.async = true
					E := e.dt(p.elem, l)
					ps = append(ps, "StreamSink<"+E+"> "+pn)
					segs = append(segs, fmt.Sprintf("..sink(GoSink<%s>(%s, (r) => %s))", E, pn, e.dec(p.elem, "r", l, false)))
					continue
				}
				if p.k == kFunc { // a function the option keeps: a retained callback (WIRE.md)
					ps = append(ps, e.funcType(p, l)+" "+pn)
					segs = append(segs, ".."+e.retainedCb(p, pn, l, false))
					continue
				}
				ps = append(ps, e.dt(p, l)+" "+pn)
				if p.k == kOpts { // opção dentro de opção: vai como lista de uma
					segs = append(segs, fmt.Sprintf("..list([%s], (w0, e0) => w0.opt(e0))", pn))
					continue
				}
				segs = append(segs, ".."+e.enc(p, pn, 0))
			}
			// WIRE.md: a opção vai como o índice do construtor em tinfo.ctors
			// (a lista inteira, não só a dos usáveis) + os parâmetros.
			idx := -1
			for i, tc := range t.ctors {
				if strings.Join(tc.path, ".") == strings.Join(c.path, ".") {
					idx = i
					break
				}
			}
			args := "(_) {}"
			if len(segs) > 0 {
				args = "(w) => w" + strings.Join(segs, "")
			}
			opt := e.ref(t, l)
			if c.isVar {
				n.ctors = append(n.ctors, fmt.Sprintf("  /// Go: `var %s.%s`.\n  %s get %s => %s.$(%d, %s);\n",
					l.goPath[strings.LastIndex(l.goPath, "/")+1:], c.path[0], opt, memberName(c.path[0]), opt, idx, args))
				continue
			}
			if c.variadic && len(ps) > 0 {
				ps[len(ps)-1] = "[" + ps[len(ps)-1] + " = const []]"
			}
			n.ctors = append(n.ctors, fmt.Sprintf("  /// Go: `%s.%s`.\n  %s %s(%s) => %s.$(%d, %s);\n",
				l.goPath[strings.LastIndex(l.goPath, "/")+1:], strings.Join(c.path, "."), opt, memberName(c.path[len(c.path)-1]),
				strings.Join(ps, ", "), opt, idx, args))
		}
	}
	var emit func(path []string, n *node)
	emit = func(path []string, n *node) {
		cls := "_" + typeName(strings.Join(path, ""))
		fmt.Fprintf(b, "final class %s {\n  const %s._();\n", cls, cls)
		for _, k := range sortedKeys(n.kids) {
			fmt.Fprintf(b, "\n  /// Go: `%s`.\n  final %s = const _%s._();\n", strings.Join(append(append([]string{}, path...), k), "."), memberName(k), typeName(strings.Join(path, "")+k))
		}
		sort.Strings(n.ctors)
		for _, c := range n.ctors {
			b.WriteString("\n" + c)
		}
		b.WriteString("}\n\n")
		for _, k := range sortedKeys(n.kids) {
			emit(append(append([]string{}, path...), k), n.kids[k])
		}
	}
	for _, k := range sortedKeys(root.kids) {
		members = append(members, fmt.Sprintf("  /// Go: `var %s`: option constructors.\n  _%s get %s => const _%s._();\n", k, typeName(k), memberName(k), typeName(k)))
		emit([]string{k}, root.kids[k])
	}
	sort.Strings(root.ctors)
	return members, root.ctors
}

// function emite uma função de nível de pacote, um método (inClass) ou uma
// factory (factory): codifica o receptor e os argumentos num $W (WIRE.md),
// chama a função f.id do host no modo dela e decodifica os resultados do $R.
func (e *dartEmitter) function(l *dartLib, f *fn, class string, factory bool) string {
	return deprecate(e.functionBody(l, f, class, factory), e.m.deprecated[depKey(f.obj)])
}

func (e *dartEmitter) functionBody(l *dartLib, f *fn, class string, factory bool) string {
	if f.constLit != "" { // constante: o valor do Go, sem ir ao host
		return fmt.Sprintf("  /// Go: `%s`.\n  %s get %s => %s;\n", goDoc(f.obj), constDart(f.constLit), memberName(f.obj.Name()), f.constLit)
	}
	if f.cast != nil { // type assertion: um handle novo, ou null
		C := e.dt(f.cast, l)
		return fmt.Sprintf("  /// Go: type assertion `x.(%s)`: null if the object is not one.\n  %s? %s() {\n    final $r = $callSync(%d, $W()..h(this));\n    return %s;\n  }\n",
			types.TypeString(f.cast.t, func(p *types.Package) string { return p.Name() }), C, memberName(f.obj.Name()), f.id, e.dec(f.cast, "$r", l, true))
	}
	var params, segs []string
	switch {
	case f.recv != nil && f.recv.k == kDTO: // receptor DTO: vai por valor
		segs = append(segs, "dto(this)")
	case f.recv != nil && f.recv.k == kValue: // value type: its string
		segs = append(segs, "val(this)")
	case f.recv != nil:
		segs = append(segs, "h(this)")
	}
	opt, cbItem := "", ""
	for i, p := range f.params {
		// chan<- da própria função é o modo stream
		if p.t.k == kChanSend {
			continue
		}
		if i == f.outBuf { // o Go preenche o []byte: o Dart manda só o tamanho
			segs = append(segs, "i64(n)")
			params = append(params, "int n")
			continue
		}
		n := dartParamName(p.name)
		if p.t.k == kWriter { // handle de um io.Writer (os.File, bytes.Buffer); null = io.Discard
			segs = append(segs, "h("+n+")")
			params = append(params, "GoHandle? "+n)
			continue
		}
		if p.t.k == kFunc && p.t.retained { // kept by Go: a retained callback (WIRE.md); a Dart implementation leaves methods out with null
			if f.impl != nil {
				params = append(params, e.funcType(p.t, l)+"? "+n)
			} else {
				params = append(params, e.funcType(p.t, l)+" "+n)
			}
			segs = append(segs, e.retainedCb(p.t, n, l, f.impl != nil))
			continue
		}
		if p.t.k == kFunc { // callback sob demanda: a função Dart; no pedido, o tamanho do lote
			segs = append(segs, fmt.Sprintf("u32(batchSize ?? %d)", cbDefaultBatch(p.t)))
			params = append(params, e.funcType(p.t, l)+" "+n)
			var decs []string
			for _, a := range p.t.fargs {
				decs = append(decs, e.dec(a, "r", l, false))
			}
			cbItem = fmt.Sprintf("(r) => %s(%s)", n, strings.Join(decs, ", "))
			continue
		}
		if p.t.reader {
			segs = append(segs, "reader("+n+")")
		} else {
			segs = append(segs, e.enc(p.t, n, 0))
		}
		if p.variadic {
			opt = fmt.Sprintf("[%s %s = const []]", e.dt(p.t, l), n)
			continue
		}
		dartT := "Object" // Uint8List ou um handle (io.Reader, io.ReaderAt...)
		if !p.t.reader {
			dartT = e.dt(p.t, l)
		}
		if p.t.k == kBasic && p.t.ptr { // *int64: null = nil
			dartT += "?"
		}
		params = append(params, dartT+" "+n)
	}
	if cbItem != "" { // o lote é opcional; com variádico, no mesmo colchete (o Dart não mistura [] e {})
		if opt != "" {
			opt = strings.TrimSuffix(opt, "]") + ", int? batchSize]"
		} else {
			params = append(params, "{int? batchSize}")
		}
	}
	if opt != "" {
		params = append(params, opt)
	}
	if f.impl != nil && len(params) > 0 { // a Dart implementation: the methods by name
		params = []string{"{" + strings.Join(params, ", ") + "}"}
	}
	sig := "(" + strings.Join(params, ", ") + ")"
	call := fmt.Sprintf("%d", f.id)
	if len(segs) > 0 {
		call += ", $W().." + strings.Join(segs, "..")
	}
	indent := "  " // a class member, or one of the namespace's extension
	name := memberName(f.obj.Name())
	var b strings.Builder
	if f.impl != nil {
		fmt.Fprintf(&b, "%s/// A Dart implementation of Go's `%s`.\n", indent, docType(f.results[0]))
	} else {
		fmt.Fprintf(&b, "%s/// Go: `%s`.\n", indent, goDoc(f.obj))
	}
	if f.async && f.stream == nil {
		fmt.Fprintf(&b, "%s///\n%s/// Asynchronous: runs in a goroutine of the service.\n", indent, indent)
	}
	for _, p := range f.params {
		if p.t.k == kFunc && p.t.retained {
			what := "Go keeps [" + dartParamName(p.name) + "] and calls it on the Dart event loop for as\n/// long as it holds it"
			if f.impl != nil {
				what = "Go keeps the functions and calls them on the Dart event loop for as\n/// long as it holds the object; a method left out does nothing"
			} else if p.t.unchecked {
				what = "Go calls [" + dartParamName(p.name) + "] on the Dart event loop, during the call or\n/// later for as long as it holds it (nobody checked which), and waits for\n/// each invocation"
			}
			what = strings.ReplaceAll(what, "\n", "\n"+indent)
			fmt.Fprintf(&b, "%s///\n%s/// %s (a retained callback, WIRE.md).\n", indent, indent, what)
			break
		}
	}
	if i := funcParamIdx(f); i >= 0 {
		doc := []string{"[batchSize]: invocations of the callback Go sends at a time (default",
			"1024, up to 128 KiB). Go runs at most `batchSize - 1` invocations ahead",
			"of Dart; 1 is exactly Go's semantics."}
		if cbDefaultBatch(f.params[i].t) == 1 {
			doc = []string{"[batchSize]: invocations of the callback Go sends at a time (default 1:",
				"the callback receives Go objects that may only be valid during the",
				"invocation). Go runs at most `batchSize - 1` invocations ahead of Dart."}
		}
		fmt.Fprintf(&b, "%s///\n", indent)
		for _, d := range doc {
			fmt.Fprintf(&b, "%s/// %s\n", indent, d)
		}
	}
	if f.stream != nil {
		fmt.Fprintf(&b, "%sStream<%s> %s%s =>\n%s    $stream(%s).map((r) => %s);\n", indent, e.dt(f.stream, l), name, sig, indent, call, e.dec(f.stream, "r", l, false))
		return b.String()
	}
	ret, dec := "void", ""
	switch {
	case f.outBuf >= 0: // os bytes lidos (vazio no fim)
		l.bytes = true
		ret, dec = "Uint8List", "$r.bytes() ?? Uint8List(0)"
	case len(f.results) == 0:
	case len(f.results) == 1:
		ret, dec = e.dt(f.results[0], l), e.dec(f.results[0], "$r", l, false)
	default: // os campos de um record são avaliados em ordem
		var ts, ds []string
		for _, r := range f.results {
			ts = append(ts, e.dt(r, l))
			ds = append(ds, e.dec(r, "$r", l, false))
		}
		ret = "(" + strings.Join(ts, ", ") + ")"
		dec = "(" + strings.Join(ds, ", ") + ")"
	}
	head := fmt.Sprintf("%s %s%s", ret, name, sig)
	switch {
	case f.setter:
		head = fmt.Sprintf("set %s%s", name, sig)
	case f.isVar || f.field:
		head = fmt.Sprintf("%s get %s", ret, name)
	}
	if factory {
		head = "factory " + class + sig
	}
	callExpr := "$callSync(" + call + ")"
	if f.async {
		if factory {
			panic("gen: factory assíncrona")
		}
		head = fmt.Sprintf("Future<%s> %s%s async", ret, name, sig)
		callExpr = "await $call(" + call + ")"
		if cbItem != "" {
			callExpr = "await $callCb(" + call + ", " + cbItem + ")"
		}
	}
	if dec == "" {
		fmt.Fprintf(&b, "%s%s {\n%s  %s;\n%s}\n", indent, head, indent, callExpr, indent)
	} else {
		fmt.Fprintf(&b, "%s%s {\n%s  final $r = %s;\n%s  return %s;\n%s}\n", indent, head, indent, callExpr, indent, dec, indent)
	}
	return b.String()
}

// constDart: the Dart type of a constant's literal (dartConstLit).
func constDart(lit string) string {
	switch {
	case lit == "true" || lit == "false":
		return "bool"
	case strings.HasPrefix(lit, "Duration("):
		return "Duration"
	case strings.HasPrefix(lit, `"`):
		return "String"
	case strings.ContainsAny(lit, ".eEn"):
		return "double"
	}
	return "int"
}

// weaker: [a] is only taken by option constructors and [b] is not.
func (e *dartEmitter) weaker(a, b *dclass) bool {
	only := func(c *dclass) bool {
		return e.optIfaces[classKey(c.t)] && realMethods(c) == 0 && !e.paramIfaces[classKey(c.t)]
	}
	return only(a) && !only(b)
}

// retainedCb: the writer call of the retained callback [n] of type [t]
// (WIRE.md): its decoder and, for a value result, the value's encoder;
// [nullable]: null sends nil.
func (e *dartEmitter) retainedCb(t *tinfo, n string, l *dartLib, nullable bool) string {
	var decs []string
	for _, a := range t.fargs {
		decs = append(decs, e.dec(a, "r", l, false))
	}
	call := fmt.Sprintf("(r) => %s(%s)", n, strings.Join(decs, ", "))
	if nullable {
		call = fmt.Sprintf("%s == null ? null : %s", n, call)
	}
	if t.fret == fretVal { // the value goes back in the CallbackAck
		return fmt.Sprintf("cb(%s, true, (w, v) => w.%s)", call, e.enc(t.fres, "v as "+e.dt(t.fres, l), 0))
	}
	return fmt.Sprintf("cb(%s, %v)", call, t.fret != fretNone || t.unchecked)
}

// better: a interface [a] é melhor base para um handle concreto que [b].
func better(a, b *dclass) bool {
	if ra, rb := realMethods(a) > 0, realMethods(b) > 0; ra != rb {
		return ra
	}
	return a.t.named.Underlying().(*types.Interface).NumMethods() > b.t.named.Underlying().(*types.Interface).NumMethods()
}

func realMethods(c *dclass) int {
	n := 0
	for _, f := range c.methods {
		if f.cast == nil {
			n++
		}
	}
	return n
}

// funcType: o tipo Dart da função passada como callback: os argumentos do
// callback Go e FutureOr<bool> (false para) ou FutureOr<void>.
func (e *dartEmitter) funcType(t *tinfo, l *dartLib) string {
	l.async = true // FutureOr
	var ps []string
	for i, a := range t.fargs {
		n := dartParamName(t.fnames[i])
		if n == "" || n == "_" {
			n = dartParamName(paramName(a, i)) // the type's name (stream, conn), as for parameters
		}
		ps = append(ps, e.dt(a, l)+" "+n)
	}
	ret := "FutureOr<void>"
	switch t.fret {
	case fretBool:
		ret = "FutureOr<bool>"
	case fretVal:
		ret = "FutureOr<" + e.dt(t.fres, l) + ">"
	}
	return fmt.Sprintf("%s Function(%s)", ret, strings.Join(ps, ", "))
}

// cbDefaultBatch: o lote quando o Dart não diz (0 = o padrão medido do
// host, callback.go); 1 quando o callback recebe um objeto Go (handle), que
// pode só valer durante a invocação (o ExploreFieldsSpecBuilder do
// exploreFields).
func cbDefaultBatch(t *tinfo) int {
	for _, a := range t.fargs {
		if a.k == kHandle {
			return 1
		}
	}
	return 0
}

func usesRuntime(body string) bool {
	for _, id := range []string{"GoHandle", "GoValue", "GoDto", "GoOption", "GoSink", "GoToken", "GolangException", "$call", "$stream", "$W", "$R", "$nil", "$orErr"} {
		if strings.Contains(body, id) {
			return true
		}
	}
	return false
}

func docType(t *tinfo) string {
	if t.named != nil {
		return types.TypeString(t.named, shortQual)
	}
	return types.TypeString(t.t, shortQual)
}

// linkInterfaces: uma interface que embute várias (routing.ContentRouting:
// ContentProviding e ContentDiscovery) estende no Dart só uma, a primeira;
// se essa nenhuma função recebe e outra embutida sim (bitswap.New pede
// ContentDiscovery), estende a recebida, para ser aceita onde o Go a aceita.
func (e *dartEmitter) linkInterfaces() {
	for _, path := range sortedKeys(e.libs) {
		l := e.libs[path]
		for _, k := range sortedKeys(l.classes) {
			t := l.classes[k].t
			if t.k != kHandle || t.named == nil || !types.IsInterface(t.named) || t.super == nil || e.paramIfaces[classKey(t.super)] {
				continue
			}
			u := t.named.Underlying().(*types.Interface)
			for i := 0; i < u.NumEmbeddeds(); i++ {
				if en, ok := u.EmbeddedType(i).(*types.Named); ok {
					if s := e.m.classify(en); s.k == kHandle && !s.reader && e.paramIfaces[classKey(s)] {
						t.super = s
						break
					}
				}
			}
		}
	}
}

// alignOverrides: a method that overrides an asynchronous one of its base
// class or of a mixin (swarm.Conn.Close over network.Conn.Close) is
// asynchronous too, or the Dart override would not be valid.
func (e *dartEmitter) alignOverrides() {
	classes := map[string]*dclass{}
	for _, l := range e.libs {
		for _, c := range l.classes {
			if c.t.k == kHandle && c.t.named != nil {
				classes[classKey(c.t)] = c
			}
		}
	}
	for changed := true; changed; {
		changed = false
		for _, c := range classes {
			async := map[string]bool{}
			var supers []*tinfo
			for s := c.t.super; s != nil; s = s.super {
				supers = append(supers, s)
			}
			for _, mx := range c.mixins {
				supers = append(supers, mx.t)
			}
			for _, s := range supers {
				if b := classes[classKey(s)]; b != nil {
					for _, f := range b.methods {
						async[memberName(f.obj.Name())] = async[memberName(f.obj.Name())] || f.async
					}
				}
			}
			for _, f := range c.methods {
				if !f.async && async[memberName(f.obj.Name())] {
					f.async, changed = true, true
				}
			}
		}
	}
}

// linkConcrete: handle concreto (*merkledag.RawNode) que implementa uma
// interface exposta (ipld.Node) estende a classe dela no Dart, para ser aceito
// onde o Go aceita a interface. Escolhe a interface com mais métodos.
func (e *dartEmitter) linkConcrete() {
	var ifaces []*dclass
	for _, path := range sortedKeys(e.libs) {
		l := e.libs[path]
		for _, k := range sortedKeys(l.classes) {
			c := l.classes[k]
			// só interfaces com métodos expostos (io.Closer sem métodos gerados
			// não acrescenta nada); os casts (asProtoNode) não contam: senão a
			// interface que só serve de parâmetro (datamodel.Node) ganharia
			if c.t.k == kHandle && !c.t.reader && types.IsInterface(c.t.named) && (realMethods(c) > 0 || e.paramIfaces[classKey(c.t)] || e.optIfaces[classKey(c.t)]) {
				ifaces = append(ifaces, c)
			}
		}
	}
	for _, path := range sortedKeys(e.libs) {
		l := e.libs[path]
		for _, k := range sortedKeys(l.classes) {
			c := l.classes[k]
			if c.t.k != kHandle || c.t.super != nil || types.IsInterface(c.t.named) {
				continue
			}
			var best *dclass
			for _, i := range ifaces {
				it := i.t.named.Underlying().(*types.Interface)
				if !types.Implements(types.NewPointer(c.t.named), it) && !types.Implements(c.t.named, it) {
					continue
				}
				// a com métodos expostos ganha da usada só como parâmetro
				// (ProtoNode fica format.Node, não datamodel.Node); entre
				// iguais, a com mais métodos; one only an option takes comes last;
				// the other interfaces it implements are mixed in (linkMixins)
				if best == nil || e.weaker(best, i) || (e.weaker(i, best) == e.weaker(best, i) && better(i, best)) {
					best = i
				}
			}
			if best != nil {
				c.t.super = best.t
			}
		}
	}
	e.ifaces = ifaces
}

// linkMixins: Dart has one base class, Go accepts a type as every interface
// it implements (IpfsDht is a ContentRouting, a ValueStore, a Routing...).
// Each interface's methods are also a mixin (`Name$`); a handle mixes in and
// implements the exposed interfaces its base class's chain lacks: those an
// interface embeds, every one a concrete type implements.
func (e *dartEmitter) linkMixins() {
	depth := func(c *dclass) int {
		n := 0
		for s := c.t.super; s != nil; s = s.super {
			n++
		}
		return n
	}
	for _, path := range sortedKeys(e.libs) {
		l := e.libs[path]
		for _, k := range sortedKeys(l.classes) {
			c := l.classes[k]
			if c.t.k != kHandle || c.t.reader || c.t.named == nil {
				continue
			}
			chain := map[string]bool{classKey(c.t): true}
			for s := c.t.super; s != nil; s = s.super {
				chain[classKey(s)] = true
			}
			iface := types.IsInterface(c.t.named)
			var ms []*dclass
			for _, i := range e.ifaces {
				if chain[classKey(i.t)] {
					continue
				}
				// an interface only through embedding: two interfaces with the
				// same methods would implement each other, a cycle in Dart
				if iface && !embeds(c.t.named, i.t.named) {
					continue
				}
				it := i.t.named.Underlying().(*types.Interface)
				if !iface && !types.Implements(types.NewPointer(c.t.named), it) && !types.Implements(c.t.named, it) {
					continue
				}
				ms = append(ms, i)
			}
			sort.SliceStable(ms, func(a, b int) bool { return depth(ms[a]) < depth(ms[b]) })
			c.mixins = ms
		}
	}
}
