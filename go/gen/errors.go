package main

import (
	"go/types"
	"strings"
	"text/template"
)

// goError: um erro do Go com classe de exceção no Dart (WIRE.md, evento
// `erro`): uma sentinela exportada (`var ErrX = errors.New(...)`) ou um tipo
// exportado que implementa `error`, de um pacote com library. O host manda o
// id de cada elo da corrente que for um deles; o Dart lança a classe.
type goError struct {
	id     int
	key    string         // pacote.Nome, como no roots.txt
	lib    *dartLib       // a library do pacote onde o nome foi achado
	obj    types.Object   // *types.Var (sentinela) ou *types.TypeName (tipo)
	named  *types.Named   // o tipo (só para tipos)
	ptr    bool           // o tipo implementa error só por ponteiro (*T)
	fields []goErrorField // campos que atravessam
	skip   []string       // campos que não atravessam (API.md)
	name   string         // a classe Dart
	why    string         // fora, e por quê (API.md)
}

type goErrorField struct {
	name string
	t    *tinfo
}

// fixedErrors: os erros que já têm classe no runtime (GolangEofException...;
// wire.go errData os reconhece com errors.Is e manda o código fixo).
var fixedErrors = setOf(`io.EOF io.ErrUnexpectedEOF context.Canceled context.DeadlineExceeded
github.com/ipfs/go-ipld-format.ErrNotFound github.com/ipld/go-car/v2/storage.ErrNotFound
github.com/ipld/go-car/v2/index.ErrNotFound`)

var errorIface = types.Universe.Lookup("error").Type().Underlying().(*types.Interface)

// errorClasses: as sentinelas e os tipos de erro exportados do pacote de cada
// library (sem linha no roots.txt, como as constantes). Fica de fora, com o
// motivo, o tipo genérico, o nome que já é de outra classe da library e os
// que têm classe fixa no runtime.
func (e *dartEmitter) errorClasses() []*goError {
	var out []*goError
	seen := map[string]bool{} // o mesmo tipo por um alias em outro pacote
	for _, path := range sortedKeys(e.libs) {
		l := e.libs[path]
		pkg := e.m.load(l.goPath)
		if pkg == nil {
			continue
		}
		taken := map[string]bool{}
		for _, c := range l.classes {
			taken[className(e.m, c.t)] = true
		}
		for _, name := range pkg.Scope().Names() {
			obj := pkg.Scope().Lookup(name)
			if !obj.Exported() {
				continue
			}
			ge := &goError{key: l.goPath + "." + name, lib: l, obj: obj, name: qualType(l.path, name)}
			switch o := obj.(type) {
			case *types.Var:
				if !types.Identical(o.Type(), types.Universe.Lookup("error").Type()) {
					continue
				}
			case *types.TypeName:
				named, ok := types.Unalias(o.Type()).(*types.Named)
				if !ok || types.IsInterface(named) {
					continue
				}
				switch {
				case types.Implements(named, errorIface):
				case types.Implements(types.NewPointer(named), errorIface):
					ge.ptr = true
				default:
					continue
				}
				if seen[objKey(named.Obj())] {
					continue
				}
				seen[objKey(named.Obj())] = true
				ge.named = named
				if named.TypeParams().Len() > 0 {
					ge.why = "generic error type"
				}
			default:
				continue
			}
			switch {
			case ge.why != "":
			case e.m.platformDecl[ge.key]:
				ge.why = platformWhy
			case fixedErrors[ge.key]:
				ge.why = "has its runtime class (`GolangEofException`, `GolangNotFoundException`...)"
			case taken[ge.name]:
				ge.why = "error whose Dart class name `" + ge.name + "` another class of the library has"
			default:
				taken[ge.name] = true
				if ge.named != nil {
					e.errorFields(ge)
				}
			}
			out = append(out, ge)
		}
	}
	id := 0
	for _, ge := range out {
		if ge.why == "" {
			id++
			ge.id = id
		}
	}
	return out
}

// errorFields: os campos exportados do tipo de erro que atravessam como valor
// (básicos, bytes, tipos-valor); um campo error fica de fora (é o próximo elo
// da corrente).
func (e *dartEmitter) errorFields(ge *goError) {
	st, ok := ge.named.Underlying().(*types.Struct)
	if !ok {
		return
	}
	for i := 0; i < st.NumFields(); i++ {
		f := st.Field(i)
		if !f.Exported() || f.Embedded() {
			continue
		}
		t := e.m.classify(f.Type())
		switch {
		case t.k == kError:
			ge.skip = append(ge.skip, f.Name()+" (the next link of the chain)")
		case (t.k == kBasic || t.k == kValue) && !t.ptr, t.k == kBytes:
			ge.fields = append(ge.fields, goErrorField{f.Name(), t})
		default:
			ge.skip = append(ge.skip, f.Name())
		}
	}
}

// The templates of what errors.go writes. The output goes through gofmt and
// dart format, so the indentation here is only for reading; {{code x}} puts
// x between backticks (a raw string cannot hold one).
var errTmpl = template.Must(template.New("").Funcs(template.FuncMap{
	"code": func(s string) string { return "`" + s + "`" },
}).Parse(`
{{define "dartClass"}}
/// Go: {{code .Doc}}: an error. Thrown as this class when it is the outermost
/// link of the error chain with a class; otherwise in {{code "causes"}} ({{code "isA"}}, {{code "find"}}).
class {{.Name}} extends GolangException {
{{- if .Fields}}
  {{.Name}}.$(super.base, $R r)
      : {{range $i, $f := .Fields}}{{if $i}}, {{end}}{{$f.Member}} = {{$f.Dec}}{{end}},
        super.$from();
{{range .Fields}}
  /// Go: {{code .Go}}.
  final {{.Type}} {{.Member}};
{{end}}
{{- else}}
  {{.Name}}.$(super.base) : super.$from();
{{- end}}

  @override
  String toString() => '{{.GoName}}: $message';
}
{{end}}

{{define "dartTypes"}}
// Generated by go/gen from the exposed packages; do not edit.

/// The classes of the Go errors (WIRE.md, {{code "error"}} event), by id: the
/// runtime builds each link of an error chain that has one, and throws the
/// outermost.
library;

import 'package:p2p_ffi/src/runtime.dart';
{{range .Imports}}import '{{.URI}}' as {{.Alias}};
{{end}}
final $errorTypes = <int, GolangException Function(GolangException base, $R r)>{
{{- range .Makes}}
  {{.ID}}: (b, r) => {{.Ref}}.$(b{{if .Fields}}, r{{end}}),
{{- end}}
};
{{end}}

{{define "goErrClass"}}
// errSentinels: as sentinelas com classe Dart (WIRE.md, evento {{code "erro"}}).
// Um mesmo valor pode ter mais de um nome (os.ErrNotExist é fs.ErrNotExist):
// o elo ganha todas as classes dele.
var errSentinels = []struct {
	err error
	id  uint32
}{
	{{- range .Sentinels}}
	{ {{- .Ref}}, {{.ID -}} },
	{{- end}}
}

// errClass: as classes Dart do elo de erro e e o codificador dos campos de
// cada uma (WIRE.md, evento {{code "erro"}}); nenhuma quando ele não tem classe.
func errClass(e error) (out []errLink) {
	for _, s := range errSentinels {
		if sameErr(e, s.err) {
			out = append(out, errLink{id: s.id})
		}
	}
	switch v := e.(type) {
	{{- range .Typed}}
	case *{{.Type}}:
		if v != nil {
			out = append(out, errLink{id: {{.ID}}, enc: {{template "goEnc" .}}})
		}
	{{- if .ByValue}}
	case {{.Type}}:
		out = append(out, errLink{id: {{.ID}}, enc: {{template "goEnc" .}}})
	{{- end}}
	{{- end}}
	}
	return out
}
{{end}}

{{define "goEnc"}}
{{- if .Fields}}func(w *writer) {
	{{- range .Fields}}
		{{.Enc}}(w, v.{{.Go}})
	{{- end}}
	}
{{- else}}nil{{end}}
{{- end}}

{{define "api"}}
## Go errors with a Dart class

Each is a {{code "GolangException"}} subclass in the library of its package: thrown when it is
the outermost link of the error chain with a class, otherwise in {{code "causes"}}
({{code "isA"}}, {{code "find"}}). Fields that are another {{code "error"}} are the next link
of the chain.

| Go | Dart | Fields |
|---|---|---|
{{range .Classes}}| {{code .Doc}} | {{code .Name}} in {{code .Lib}} | {{.Fields}} |
{{end}}
{{- if .Omitted}}
Without a class (they cross as {{code "GolangException"}}, with the message and the chain's
texts):

{{range .Omitted}}- {{code .Doc}}: {{.Why}}
{{end}}
{{- end}}
{{end}}
`))

// run executes the template [name] with [data].
func runTmpl(name string, data any) string {
	var b strings.Builder
	if err := errTmpl.ExecuteTemplate(&b, name, data); err != nil {
		panic(err)
	}
	return b.String()
}

// errDoc: how the error is written in the docs (the var, or the type).
func errDoc(ge *goError) string {
	if ge.named != nil {
		return types.TypeString(ge.named, shortQual)
	}
	return goDoc(ge.obj)
}

// emitErrorClasses: a classe de cada erro na library do pacote dele, e o
// src/error_types.dart (o id → a classe, que o runtime lança).
func (e *dartEmitter) emitErrorClasses(errs []*goError) string {
	type field struct{ Go, Member, Type, Dec string }
	type make struct {
		ID     int
		Ref    string
		Fields bool
	}
	src := &dartLib{path: "src/error_types.dart", prefix: map[string]string{}, classes: map[string]*dclass{}}
	var makes []make
	for _, ge := range errs {
		if ge.why != "" {
			continue
		}
		l := ge.lib
		var fs []field
		for _, f := range ge.fields {
			fs = append(fs, field{f.name, memberName(f.name), e.dt(f.t, l), e.dec(f.t, "r", l, false)})
		}
		l.extra = append(l.extra, runTmpl("dartClass", map[string]any{
			"Doc": errDoc(ge), "Name": ge.name, "Fields": fs,
			"GoName": ge.obj.Pkg().Name() + "." + ge.obj.Name(),
		}))
		makes = append(makes, make{ge.id, e.imp(src, pkgPrefix+l.path) + "." + ge.name, len(fs) > 0})
	}
	type imp struct{ URI, Alias string }
	var imps []imp
	for _, uri := range sortedKeys(src.prefix) {
		imps = append(imps, imp{uri, src.prefix[uri]})
	}
	return runTmpl("dartTypes", map[string]any{"Imports": imps, "Makes": makes})
}

// errClass: o errClass do zz_generated.go: o id da classe do elo de erro e o
// codificador dos campos dele (0 = sem classe). Uma sentinela compara por ==
// (o elo, não a corrente: errData percorre os elos); um tipo, pelo type
// switch, por ponteiro e, quando o método é do valor, também por valor.
func (g *goEmitter) errClass(errs []*goError) string {
	type sentinel struct {
		Ref string
		ID  int
	}
	type field struct{ Go, Enc string }
	type typed struct {
		Type    string
		ID      int
		ByValue bool
		Fields  []field
	}
	var ss []sentinel
	var ts []typed
	for _, ge := range errs {
		switch {
		case ge.why != "":
		case ge.named == nil:
			ss = append(ss, sentinel{g.qual(ge.obj.Pkg()) + "." + ge.obj.Name(), ge.id})
		default:
			t := typed{Type: g.ts(ge.named), ID: ge.id, ByValue: !ge.ptr}
			for _, f := range ge.fields {
				t.Fields = append(t.Fields, field{f.name, g.enc(f.t)})
			}
			ts = append(ts, t)
		}
	}
	return runTmpl("goErrClass", map[string]any{"Sentinels": ss, "Typed": ts})
}

// errorsAPI: a seção do API.md com os erros que têm classe e os que ficaram
// de fora.
func errorsAPI(errs []*goError) string {
	type class struct{ Doc, Name, Lib, Fields string }
	type omitted struct{ Doc, Why string }
	var cs []class
	var os []omitted
	for _, ge := range errs {
		if ge.why != "" {
			os = append(os, omitted{goDoc(ge.obj), ge.why})
			continue
		}
		var fs []string
		for _, f := range ge.fields {
			fs = append(fs, memberName(f.name))
		}
		cell := strings.Join(fs, ", ")
		if len(ge.skip) > 0 {
			cell = strings.TrimSpace(cell + " (not crossing: " + strings.Join(ge.skip, ", ") + ")")
		}
		cs = append(cs, class{errDoc(ge), ge.name, "lib/" + ge.lib.path, cell})
	}
	return runTmpl("api", map[string]any{"Classes": cs, "Omitted": os})
}
