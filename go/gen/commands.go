package main

// Os comandos do RPC do kubo (`ipfs files stat`...) no Dart: o gerador percorre
// a árvore do kubo (core/commands.Root), como o servidor HTTP dele a vê, e
// escreve uma função por comando e um DTO por tipo de retorno (WIRE.md,
// "Comandos"; o host chama pela função 36, go/manual_commands.go). O tipo de
// cada campo e a ordem saem de cmdschema, o mesmo pacote que o host usa para
// codificar.

import (
	"bytes"
	"fmt"
	"hash/fnv"
	"io/fs"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strings"

	"github.com/ExtraMobs/transpiled_ipfs/go/cmdschema"
	cmds "github.com/ipfs/go-ipfs-cmds"
	corecmds "github.com/ipfs/kubo/core/commands"
)

// cmdSkip: comandos que não atravessam, com o motivo (API.md).
var cmdSkip = map[string]string{
	"shutdown":    "stops the daemon; in ipfs_ffi it is `IpfsNode.close`/`IpfsService.stop`",
	"mount":       "FUSE: mounts on the host's file system",
	"update":      "updates the kubo binary (not the case of ipfs_host)",
	"commands":    "the CLI help",
	"config edit": "opens $EDITOR in the host process",
}

// cmdByteOut: comandos que emitem um io.Reader (bytes, Stream<Uint8List>).
var cmdByteOut = setOf(`cat get files-read block-get key-export log-tail name-get diag-profile
multibase-decode multibase-encode multibase-transcode dag-get dag-export`)

// cmdRootOpts: as opções globais do Root que valem num comando no ipfs_ffi
// (as outras são do CLI ou do HTTP).
var cmdRootOpts = []string{"offline", "cid-base", "upgrade-cidv0-in-output"}

type cmdArg struct {
	name, dart string
	file       bool
	variadic   bool
	required   bool
}

type cmdOpt struct {
	name, dart string
	kind       reflect.Kind
}

type cmdInfo struct {
	path    []string
	c       *cmds.Command
	dart    string
	args    []cmdArg
	opts    []cmdOpt
	out     reflect.Type // nil = dinâmico
	mode    string       // typed, bytes, dyn (sempre Stream)
	skipped string
}

// cmdsPkg: o pacote Go dos comandos; as funções Dart ficam na library dele.
const cmdsPkg = "github.com/ipfs/kubo/core/commands"

// cmdEmitter escreve através do emissor principal: as funções dos comandos na
// library de core/commands e cada DTO na library do pacote Go dele, a mesma em
// que o gerador principal põe as classes daquele pacote. Um tipo que o gerador
// principal já escreve (peer.AddrInfo, mfs.NodeListing) não ganha outra classe:
// o comando monta a dele.
type cmdEmitter struct {
	de     *dartEmitter
	cur    *dartLib                  // a library sendo escrita (os imports vão para ela)
	names  map[reflect.Type]string   // struct → classe Dart
	libs   map[reflect.Type]*dartLib // struct → library dela
	shared map[reflect.Type]*tinfo   // struct que o gerador principal já escreve
	taken  map[*dartLib]map[string]reflect.Type
	order  []reflect.Type
}

func (e *cmdEmitter) imp(goPkg string) string {
	return e.de.imp(e.cur, "package:ipfs_ffi/"+dartPath(goPkg))
}

// walkCommands: os comandos executáveis, em ordem de caminho.
func walkCommands() []*cmdInfo {
	var out []*cmdInfo
	var walk func(path []string, c *cmds.Command)
	walk = func(path []string, c *cmds.Command) {
		if c.Run != nil && len(path) > 0 && c.Status != cmds.Removed {
			out = append(out, &cmdInfo{path: append([]string{}, path...), c: c})
		}
		for _, k := range sortedKeys(c.Subcommands) {
			walk(append(append([]string{}, path...), k), c.Subcommands[k])
		}
	}
	walk(nil, corecmds.Root)
	return out
}

// cmdName: o nome Dart de um nome do kubo ("ipfs-path", "peer ID", "cid-version").
func cmdName(s string) string {
	parts := strings.FieldsFunc(s, func(r rune) bool { return r == '-' || r == '_' || r == ' ' })
	var b strings.Builder
	for i, p := range parts {
		w := memberName(p)
		w = strings.TrimSuffix(w, "$")
		if i > 0 {
			w = capitalize(w)
		}
		b.WriteString(w)
	}
	return b.String()
}

// manualNames: os nomes públicos das libraries escritas à mão do kubo (o porte
// do `ipfs dag`): o comando com o mesmo nome Dart fica de fora (API.md).
func manualNames() map[string]bool {
	manual := map[string]bool{}
	_ = filepath.WalkDir("../lib/"+strings.TrimSuffix(dartPath("github.com/ipfs/kubo"), ".dart"), func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".dart") {
			return err
		}
		if src, err := os.ReadFile(path); err == nil && !bytes.HasPrefix(src, []byte(generatedHeader)) && !bytes.Contains(src, []byte("\npart of ")) {
			for _, n := range publicNames(src) {
				manual[n] = true
			}
		}
		return nil
	})
	return manual
}

// prepare: argumentos, opções, retorno e modo de cada comando.
func (e *cmdEmitter) prepare(cs []*cmdInfo, manual map[string]bool) {
	for _, ci := range cs {
		key := strings.Join(ci.path, " ")
		ci.dart = cmdName(strings.Join(ci.path, "-"))
		if why, ok := cmdSkip[ci.path[0]]; ok {
			ci.skipped = why
		} else if why, ok := cmdSkip[key]; ok {
			ci.skipped = why
		} else if manual[ci.dart] {
			ci.skipped = "hand port with the same name (`" + dartPath(cmdsPkg+"/dag") + "`)"
		}
		if ci.skipped != "" {
			continue
		}
		used := map[string]bool{"node": true, "ctx": true}
		for _, a := range ci.c.Arguments {
			ca := cmdArg{name: a.Name, dart: dartParamName(cmdName(a.Name)), file: a.Type == cmds.ArgFile, variadic: a.Variadic, required: a.Required}
			for used[ca.dart] {
				ca.dart += "Arg"
			}
			used[ca.dart] = true
			ci.args = append(ci.args, ca)
		}
		defs, _ := corecmds.Root.GetOptions(ci.path)
		seen := map[string]bool{}
		add := func(o cmds.Option) {
			n := o.Names()[0]
			if seen[n] {
				return
			}
			seen[n] = true
			co := cmdOpt{name: n, dart: dartParamName(cmdName(n)), kind: o.Type()}
			for used[co.dart] {
				co.dart += "Option"
			}
			used[co.dart] = true
			ci.opts = append(ci.opts, co)
		}
		// as do próprio comando e as herdadas (não as do Root), depois as globais úteis
		rootNames := map[string]bool{}
		for _, o := range corecmds.Root.Options {
			for _, n := range o.Names() {
				rootNames[n] = true
			}
		}
		var own []string
		for n, o := range defs {
			if !rootNames[n] && o.Names()[0] == n {
				own = append(own, n)
			}
		}
		sort.Strings(own)
		for _, o := range ci.c.Options { // na ordem do kubo primeiro
			add(o)
		}
		for _, n := range own {
			add(defs[n])
		}
		for _, n := range cmdRootOpts {
			if o, ok := defs[n]; ok {
				add(o)
			}
		}
		if ci.c.Type != nil {
			ci.out = reflect.TypeOf(ci.c.Type)
			if ci.out.Kind() == reflect.Pointer {
				ci.out = ci.out.Elem()
			}
		}
		// todo comando é Stream (decisão do dono): quem usa decide entre
		// .single, .first e toList(); o modo só escolhe o tipo do item
		switch {
		case cmdByteOut[strings.Join(ci.path, "-")]:
			ci.mode = "bytes"
		case ci.out == nil:
			ci.mode = "dyn"
		default:
			ci.mode = "typed"
		}
		if ci.out != nil {
			e.collect(ci.out, typeName(cmdName(strings.Join(ci.path, "-")))+"Output")
		}
	}
}

// collect registra as classes dos structs alcançáveis de [t], cada uma na
// library do pacote Go dela.
func (e *cmdEmitter) collect(t reflect.Type, hint string) {
	switch cmdschema.Of(t) {
	case cmdschema.List, cmdschema.Map, cmdschema.Ptr:
		e.collect(t.Elem(), hint)
	case cmdschema.Struct:
		if _, ok := e.libs[t]; ok {
			return
		}
		pkg := t.PkgPath()
		if pkg == "" {
			pkg = cmdsPkg // struct sem nome: fica com os comandos
		}
		l := e.de.lib(pkg)
		e.libs[t] = l
		if c, ok := l.classes[pkg+"."+t.Name()]; ok && t.Name() != "" && c.t.k == kDTO {
			e.shared[t] = c.t
			e.names[t] = className(c.t)
		} else {
			name := typeName(t.Name())
			if t.Name() == "" {
				name = hint
			}
			for _, c := range l.classes {
				if className(c.t) == name {
					panic(fmt.Sprintf("gen: o DTO de comando %v repete a classe %s de lib/%s", t, name, l.path))
				}
			}
			if e.taken[l] == nil {
				e.taken[l] = map[string]reflect.Type{}
			}
			if other, ok := e.taken[l][name]; ok && other != t {
				panic(fmt.Sprintf("gen: dois tipos de comando com o nome Dart %s em lib/%s: %v e %v", name, l.path, other, t))
			}
			e.names[t], e.taken[l][name] = name, t
			e.order = append(e.order, t)
		}
		for _, f := range cmdschema.Fields(t) {
			e.collect(f.Type, e.names[t]+f.Name)
		}
	}
}

// ref: a classe Dart de um struct, com o prefixo se for de outra library.
func (e *cmdEmitter) ref(t reflect.Type) string {
	if ti, ok := e.shared[t]; ok {
		return e.de.ref(ti, e.cur)
	}
	if l := e.libs[t]; l != e.cur {
		return e.de.imp(e.cur, "package:ipfs_ffi/"+l.path) + "." + e.names[t]
	}
	return e.names[t]
}

// decStruct: lê um struct; o compartilhado com o gerador principal é montado
// pelo construtor da classe dele, campo a campo, na ordem do esquema.
func (e *cmdEmitter) decStruct(t reflect.Type, r string) string {
	ti, ok := e.shared[t]
	if !ok {
		return e.ref(t) + ".$dec(" + r + ")"
	}
	have := map[string]bool{}
	for _, f := range ti.fields {
		if f.skipped == "" {
			have[memberName(f.name)] = true
		}
	}
	var args []string
	for _, f := range cmdschema.Fields(t) {
		n := memberName(f.Name)
		if !have[n] {
			panic(fmt.Sprintf("gen: o campo %s.%s do comando não existe na classe %s", t, f.Name, className(ti)))
		}
		args = append(args, n+": "+e.dec(f.Type, r))
	}
	return e.ref(t) + "(" + strings.Join(args, ", ") + ")"
}

func pkgOf(t reflect.Type) string {
	p := t.PkgPath()
	return p[strings.LastIndex(p, "/")+1:]
}

// textClass: as classes-valor do Dart (no pacote Go delas) dos Text conhecidos.
var textClass = map[string]string{
	"github.com/ipfs/go-cid.Cid":                     "Cid",
	"github.com/libp2p/go-libp2p/core/peer.ID":       "Id",
	"github.com/multiformats/go-multiaddr.Multiaddr": "Multiaddr",
}

func (e *cmdEmitter) textRef(t reflect.Type) string {
	c, ok := textClass[t.PkgPath()+"."+t.Name()]
	if !ok {
		return ""
	}
	if "package:ipfs_ffi/"+dartPath(t.PkgPath()) == "package:ipfs_ffi/"+e.cur.path {
		return c
	}
	return e.imp(t.PkgPath()) + "." + c
}

// dt: o tipo Dart de [t].
func (e *cmdEmitter) dt(t reflect.Type) string {
	switch cmdschema.Of(t) {
	case cmdschema.Bool:
		return "bool"
	case cmdschema.Int, cmdschema.Uint:
		return "int"
	case cmdschema.Float:
		return "double"
	case cmdschema.String:
		return "String"
	case cmdschema.Bytes:
		return "Uint8List?"
	case cmdschema.Text:
		if c := e.textRef(t); c != "" {
			return c
		}
		return "String"
	case cmdschema.Time:
		return "DateTime?"
	case cmdschema.Duration:
		return "Duration"
	case cmdschema.List:
		return "List<" + e.dt(t.Elem()) + ">"
	case cmdschema.Map:
		return "Map<String, " + e.dt(t.Elem()) + ">"
	case cmdschema.Struct:
		return e.ref(t)
	case cmdschema.Ptr:
		inner := e.dt(t.Elem())
		if strings.HasSuffix(inner, "?") {
			return inner
		}
		return inner + "?"
	case cmdschema.Any:
		return "Object?"
	}
	panic("gen: comando com tipo que não atravessa: " + t.String())
}

// dec: a expressão que lê um [t] de [r].
func (e *cmdEmitter) dec(t reflect.Type, r string) string {
	switch cmdschema.Of(t) {
	case cmdschema.Bool:
		return r + ".b()"
	case cmdschema.Int, cmdschema.Uint:
		return r + ".i64()"
	case cmdschema.Float:
		return r + ".f64()"
	case cmdschema.String:
		return r + ".str()"
	case cmdschema.Bytes:
		return r + ".bytes()"
	case cmdschema.Text:
		if c := e.textRef(t); c != "" {
			return c + "(" + r + ".str())"
		}
		return r + ".str()"
	case cmdschema.Time:
		return r + ".p() ? " + r + ".time() : null"
	case cmdschema.Duration:
		return "Duration(microseconds: " + r + ".i64() ~/ 1000)"
	case cmdschema.List:
		return r + ".list(() => " + e.dec(t.Elem(), r) + ")"
	case cmdschema.Map:
		return r + ".map(() => " + r + ".str(), () => " + e.dec(t.Elem(), r) + ")"
	case cmdschema.Struct:
		return e.decStruct(t, r)
	case cmdschema.Ptr:
		inner := e.dec(t.Elem(), r)
		if strings.Contains(inner, " ? ") { // já com presença própria (time)
			inner = "(" + inner + ")"
		}
		return r + ".p() ? " + inner + " : null"
	case cmdschema.Any:
		return r + ".any()"
	}
	panic("gen: comando com tipo que não atravessa: " + t.String())
}

func optDart(k reflect.Kind) string {
	switch k {
	case reflect.Bool:
		return "bool?"
	case reflect.Int, reflect.Uint, reflect.Int64, reflect.Uint64:
		return "int?"
	case reflect.Float64:
		return "double?"
	case reflect.Array:
		return "List<String>?"
	}
	return "String?"
}

// emitCommands: as funções dos comandos (na library de core/commands) e os DTOs
// (cada um na library do pacote Go dele), a seção do API.md, o teste de fumaça
// e o hash do esquema (vai no Hello, com o da tabela).
func emitCommands(de *dartEmitter, manual map[string]bool) (api, smoke string, hash uint64) {
	e := &cmdEmitter{de: de, names: map[reflect.Type]string{}, libs: map[reflect.Type]*dartLib{},
		shared: map[reflect.Type]*tinfo{}, taken: map[*dartLib]map[string]reflect.Type{}}
	cmdsLib := de.lib(cmdsPkg)
	e.cur = cmdsLib
	cs := walkCommands()
	e.prepare(cs, manual)
	h := fnv.New64a()
	var body, md, sm strings.Builder
	fmt.Fprintf(&md, "\n## RPC commands (`ipfs ...`) → `package:ipfs_ffi/%s`\n\n", cmdsLib.path)
	md.WriteString("Generated from the kubo command tree (`core/commands.Root`); the host calls them like the kubo HTTP server (function 36 of `WIRE.md`). Each result type lives in the library of its Go package.\n\n| Command | Dart | Returns |\n|---|---|---|\n")
	var skipped []string
	for _, ci := range cs {
		key := strings.Join(ci.path, " ")
		if ci.skipped != "" {
			skipped = append(skipped, fmt.Sprintf("- `ipfs %s`: %s", key, ci.skipped))
			continue
		}
		e.cur = cmdsLib
		ret, call := e.ret(ci)
		var params []string
		params = append(params, e.imp("github.com/ipfs/kubo/core")+".IpfsNode node", e.de.imp(cmdsLib, "package:ipfs_ffi/go/context.dart")+".Context ctx")
		var args, fls, smArgs []string
		for _, a := range ci.args {
			get := fmt.Sprintf("a.s('%s', '%s')", key, a.name)
			if a.file {
				get = fmt.Sprintf("a.f('%s', '%s')", key, a.name)
			}
			switch {
			case a.variadic:
				smArgs = append(smArgs, "["+get+"]")
			case a.required:
				smArgs = append(smArgs, get)
			default:
				smArgs = append(smArgs, "null")
			}
			t := "String"
			if a.file {
				t = e.imp("github.com/ipfs/boxo/files") + ".Node"
			}
			switch {
			case a.variadic:
				params = append(params, "List<"+t+"> "+a.dart)
			case a.required:
				params = append(params, t+" "+a.dart)
			default:
				params = append(params, t+"? "+a.dart)
			}
			switch {
			case a.file && a.variadic:
				fls = append(fls, "..."+a.dart)
			case a.file && a.required:
				fls = append(fls, a.dart)
			case a.file:
				fls = append(fls, "if ("+a.dart+" != null) "+a.dart)
			case a.variadic:
				args = append(args, "..."+a.dart)
			case a.required:
				args = append(args, a.dart)
			default:
				args = append(args, "if ("+a.dart+" != null) "+a.dart)
			}
		}
		var named, optMap []string
		for _, o := range ci.opts {
			named = append(named, optDart(o.kind)+" "+o.dart)
			optMap = append(optMap, fmt.Sprintf("'%s': %s", o.name, o.dart))
		}
		sig := strings.Join(params, ", ")
		if len(named) > 0 {
			sig += ", {" + strings.Join(named, ", ") + "}"
		}
		tag := strings.TrimSpace(ci.c.Helptext.Tagline)
		fmt.Fprintf(&body, "/// `ipfs %s`: %s\n", key, tag)
		switch ci.c.Status {
		case cmds.Experimental:
			body.WriteString("///\n/// Experimental in kubo.\n")
		case cmds.Deprecated:
			body.WriteString("@Deprecated('deprecated in kubo')\n")
		}
		fmt.Fprintf(&body, "%s %s(%s) =>\n    %s(node, ctx, '%s', [%s], [%s], {%s}%s);\n\n",
			ret, ci.dart, sig, call.fn, key, strings.Join(args, ", "), strings.Join(fls, ", "), strings.Join(optMap, ", "), call.dec)
		fmt.Fprintf(&md, "| `ipfs %s` | `%s` | `%s` |\n", key, ci.dart, ret)
		fmt.Fprintf(&sm, "  '%s': (a) => k.%s(%s),\n", key, ci.dart, strings.Join(append([]string{"a.node", "a.ctx"}, smArgs...), ", "))
		fmt.Fprintf(h, "%s|%s|%v|%v|%s\n", key, sig, ci.args, ci.opts, ret)
	}
	cmdsLib.extra = append(cmdsLib.extra, body.String())
	cmdsLib.bytes = cmdsLib.bytes || strings.Contains(body.String(), "Uint8List")
	for _, t := range e.order {
		l := e.libs[t]
		e.cur = l
		src := e.class(t)
		l.extra = append(l.extra, src)
		l.bytes = l.bytes || strings.Contains(src, "Uint8List")
		fmt.Fprintf(h, "%s.%s=%s\n", t.PkgPath(), e.names[t], e.schema(t))
	}
	if len(skipped) > 0 {
		md.WriteString("\nLeft out:\n\n" + strings.Join(skipped, "\n") + "\n")
	}
	return md.String(), smokeDart(sm.String(), cmdsLib.path), h.Sum64()
}

type cmdCall struct{ fn, dec string }

// ret: o tipo devolvido e o ajudante do runtime (lib/src/runtime/commands.dart).
func (e *cmdEmitter) ret(ci *cmdInfo) (string, cmdCall) {
	switch ci.mode {
	case "bytes":
		return "Stream<Uint8List>", cmdCall{fn: "$cmdBytes"}
	case "dyn":
		return "Stream<Object?>", cmdCall{fn: "$cmdDynStream"}
	}
	return "Stream<" + e.dt(ci.out) + ">", cmdCall{fn: "$cmdStream", dec: ", (r) => " + e.dec(ci.out, "r")}
}

// class: o DTO de um struct de saída.
func (e *cmdEmitter) class(t reflect.Type) string {
	name := e.names[t]
	fs := cmdschema.Fields(t)
	var b strings.Builder
	what := t.String()
	if t.Name() == "" {
		what = "struct"
	}
	fmt.Fprintf(&b, "/// Go: `%s` (a kubo command output).\nfinal class %s {\n", what, name)
	if len(fs) == 0 {
		fmt.Fprintf(&b, "  %s.$dec($R r);\n}\n\n", name)
		return b.String()
	}
	var inits []string
	used := map[string]bool{}
	var decls strings.Builder
	for _, f := range fs {
		n := memberName(f.Name)
		for used[n] {
			n += "$"
		}
		used[n] = true
		inits = append(inits, n+" = "+e.dec(f.Type, "r"))
		k := f.Type.Kind()
		fmt.Fprintf(&decls, "\n  /// Go: `%s`.%s\n  final %s %s;\n", f.Name, u64Doc(k == reflect.Uint || k == reflect.Uint64 || k == reflect.Uintptr), e.dt(f.Type), n)
	}
	fmt.Fprintf(&b, "  %s.$dec($R r)\n      : %s;\n%s}\n\n", name, strings.Join(inits, ",\n        "), decls.String())
	return b.String()
}

// schema: a forma de [t] para o hash (nomes e tipos Go dos campos, em ordem).
func (e *cmdEmitter) schema(t reflect.Type) string {
	var parts []string
	for _, f := range cmdschema.Fields(t) {
		parts = append(parts, f.Name+":"+f.Type.String())
	}
	return strings.Join(parts, ",")
}

// smokeDart: a tabela do teste de fumaça (test/src/commands_smoke.dart): cada
// comando gerado chamado com os argumentos obrigatórios que o teste fornece
// (SmokeArgs), para test/commands_smoke_test.dart rodar todos.
func smokeDart(entries, cmdsPath string) string {
	return generatedHeader + ` from the kubo command tree; do not edit.

// Every generated kubo command, called with the arguments the smoke test
// provides (test/commands_smoke_test.dart).
import 'package:ipfs_ffi/` + dartPath("github.com/ipfs/boxo/files") + `' as files;
import 'package:ipfs_ffi/` + dartPath("context") + `' as context;
import 'package:ipfs_ffi/` + dartPath("github.com/ipfs/kubo/core") + `' as core;
import 'package:ipfs_ffi/` + cmdsPath + `' as k;

/// What a command needs: the node, a ctx, and a value per required argument.
abstract interface class SmokeArgs {
  core.IpfsNode get node;
  context.Context get ctx;

  /// The string for argument [arg] of command [cmd].
  String s(String cmd, String arg);

  /// The file for argument [arg] of command [cmd].
  files.Node f(String cmd, String arg);
}

/// Command path → the call.
final smokeCommands = <String, Stream<Object?> Function(SmokeArgs a)>{
` + entries + `};
`
}
