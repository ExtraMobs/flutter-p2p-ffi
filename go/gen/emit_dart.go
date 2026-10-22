package main

import (
	"bytes"
	"fmt"
	"go/types"
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
	extra   []string // código de outro emissor (os comandos e os DTOs deles)
	bytes   bool     // usa Uint8List
	async   bool     // usa StreamSink (dart:async)
}

type dclass struct {
	t         *tinfo
	methods   []*fn
	factories []*fn
}

type dartEmitter struct {
	m           *model
	libs        map[string]*dartLib
	paramIfaces map[string]bool // interfaces usadas como parâmetro (linkConcrete)
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
	l := e.lib(t.named.Obj().Pkg().Path())
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
		for _, p := range c.params {
			e.collect(p)
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
func emitDart(m *model, fns []*fn, hash uint64, more func(*dartEmitter)) (map[string][]byte, []*fn) {
	e := &dartEmitter{m: m, libs: map[string]*dartLib{}, paramIfaces: map[string]bool{}}
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
			c := e.lib(f.recv.named.Obj().Pkg().Path()).classes[classKey(f.recv)]
			c.methods = append(c.methods, f)
		case isFactory(f):
			c := e.lib(f.pkg.Path()).classes[classKey(f.results[0])]
			c.factories = append(c.factories, f)
		default:
			l := e.lib(f.pkg.Path())
			l.funcs = append(l.funcs, f)
		}
	}
	e.linkConcrete()
	if more != nil {
		more(e)
	}
	consts := e.constants()
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
	// O hash da tabela vai no Hello do P2pService (WIRE.md): app e host têm de
	// vir do mesmo gerador.
	out["src/table.dart"] = tableDart(hash)
	return out, consts
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
	name := className(t)
	l := e.lib(t.named.Obj().Pkg().Path())
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

func className(t *tinfo) string {
	if t.k == kValue {
		return t.val.dartClass
	}
	return typeName(t.named.Obj().Name())
}

func basicDart(t *tinfo) string {
	tt := t.t
	if p, ok := tt.(*types.Pointer); ok { // *int64: o tipo do básico
		tt = p.Elem()
	}
	b := tt.Underlying().(*types.Basic)
	switch {
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
		return fmt.Sprintf("%s.list(() => %s)", r, e.dec(t.elem, r, from, false))
	case kMap:
		key := r + ".str()"
		switch {
		case t.mkey != nil && t.mkey.k == kBasic: // chave inteira
			key = e.dec(t.mkey, r, from, false)
		case t.mkey != nil:
			key = e.ref(t.mkey, from) + "(" + r + ".str())"
		}
		return fmt.Sprintf("%s.map(() => %s, () => %s)", r, key, e.dec(t.elem, r, from, false))
	}
	panic("gen: sem decodificação Dart para " + t.key)
}

func goDoc(o types.Object) string {
	return types.ObjectString(o, func(p *types.Package) string { return p.Name() })
}

func (e *dartEmitter) body(l *dartLib) string {
	var body strings.Builder
	for _, k := range sortedKeys(l.classes) {
		body.WriteString(e.class(l, l.classes[k]))
	}
	e.holders(l, &body)
	for _, f := range l.funcs {
		body.WriteString(e.function(l, f, "", false) + "\n")
	}
	for _, x := range l.extra {
		body.WriteString(x)
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

func (e *dartEmitter) class(l *dartLib, c *dclass) string {
	t := c.t
	name := className(t)
	var b strings.Builder
	switch t.k {
	case kValue:
		base := "GoValue"
		if t.val.json {
			base = "GoJsonValue"
		} else if t.val.dartExtend != "" {
			base = t.val.dartExtend
		}
		fmt.Fprintf(&b, "/// Go: `%s` (valor).\nclass %s extends %s {\n", docType(t), name, base)
		if t.val.json {
			fmt.Fprintf(&b, "  %s(super.json);\n}\n\n", name)
		} else {
			fmt.Fprintf(&b, "  const %s(super.value);\n}\n\n", name)
		}
	case kOpts:
		fmt.Fprintf(&b, "/// Go: `%s` (functional option; constructors in the package).\nfinal class %s extends GoOption {\n  %s.$(super.$i, super.$a);\n}\n\n", docType(t), name, name)
	case kDTO:
		e.dto(l, &b, t, name)
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
		fmt.Fprintf(&b, "/// Go: `%s` (handle).\nclass %s extends %s {\n  %s\n", docType(t), name, base, ctor)
		for _, f := range c.factories {
			b.WriteString("\n" + e.function(l, f, name, true))
		}
		for _, f := range c.methods {
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
		decs = append(decs, fmt.Sprintf("%s = %s", n, e.dec(f.t, "r", l, nullable(f.t))))
		encs = append(encs, ".."+e.enc(f.t, n, 0))
	}
	// $dec lê os campos na ordem de tinfo.fields (o initializer list roda em
	// ordem); a presença do DTO é de quem o contém.
	if len(params) == 0 {
		fmt.Fprintf(b, "  %s();\n  %s.$dec($R r);\n", name, name)
	} else {
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
// com os construtores das opções usadas.
func (e *dartEmitter) holders(l *dartLib, b *strings.Builder) {
	type node struct {
		kids  map[string]*node
		ctors []string
	}
	root := &node{kids: map[string]*node{}}
	for _, k := range sortedKeys(l.classes) {
		t := l.classes[k].t
		if t.k != kOpts {
			continue
		}
		for _, c := range usableCtors(t) {
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
			opt := className(t)
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
		fmt.Fprintf(b, "/// Go: `var %s`: option constructors.\nconst %s = _%s._();\n\n", k, memberName(k), typeName(k))
		emit([]string{k}, root.kids[k])
	}
	sort.Strings(root.ctors)
	for _, c := range root.ctors { // funções do pacote: no nível da library
		b.WriteString(strings.ReplaceAll(strings.TrimPrefix(c, "  "), "\n  ", "\n") + "\n")
	}
}

// function emite uma função de nível de pacote, um método (inClass) ou uma
// factory (factory): codifica o receptor e os argumentos num $W (WIRE.md),
// chama a função f.id do host no modo dela e decodifica os resultados do $R.
func (e *dartEmitter) function(l *dartLib, f *fn, class string, factory bool) string {
	if isConstObj(f.obj) { // constante: o valor do Go, sem ir ao host
		return fmt.Sprintf("/// Go: `%s`.\nconst %s = %s;\n", goDoc(f.obj), memberName(f.obj.Name()), f.constLit)
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
	sig := "(" + strings.Join(params, ", ") + ")"
	call := fmt.Sprintf("%d", f.id)
	if len(segs) > 0 {
		call += ", $W().." + strings.Join(segs, "..")
	}
	indent := ""
	if class != "" {
		indent = "  "
	}
	name := memberName(f.obj.Name())
	var b strings.Builder
	fmt.Fprintf(&b, "%s/// Go: `%s`.\n", indent, goDoc(f.obj))
	if f.async && f.stream == nil {
		fmt.Fprintf(&b, "%s///\n%s/// Asynchronous: runs in a goroutine of the service.\n", indent, indent)
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
			n = fmt.Sprintf("arg%d", i)
		}
		ps = append(ps, e.dt(a, l)+" "+n)
	}
	ret := "FutureOr<void>"
	if t.fret == fretBool {
		ret = "FutureOr<bool>"
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
	for _, id := range []string{"GoHandle", "GoValue", "GoDto", "GoOption", "GoSink", "$call", "$stream", "$W", "$R", "$nil", "$orErr"} {
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
			if c.t.k == kHandle && !c.t.reader && types.IsInterface(c.t.named) && (realMethods(c) > 0 || e.paramIfaces[classKey(c.t)]) {
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
				// iguais, a com mais métodos
				if best == nil || better(i, best) {
					best = i
				}
			}
			if best != nil {
				c.t.super = best.t
			}
		}
	}
}
