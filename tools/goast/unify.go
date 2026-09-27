package main

import "go/types"

// instanceFor: a instância da interface genérica g que t pode satisfazer, com
// os argumentos tirados dos métodos de t (o parâmetro de g na assinatura de
// um método de g casa com o tipo na mesma posição no método de t), ou nil.
func instanceFor(g *types.Named, t types.Type) *types.Named {
	tps := g.TypeParams()
	it := g.Underlying().(*types.Interface)
	bind := make([]types.Type, tps.Len())
	for i := 0; i < it.NumMethods(); i++ {
		m := it.Method(i)
		obj, _, _ := types.LookupFieldOrMethod(t, true, m.Pkg(), m.Name())
		f, ok := obj.(*types.Func)
		if !ok {
			return nil
		}
		unify(m.Type(), f.Type(), tps, bind)
	}
	for _, b := range bind {
		if b == nil {
			return nil
		}
	}
	inst, err := types.Instantiate(nil, g, bind, true)
	if err != nil {
		return nil
	}
	n, _ := inst.(*types.Named)
	return n
}

// unify liga os parâmetros de tps que aparecem em p aos tipos de a na mesma
// posição (o primeiro vínculo vale; a checagem final é do Implements).
func unify(p, a types.Type, tps *types.TypeParamList, bind []types.Type) {
	switch p := p.(type) {
	case *types.TypeParam:
		for i := 0; i < tps.Len(); i++ {
			if tps.At(i) == p && bind[i] == nil {
				bind[i] = a
			}
		}
	case *types.Pointer:
		if a, ok := a.(*types.Pointer); ok {
			unify(p.Elem(), a.Elem(), tps, bind)
		}
	case *types.Slice:
		if a, ok := a.(*types.Slice); ok {
			unify(p.Elem(), a.Elem(), tps, bind)
		}
	case *types.Array:
		if a, ok := a.(*types.Array); ok {
			unify(p.Elem(), a.Elem(), tps, bind)
		}
	case *types.Map:
		if a, ok := a.(*types.Map); ok {
			unify(p.Key(), a.Key(), tps, bind)
			unify(p.Elem(), a.Elem(), tps, bind)
		}
	case *types.Chan:
		if a, ok := a.(*types.Chan); ok {
			unify(p.Elem(), a.Elem(), tps, bind)
		}
	case *types.Signature:
		if a, ok := a.(*types.Signature); ok {
			unify(p.Params(), a.Params(), tps, bind)
			unify(p.Results(), a.Results(), tps, bind)
		}
	case *types.Tuple:
		if a, ok := a.(*types.Tuple); ok && a.Len() == p.Len() {
			for i := 0; i < p.Len(); i++ {
				unify(p.At(i).Type(), a.At(i).Type(), tps, bind)
			}
		}
	case *types.Named:
		if a, ok := a.(*types.Named); ok && a.Origin() == p.Origin() && a.TypeArgs().Len() == p.TypeArgs().Len() {
			for i := 0; i < p.TypeArgs().Len(); i++ {
				unify(p.TypeArgs().At(i), a.TypeArgs().At(i), tps, bind)
			}
		}
	}
}
