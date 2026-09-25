package main

import (
	"go/constant"
	"go/types"
	"strconv"

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
		return append(d, jpair{"underlying", tt.ref(t.Underlying())})
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

func pkgPath(p *types.Package) string {
	if p == nil {
		return "" // universo: error, comparable, any
	}
	return p.Path()
}

// constValue serializa um valor constante. Strings vão decodificadas (o
// consumidor nunca interpreta literais Go); ints em decimal exato.
func constValue(v constant.Value) jobject {
	switch v.Kind() {
	case constant.String:
		return jobject{{"kind", "string"}, {"value", constant.StringVal(v)}}
	case constant.Bool:
		return jobject{{"kind", "bool"}, {"value", constant.BoolVal(v)}}
	case constant.Int:
		return jobject{{"kind", "int"}, {"value", v.ExactString()}}
	case constant.Float:
		f, _ := constant.Float64Val(v)
		return jobject{{"kind", "float"}, {"value", strconv.FormatFloat(f, 'g', -1, 64)}}
	case constant.Complex:
		re, _ := constant.Float64Val(constant.Real(v))
		im, _ := constant.Float64Val(constant.Imag(v))
		return jobject{{"kind", "complex"}, {"real", strconv.FormatFloat(re, 'g', -1, 64)},
			{"imag", strconv.FormatFloat(im, 'g', -1, 64)}}
	default:
		return jobject{{"kind", "unknown"}}
	}
}
