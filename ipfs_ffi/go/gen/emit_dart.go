package main

import (
	"bytes"
	"fmt"
	"go/types"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

// dartPath: library Dart de um pacote Go, sem o prefixo github.com/<org>/.
func dartPath(pkgPath string) string {
	p := pkgPath
	if parts := strings.SplitN(p, "/", 3); len(parts) == 3 && parts[0] == "github.com" {
		p = parts[2]
	}
	return strings.NewReplacer("-", "_", ".", "_").Replace(p) + ".dart"
}

type dartLib struct {
	path    string
	goPath  string
	prefix  map[string]string // library importada → prefixo
	classes map[string]*dclass
	funcs   []*fn
	bytes   bool // usa Uint8List
	async   bool // usa StreamSink (dart:async)
	ffi     bool // tem exports diretos (dart:ffi)
	lookups []string
}

type dclass struct {
	t         *tinfo
	methods   []*fn
	factories []*fn
}

type dartEmitter struct {
	m    *model
	libs map[string]*dartLib
}

func (e *dartEmitter) lib(goPath string) *dartLib {
	path := dartPath(goPath)
	l, ok := e.libs[path]
	if !ok {
		l = &dartLib{path: path, goPath: goPath, prefix: map[string]string{}, classes: map[string]*dclass{}}
		e.libs[path] = l
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

func emitDart(m *model, fns []*fn, hash uint64) map[string][]byte {
	_ = hash // tabela do protocolo (WIRE.md)
	e := &dartEmitter{m: m, libs: map[string]*dartLib{}}
	for _, f := range fns {
		if f.why != "" {
			continue
		}
		e.collect(f.recv)
		for _, p := range f.params {
			e.collect(p.t)
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
	out := map[string][]byte{}
	for path, l := range e.libs {
		src := e.emitLib(l)
		// Código escrito à mão que o gerador não exprime (ex. config.Profiles).
		if extra, err := os.ReadFile(filepath.Join("gen", "extra", path+".extra")); err == nil {
			src += "\n" + string(extra)
		}
		out[path] = formatDart(path, src)
	}
	return out
}

// formatDart passa a library pelo dart format (estilo da versão do pubspec).
func formatDart(path, src string) []byte {
	cmd := exec.Command("dart", "format", "--output=show", "--stdin-name=lib/"+path)
	cmd.Dir = ".."
	cmd.Stdin = strings.NewReader(src)
	var out, errb bytes.Buffer
	cmd.Stdout, cmd.Stderr = &out, &errb
	if err := cmd.Run(); err != nil {
		panic(fmt.Sprintf("gen: dart format %s: %v\n%s\n%s", path, err, errb.String(), src))
	}
	return out.Bytes()
}

// isFactory: NewX síncrono que devolve X do mesmo pacote vira `factory X(...)`.
func isFactory(f *fn) bool {
	if f.async || len(f.results) != 1 {
		return false
	}
	r := f.results[0]
	if (r.k != kHandle && r.k != kDTO) || r.named == nil || r.reader {
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
	return e.imp(from, "package:ipfs_ffi/"+l.path) + "." + name
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
	b := t.t.Underlying().(*types.Basic)
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
		return e.imp(from, "package:ipfs_ffi/context.dart") + ".Context"
	case kChanSend, kChanRecv:
		return "Stream<" + e.dt(t.elem, from) + ">"
	}
	panic("gen: sem tipo Dart para " + t.key)
}

func nullable(t *tinfo) bool {
	switch t.k {
	case kValue, kDTO, kSnap, kHandle, kBytes, kError:
		return true
	}
	return false
}

// dd: decodificação Dart do valor JSON [x] (já não nulo).
func (e *dartEmitter) dd(t *tinfo, x string, from *dartLib, depth int) string {
	switch t.k {
	case kBasic:
		switch basicDart(t) {
		case "double":
			return "(" + x + " as num).toDouble()"
		default:
			return x + " as " + basicDart(t)
		}
	case kBytes:
		from.bytes = true
		return "$bytes(" + x + ")"
	case kError:
		return x + " as String"
	case kValue:
		switch {
		case t.val.dartClass == "":
			return fmt.Sprintf(t.val.dartDec, x)
		case t.val.json:
			return e.ref(t, from) + "(" + x + " as Map<String, Object?>)"
		}
		return e.ref(t, from) + "(" + x + " as String)"
	case kDTO, kSnap:
		return e.ref(t, from) + ".$fromJson(" + x + " as Map<String, Object?>)"
	case kHandle:
		return e.ref(t, from) + ".$h(" + x + " as int)"
	case kSlice:
		v := fmt.Sprintf("e%d", depth)
		return fmt.Sprintf("[for (final %s in %s as List) %s]", v, x, e.dd(t.elem, v, from, depth+1))
	case kMap:
		v := fmt.Sprintf("e%d", depth)
		key := v + ".key"
		if t.mkey != nil { // a chave do JSON já é String: só envolve na classe-valor
			key = e.ref(t.mkey, from) + "(" + key + ")"
		}
		return fmt.Sprintf("{for (final %s in (%s as Map<String, Object?>).entries) %s: %s}", v, x, key, e.dd(t.elem, v+".value", from, depth+1))
	}
	panic("gen: sem decodificação Dart para " + t.key)
}

// ddn: como dd, mas o JSON pode ser null.
func (e *dartEmitter) ddn(t *tinfo, x string, from *dartLib) string {
	if !nullable(t) {
		return e.dd(t, x, from, 0)
	}
	return fmt.Sprintf("%s == null ? null : %s", x, e.dd(t, x, from, 0))
}

// ddr: resultado de função (não nulo; nil do Go vira IpfsException).
func (e *dartEmitter) ddr(t *tinfo, x string, from *dartLib) string {
	if nullable(t) && t.k != kBytes {
		x = "$nn(" + x + ")"
	}
	return e.dd(t, x, from, 0)
}

func goDoc(o types.Object) string {
	return types.ObjectString(o, func(p *types.Package) string { return p.Name() })
}

func (e *dartEmitter) emitLib(l *dartLib) string {
	var body strings.Builder
	for _, k := range sortedKeys(l.classes) {
		body.WriteString(e.class(l, l.classes[k]))
	}
	e.holders(l, &body)
	for _, f := range l.funcs {
		body.WriteString(e.function(l, f, "", false) + "\n")
	}
	if len(l.lookups) > 0 {
		body.WriteString("// Exports diretos (sem JSON) usados acima.\n")
		for _, lk := range l.lookups {
			body.WriteString(lk)
		}
	}
	var b strings.Builder
	fmt.Fprintf(&b, "// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.\n// Go: %s\nlibrary;\n\n", l.goPath)
	if l.async {
		b.WriteString("import 'dart:async';\n")
	}
	if l.ffi {
		b.WriteString("import 'dart:ffi';\n")
	}
	if l.bytes {
		b.WriteString("import 'dart:typed_data';\n")
	}
	if l.async || l.bytes || l.ffi {
		b.WriteString("\n")
	}
	if usesRuntime(body.String()) {
		b.WriteString("import 'package:ipfs_ffi/src/runtime.dart';\n")
	}
	uris := sortedKeys(l.prefix)
	for _, uri := range uris {
		fmt.Fprintf(&b, "import '%s' as %s;\n", uri, l.prefix[uri])
	}
	b.WriteString("\n" + body.String())
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
		fmt.Fprintf(&b, "/// Go: `%s` (opção funcional; construtores nas variáveis do pacote).\nfinal class %s extends GoOption {\n  %s.$(super.p, super.a);\n}\n\n", docType(t), name, name)
	case kDTO:
		e.dto(l, &b, t, name)
	case kSnap:
		fmt.Fprintf(&b, "/// Go: `%s` (valores lidos dos métodos).\nfinal class %s {\n", docType(t), name)
		var inits []string
		for _, g := range t.gets {
			inits = append(inits, fmt.Sprintf("%s = %s", memberName(g.name), e.snapDec(l, g)))
		}
		if len(inits) == 0 {
			fmt.Fprintf(&b, "  %s.$fromJson(Map<String, Object?> j);\n", name)
		} else {
			fmt.Fprintf(&b, "  %s.$fromJson(Map<String, Object?> j)\n    : %s;\n", name, strings.Join(inits, ",\n      "))
		}
		for _, g := range t.gets {
			q := ""
			if nullable(g.t) || g.hasErr {
				q = "?"
			}
			fmt.Fprintf(&b, "\n  /// Go: `%s()`.\n  final %s%s %s;\n", g.name, e.dt(g.t, l), q, memberName(g.name))
		}
		b.WriteString("}\n\n")
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

func (e *dartEmitter) snapDec(l *dartLib, g getter) string {
	x := fmt.Sprintf("j['%s']", g.name)
	if g.hasErr && !nullable(g.t) {
		return fmt.Sprintf("%s == null ? null : %s", x, e.dd(g.t, x, l, 0))
	}
	return e.ddn(g.t, x, l)
}

func zero(t *tinfo, dartT string) string {
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
		fmt.Fprintf(b, "///\n/// Campos que não atravessam a ponte: %s.\n", strings.Join(skipped, ", "))
	}
	fmt.Fprintf(b, "final class %s implements GoJson {\n", name)
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
		decs = append(decs, fmt.Sprintf("%s = %s", n, e.ddn(f.t, fmt.Sprintf("j['%s']", f.name), l)))
		encs = append(encs, fmt.Sprintf("'%s': $enc(%s)", f.name, n))
	}
	if len(params) == 0 {
		fmt.Fprintf(b, "  %s();\n  %s.$fromJson(Map<String, Object?> j);\n", name, name)
	} else {
		fmt.Fprintf(b, "  %s({%s})\n    : %s;\n\n", name, strings.Join(params, ", "), strings.Join(inits, ",\n      "))
		fmt.Fprintf(b, "  %s.$fromJson(Map<String, Object?> j)\n    : %s;\n", name, strings.Join(decs, ",\n      "))
	}
	for _, f := range t.fields {
		if f.skipped != "" {
			continue
		}
		q := ""
		if nullable(f.t) {
			q = "?"
		}
		fmt.Fprintf(b, "\n  /// Go: `%s`.\n  %s%s %s;\n", f.name, e.dt(f.t, l), q, memberName(f.name))
	}
	fmt.Fprintf(b, "\n  @override\n  Map<String, Object?> $toJson() => {%s};\n}\n\n", strings.Join(encs, ", "))
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
			var ps, as []string
			for i, p := range c.params {
				pn := memberName(c.pnames[i])
				if pn == "" || pn == "_" {
					pn = fmt.Sprintf("arg%d", i)
				}
				if p.k == kChanSend { // canal do chamador: StreamSink, registrado pelo runtime
					l.async = true
					E := e.dt(p.elem, l)
					ps = append(ps, "StreamSink<"+E+"> "+pn)
					as = append(as, fmt.Sprintf("GoSink<%s>(%s, (j) => %s)", E, pn, e.dd(p.elem, "j", l, 0)))
					continue
				}
				ps = append(ps, e.dt(p, l)+" "+pn)
				as = append(as, pn)
			}
			opt := className(t)
			n.ctors = append(n.ctors, fmt.Sprintf("  /// Go: `%s.%s`.\n  %s %s(%s) => %s.$('%s', [%s]);\n",
				l.goPath[strings.LastIndex(l.goPath, "/")+1:], strings.Join(c.path, "."), opt, memberName(c.path[len(c.path)-1]),
				strings.Join(ps, ", "), opt, strings.Join(c.path, "."), strings.Join(as, ", ")))
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
		fmt.Fprintf(b, "/// Go: `var %s`: construtores de opções.\nconst %s = _%s._();\n\n", k, memberName(k), typeName(k))
		emit([]string{k}, root.kids[k])
	}
}

// function emite uma função de nível de pacote, um método (inClass) ou uma
// factory (factory).
func (e *dartEmitter) function(l *dartLib, f *fn, class string, factory bool) string {
	var params, args []string
	if f.recv != nil {
		args = append(args, "this")
	}
	opt := ""
	for _, p := range f.params {
		if p.t.k == kWriter || p.t.k == kChanSend {
			continue
		}
		n := memberName(p.name)
		args = append(args, n)
		if p.variadic {
			opt = fmt.Sprintf("[%s %s = const []]", e.dt(p.t, l), n)
			continue
		}
		dartT := e.dt(p.t, l)
		if p.t.reader {
			dartT = "Object" // Uint8List ou um handle de io.Reader
		}
		params = append(params, dartT+" "+n)
	}
	if opt != "" {
		params = append(params, opt)
	}
	sig := "(" + strings.Join(params, ", ") + ")"
	call := fmt.Sprintf("'%s', [%s]", f.key, strings.Join(args, ", "))
	indent := ""
	if class != "" {
		indent = "  "
	}
	name := memberName(f.obj.Name())
	var b strings.Builder
	fmt.Fprintf(&b, "%s/// Go: `%s`.\n", indent, goDoc(f.obj))
	if f.async && f.stream == nil {
		fmt.Fprintf(&b, "%s///\n%s/// Assíncrona: roda numa goroutine.\n", indent, indent)
	}
	if f.stream != nil {
		fmt.Fprintf(&b, "%sStream<%s> %s%s =>\n%s    $stream(%s).map((r) => %s);\n", indent, e.dt(f.stream, l), name, sig, indent, call, e.dd(f.stream, "r", l, 0))
		return b.String()
	}
	if f.direct >= 0 {
		head := ""
		switch {
		case factory:
			head = "factory " + class + sig
		case f.isVar:
			head = e.directRet(f, l) + " get " + name
		default:
			head = e.directRet(f, l) + " " + name + sig
		}
		b.WriteString(indent + head + " {\n" + e.directBody(l, f, indent+"  ") + indent + "}\n")
		return b.String()
	}
	ret, dec := "void", ""
	switch len(f.results) {
	case 0:
	case 1:
		ret, dec = e.dt(f.results[0], l), e.ddr(f.results[0], "$r", l)
	default:
		var ts, ds []string
		for i, r := range f.results {
			ts = append(ts, e.dt(r, l))
			ds = append(ds, e.ddr(r, fmt.Sprintf("$l[%d]", i), l))
		}
		ret = "(" + strings.Join(ts, ", ") + ")"
		dec = "(" + strings.Join(ds, ", ") + ")"
	}
	head := fmt.Sprintf("%s %s%s", ret, name, sig)
	if f.isVar {
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
	}
	switch {
	case dec == "":
		fmt.Fprintf(&b, "%s%s {\n%s  %s;\n%s}\n", indent, head, indent, callExpr, indent)
	case len(f.results) > 1:
		fmt.Fprintf(&b, "%s%s {\n%s  final $l = %s as List;\n%s  return %s;\n%s}\n", indent, head, indent, callExpr, indent, dec, indent)
	default:
		fmt.Fprintf(&b, "%s%s {\n%s  final $r = %s;\n%s  return %s;\n%s}\n", indent, head, indent, callExpr, indent, dec, indent)
	}
	return b.String()
}

func usesRuntime(body string) bool {
	for _, id := range []string{"GoHandle", "GoValue", "GoJson", "GoOption", "$call", "$stream", "$enc", "$nn", "$bytes"} {
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
			// só interfaces com métodos expostos (io.Closer sem métodos gerados não acrescenta nada)
			if c.t.k == kHandle && !c.t.reader && types.IsInterface(c.t.named) && len(c.methods) > 0 {
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
				if best == nil || it.NumMethods() > best.t.named.Underlying().(*types.Interface).NumMethods() {
					best = i
				}
			}
			if best != nil {
				c.t.super = best.t
			}
		}
	}
}

func (e *dartEmitter) directRet(f *fn, l *dartLib) string {
	if len(f.results) == 0 {
		return "void"
	}
	return e.dt(f.results[0], l)
}

// nativeT: tipo dart:ffi (nativo, Dart) de um tipo direto.
func nativeT(t *tinfo) (string, string) {
	switch cat(t) {
	case "double":
		return "Double", "double"
	case "string", "value", "bytes": // bytes: + Int64 do tamanho ao lado
		return "Pointer<Uint8>", "Pointer<Uint8>"
	}
	return "Int64", "int"
}

// directBody: corpo Dart que chama o export IpfsD<n> (sem JSON) e declara o
// lookup dele na library.
func (e *dartEmitter) directBody(l *dartLib, f *fn, in string) string {
	l.ffi = true
	var nat, dart, args, pre, post []string
	if f.recv != nil {
		nat, dart, args = append(nat, "Int64"), append(dart, "int"), append(args, "$h")
	}
	for i, p := range f.params {
		n, d := nativeT(p.t)
		nat, dart = append(nat, n), append(dart, d)
		v := memberName(p.name)
		switch cat(p.t) {
		case "handle":
			args = append(args, v+".$h")
		case "bool":
			args = append(args, v+" ? 1 : 0")
		case "string", "value":
			s := fmt.Sprintf("$s%d", i)
			if cat(p.t) == "value" {
				v += ".value"
			}
			pre = append(pre, fmt.Sprintf("final %s = $cstr(%s);", s, v))
			post = append(post, fmt.Sprintf("$free(%s);", s))
			args = append(args, s)
		case "bytes": // buffer C com a cópia; o Go copia de novo
			s := fmt.Sprintf("$b%d", i)
			nat, dart = append(nat, "Int64"), append(dart, "int")
			pre = append(pre, fmt.Sprintf("final %s = $cbytes(%s);", s, v))
			post = append(post, fmt.Sprintf("$free(%s);", s))
			args = append(args, s, v+".length")
		default:
			args = append(args, v)
		}
	}
	out, ret := "$out", ""
	if len(f.results) == 1 {
		r := f.results[0]
		switch cat(r) {
		case "handle":
			ret = e.ref(r, l) + ".$h($nnH($out.value))"
		case "bool":
			ret = "$out.value != 0"
		case "double":
			out, ret = "$out.cast<Double>()", "$out.cast<Double>().value"
		case "string":
			out, ret = "$out.cast<Pointer<Uint8>>()", "$take($out.cast<Pointer<Uint8>>().value)"
		case "value": // NULL (nil do Go) vira IpfsException, como no JSON
			out, ret = "$out.cast<Pointer<Uint8>>()", e.ref(r, l)+"($take($nnP($out.cast<Pointer<Uint8>>().value)))"
		case "bytes": // nil → vazio, como no JSON
			out, ret = "$out.cast<Pointer<Uint8>>()", "$takeBytes($out.cast<Pointer<Uint8>>().value, $outN.value)"
		default:
			ret = "$out.value"
		}
	}
	outNat := "Pointer<Int64>"
	switch out {
	case "$out.cast<Double>()":
		outNat = "Pointer<Double>"
	case "$out.cast<Pointer<Uint8>>()":
		outNat = "Pointer<Pointer<Uint8>>"
	}
	nat, dart, args = append(nat, outNat), append(dart, outNat), append(args, out)
	if len(f.results) == 1 && cat(f.results[0]) == "bytes" {
		nat, dart, args = append(nat, "Pointer<Int64>"), append(dart, "Pointer<Int64>"), append(args, "$outN")
	}
	fn := fmt.Sprintf("_d%d", f.direct)
	l.lookups = append(l.lookups, fmt.Sprintf("final %s = $dylib.lookupFunction<Pointer<Uint8> Function(%s), Pointer<Uint8> Function(%s)>('IpfsD%d');\n",
		fn, strings.Join(nat, ", "), strings.Join(dart, ", "), f.direct))

	var b strings.Builder
	callLine := fmt.Sprintf("$check(%s(%s));", fn, strings.Join(args, ", "))
	if len(pre) == 0 {
		b.WriteString(in + callLine + "\n")
	} else {
		for _, p := range pre {
			b.WriteString(in + p + "\n")
		}
		fmt.Fprintf(&b, "%stry {\n%s  %s\n%s} finally {\n", in, in, callLine, in)
		for _, p := range post {
			b.WriteString(in + "  " + p + "\n")
		}
		b.WriteString(in + "}\n")
	}
	if ret != "" {
		b.WriteString(in + "return " + ret + ";\n")
	}
	return b.String()
}
