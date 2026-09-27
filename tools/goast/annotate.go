package main

import (
	"fmt"
	"go/ast"
	"go/token"
	"go/types"
	"path/filepath"
	"strings"
)

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
