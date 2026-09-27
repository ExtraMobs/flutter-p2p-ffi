package main

import (
	"go/types"

	"golang.org/x/tools/go/types/typeutil"
)

// typeTable serializa types.Type como descritores JSON estruturados,
// deduplicados por identidade de tipo (types.Identical). Os nós referenciam
// tipos pelo índice na tabela; índices seguem a ordem de travessia
// (determinística). Tipos nomeados e parâmetros de tipo são registrados antes
// de expandir seus componentes, então tipos recursivos não entram em ciclo.
type typeTable struct {
	index typeutil.Map
	list  []jobject
	types []types.Type // tipo de cada entrada de list (mesmo índice)
}

func (tt *typeTable) ref(t types.Type) any {
	if t == nil {
		return nil
	}
	t = types.Unalias(t)
	if i := tt.index.At(t); i != nil {
		return i.(int)
	}
	i := len(tt.list)
	tt.index.Set(t, i)
	tt.list = append(tt.list, nil)
	tt.types = append(tt.types, t)
	tt.list[i] = tt.describe(t)
	return i
}

func (tt *typeTable) refs(n int, at func(int) types.Type) []any {
	out := make([]any, n)
	for i := range out {
		out[i] = tt.ref(at(i))
	}
	return out
}

func (tt *typeTable) tuple(t *types.Tuple) []any {
	return tt.refs(t.Len(), func(i int) types.Type { return t.At(i).Type() })
}

func (tt *typeTable) describe(t types.Type) jobject {
	switch t := t.(type) {
	case *types.Basic:
		return jobject{{"kind", "basic"}, {"name", t.Name()}}
	case *types.Named:
		d := jobject{{"kind", "named"}, {"pkg", pkgPath(t.Obj().Pkg())}, {"name", t.Obj().Name()}}
		if args := t.TypeArgs(); args != nil {
			d = append(d, jpair{"args", tt.refs(args.Len(), args.At)})
		}
		d = append(d, jpair{"underlying", tt.ref(t.Underlying())})
		if _, iface := t.Underlying().(*types.Interface); !iface {
			d = append(d, jpair{"methods", tt.methodSet(t)})
		}
		return d
	case *types.Pointer:
		return jobject{{"kind", "pointer"}, {"elem", tt.ref(t.Elem())}}
	case *types.Slice:
		return jobject{{"kind", "slice"}, {"elem", tt.ref(t.Elem())}}
	case *types.Array:
		return jobject{{"kind", "array"}, {"len", t.Len()}, {"elem", tt.ref(t.Elem())}}
	case *types.Map:
		return jobject{{"kind", "map"}, {"key", tt.ref(t.Key())}, {"elem", tt.ref(t.Elem())}}
	case *types.Chan:
		dir := map[types.ChanDir]string{types.SendRecv: "both", types.SendOnly: "send", types.RecvOnly: "recv"}[t.Dir()]
		return jobject{{"kind", "chan"}, {"dir", dir}, {"elem", tt.ref(t.Elem())}}
	case *types.Struct:
		fields := make([]jobject, t.NumFields())
		for i := range fields {
			f := t.Field(i)
			fields[i] = jobject{{"name", f.Name()}, {"type", tt.ref(f.Type())}, {"embedded", f.Embedded()}, {"tag", t.Tag(i)}}
		}
		return jobject{{"kind", "struct"}, {"fields", fields}}
	case *types.Interface:
		methods := make([]jobject, t.NumMethods())
		for i := range methods {
			m := t.Method(i)
			methods[i] = jobject{{"name", m.Name()}, {"type", tt.ref(m.Type())}}
		}
		return jobject{{"kind", "interface"}, {"methods", methods},
			{"embeddeds", tt.refs(t.NumEmbeddeds(), t.EmbeddedType)}}
	case *types.Signature:
		return jobject{{"kind", "func"}, {"params", tt.tuple(t.Params())},
			{"results", tt.tuple(t.Results())}, {"variadic", t.Variadic()}}
	case *types.Tuple:
		return jobject{{"kind", "tuple"}, {"elems", tt.tuple(t)}}
	case *types.TypeParam:
		return jobject{{"kind", "typeparam"}, {"name", t.Obj().Name()}, {"index", t.Index()},
			{"constraint", tt.ref(t.Constraint())}}
	case *types.Union:
		terms := make([]jobject, t.Len())
		for i := range terms {
			terms[i] = jobject{{"tilde", t.Term(i).Tilde()}, {"type", tt.ref(t.Term(i).Type())}}
		}
		return jobject{{"kind", "union"}, {"terms", terms}}
	default:
		return jobject{{"kind", "unknown"}, {"repr", types.TypeString(t, qualifier)}}
	}
}

func qualifier(p *types.Package) string { return p.Path() }

func pkgPath(p *types.Package) string {
	if p == nil {
		return "" // universo: error, comparable, any
	}
	return p.Path()
}

// methodSet lista o method set de *T (que contém o de T): nome, assinatura,
// caminho de embedding (index) e se o método só existe em *T (ptr).
func (tt *typeTable) methodSet(t *types.Named) []jobject {
	vset := types.NewMethodSet(t)
	pset := types.NewMethodSet(types.NewPointer(t))
	out := make([]jobject, 0, pset.Len())
	for i := 0; i < pset.Len(); i++ {
		sel := pset.At(i)
		m := sel.Obj()
		index := make([]int, len(sel.Index()))
		copy(index, sel.Index())
		out = append(out, jobject{
			{"name", m.Name()},
			{"type", tt.ref(m.Type())},
			{"index", index},
			{"ptr", vset.Lookup(m.Pkg(), m.Name()) == nil},
		})
	}
	return out
}
