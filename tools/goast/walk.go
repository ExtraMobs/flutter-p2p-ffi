package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"go/ast"
	"go/token"
	"go/types"
	"path/filepath"
	"reflect"
	"strings"
	"unicode"
	"unicode/utf8"
)

var (
	posType   = reflect.TypeOf(token.Pos(0))
	tokType   = reflect.TypeOf(token.Token(0))
	objType   = reflect.TypeOf((*ast.Object)(nil))
	scopeType = reflect.TypeOf((*ast.Scope)(nil))
)

// jobject é um objeto JSON com ordem de campos preservada (json.Marshal de
// mapas ordenaria alfabeticamente; a AST exige a ordem de declaração).
type jobject []jpair

type jpair struct {
	key string
	val any
}

func (j jobject) MarshalJSON() ([]byte, error) {
	var b bytes.Buffer
	b.WriteByte('{')
	for i, p := range j {
		if i > 0 {
			b.WriteByte(',')
		}
		k, err := json.Marshal(p.key)
		if err != nil {
			return nil, err
		}
		b.Write(k)
		b.WriteByte(':')
		v, err := json.Marshal(p.val)
		if err != nil {
			return nil, err
		}
		b.Write(v)
	}
	b.WriteByte('}')
	return b.Bytes(), nil
}

// walker serializa genericamente qualquer ast.Node via reflection e anota
// os nós com a informação de tipos (chaves com prefixo "$", que não colidem
// com campos da AST).
type walker struct {
	fset *token.FileSet
	info *types.Info
	pkg  *types.Package
	tt   *typeTable
	fold map[*types.Package]map[string]bool // exportados com gêmeo por caixa
}

// folded: o nome exportado de nível de pacote tem outro exportado igual a
// ele sem diferenciar caixa (`BOOL` e `Bool`), no mesmo pacote.
func (w *walker) folded(o types.Object) bool {
	if !o.Exported() {
		return false
	}
	set, ok := w.fold[o.Pkg()]
	if !ok {
		set = map[string]bool{}
		seen := map[string]string{}
		for _, n := range o.Pkg().Scope().Names() {
			if !token.IsExported(n) {
				continue
			}
			k := strings.ToLower(n)
			if prev, dup := seen[k]; dup {
				set[prev], set[n] = true, true
			}
			seen[k] = n
		}
		if w.fold == nil {
			w.fold = map[*types.Package]map[string]bool{}
		}
		w.fold[o.Pkg()] = set
	}
	return set[o.Name()]
}

func (w *walker) walk(v reflect.Value) any {
	if !v.IsValid() {
		return nil
	}
	t := v.Type()

	switch v.Kind() {
	case reflect.Pointer, reflect.Interface:
		if v.IsNil() {
			return nil
		}
		// *ast.Object e *ast.Scope criam ciclos: não seguir.
		if t == objType {
			o := v.Interface().(*ast.Object)
			return jobject{
				{"node", "Object"},
				{"name", o.Name},
				{"kind", o.Kind.String()},
			}
		}
		if t == scopeType {
			return nil
		}
		out := w.walk(v.Elem())
		if n, ok := v.Interface().(ast.Node); ok && v.Kind() == reflect.Pointer {
			if obj, ok := out.(jobject); ok {
				out = w.annotate(n, obj)
			}
		}
		return out
	}

	if t == posType {
		p := w.fset.Position(v.Interface().(token.Pos))
		if !p.IsValid() {
			return nil
		}
		return jobject{
			{"file", filepath.Base(p.Filename)},
			{"line", p.Line},
			{"column", p.Column},
			{"offset", p.Offset},
		}
	}
	if t == tokType {
		return v.Interface().(token.Token).String()
	}

	switch v.Kind() {
	case reflect.Struct:
		// Todo struct alcançável na árvore é um nó AST.
		fields := jobject{{"node", t.Name()}}
		for i := 0; i < t.NumField(); i++ {
			f := t.Field(i)
			if !f.IsExported() {
				continue
			}
			fields = append(fields, jpair{lowerFirst(f.Name), w.walk(v.Field(i))})
		}
		return fields
	case reflect.Slice, reflect.Array:
		if v.Kind() == reflect.Slice && v.IsNil() {
			return nil
		}
		list := make([]any, v.Len())
		for i := 0; i < v.Len(); i++ {
			list[i] = w.walk(v.Index(i))
		}
		return list
	case reflect.Map:
		if v.IsNil() {
			return nil
		}
		m := map[string]any{}
		for _, k := range v.MapKeys() {
			m[fmt.Sprint(k.Interface())] = w.walk(v.MapIndex(k))
		}
		return m
	default:
		return v.Interface()
	}
}

func lowerFirst(s string) string {
	r, size := utf8.DecodeRuneInString(s)
	return string(unicode.ToLower(r)) + s[size:]
}

// annotate anexa ao nó: "$type"/"$isType"/"$builtin"/"$value" (expressões),
// "$obj" (identificadores) e "$sel" (seletores).
func (w *walker) annotate(n ast.Node, obj jobject) jobject {
	if e, ok := n.(ast.Expr); ok && w.info != nil {
		if tv, ok := w.info.Types[e]; ok {
			if tv.Type != nil {
				obj = append(obj, jpair{"$type", w.tt.ref(tv.Type)})
			}
			if tv.IsType() {
				obj = append(obj, jpair{"$isType", true})
			}
			if tv.IsBuiltin() {
				obj = append(obj, jpair{"$builtin", true})
			}
			if tv.Value != nil {
				obj = append(obj, jpair{"$value", constValue(tv.Value)})
			}
		}
	}
	switch n := n.(type) {
	case *ast.Ident:
		// Instanciação de genérico (F[int], Stack[T]): argumentos de tipo.
		if inst, ok := w.info.Instances[n]; ok && inst.TypeArgs != nil {
			obj = append(obj, jpair{"$inst", w.tt.refs(inst.TypeArgs.Len(), inst.TypeArgs.At)})
		}
		if o := w.info.Defs[n]; o != nil {
			obj = append(obj, jpair{"$obj", w.objInfo(o, true)})
		} else if o := w.info.Uses[n]; o != nil {
			obj = append(obj, jpair{"$obj", w.objInfo(o, false)})
		}
	case *ast.SelectorExpr:
		if sel := w.info.Selections[n]; sel != nil {
			kind := map[types.SelectionKind]string{
				types.FieldVal: "field", types.MethodVal: "method", types.MethodExpr: "methodExpr",
			}[sel.Kind()]
			index := make([]int, len(sel.Index()))
			copy(index, sel.Index())
			obj = append(obj, jpair{"$sel", jobject{
				{"kind", kind},
				{"recv", w.tt.ref(sel.Recv())},
				{"index", index}, // caminho pelos campos embutidos
				{"indirect", sel.Indirect()},
			}})
		}
	}
	return obj
}

// objInfo descreve o objeto de um identificador. kind ∈ func | method | var |
// field | const | type | label | package | builtin | nil.
func (w *walker) objInfo(o types.Object, def bool) jobject {
	kind := "unknown"
	switch o := o.(type) {
	case *types.Func:
		kind = "func"
		if sig, ok := o.Type().(*types.Signature); ok && sig.Recv() != nil {
			kind = "method"
		}
	case *types.Var:
		kind = "var"
		if o.IsField() {
			kind = "field"
		}
	case *types.Const:
		kind = "const"
	case *types.TypeName:
		kind = "type"
	case *types.Label:
		kind = "label"
	case *types.PkgName:
		kind = "package"
	case *types.Builtin:
		kind = "builtin"
	case *types.Nil:
		kind = "nil"
	}
	d := jobject{{"name", o.Name()}, {"kind", kind}}
	if def {
		d = append(d, jpair{"def", true})
	}
	if pn, ok := o.(*types.PkgName); ok {
		d = append(d, jpair{"pkg", pn.Imported().Path()})
		return d
	}
	if o.Type() != nil && kind != "label" {
		d = append(d, jpair{"type", w.tt.ref(o.Type())})
	}
	// decl identifica o objeto (junto com pkg): distingue variáveis homônimas
	// em escopos diferentes.
	if p := w.fset.Position(o.Pos()); p.IsValid() {
		d = append(d, jpair{"decl", fmt.Sprintf("%s:%d", filepath.Base(p.Filename), p.Offset)})
	}
	if o.Pkg() != nil {
		d = append(d, jpair{"pkg", o.Pkg().Path()})
		if o.Parent() == o.Pkg().Scope() {
			d = append(d, jpair{"top", true})
			if w.folded(o) {
				d = append(d, jpair{"fold", true})
			}
		}
	}
	if f, ok := o.(*types.Var); ok && f.Embedded() {
		d = append(d, jpair{"embedded", true})
	}
	if c, ok := o.(*types.Const); ok {
		d = append(d, jpair{"value", constValue(c.Val())})
	}
	return d
}
