package main

import (
	"go/ast"
	"go/types"
	"sort"
)

// Os lugares de conversão que pedem mais que "valor → tipo do alvo":
// chamadas (parâmetros, variádicos, `T(x)`, `append`), literais compostos e
// argumentos de tipo de genéricos (convIndex, conversions.go).

func (c *convIndex) call(n *ast.CallExpr) {
	tv, ok := c.info.Types[n.Fun]
	if !ok {
		return
	}
	if tv.IsType() { // conversão `T(x)`
		if len(n.Args) == 1 {
			c.expr(n.Args[0], tv.Type)
		}
		return
	}
	if tv.IsBuiltin() {
		if id, ok := ast.Unparen(n.Fun).(*ast.Ident); ok && id.Name == "append" && len(n.Args) > 1 && !n.Ellipsis.IsValid() {
			if s, ok := c.typeOf(n.Args[0]).Underlying().(*types.Slice); ok {
				for _, a := range n.Args[1:] {
					c.expr(a, s.Elem())
				}
			}
		}
		return
	}
	sig, ok := tv.Type.Underlying().(*types.Signature)
	if !ok {
		return
	}
	params := sig.Params()
	var dsts []types.Type
	for i := 0; i < params.Len(); i++ {
		dsts = append(dsts, params.At(i).Type())
	}
	if sig.Variadic() && !n.Ellipsis.IsValid() && params.Len() > 0 {
		elem := params.At(params.Len() - 1).Type().Underlying().(*types.Slice).Elem()
		dsts = dsts[:len(dsts)-1]
		for len(dsts) < len(n.Args) {
			dsts = append(dsts, elem)
		}
		if len(n.Args) == 1 { // f(g()) com g multivalorado
			if tup, ok := c.typeOf(n.Args[0]).(*types.Tuple); ok {
				for len(dsts) < tup.Len() {
					dsts = append(dsts, elem)
				}
			}
		}
	}
	c.results(n.Args, dsts)
}

func (c *convIndex) composite(n *ast.CompositeLit) {
	t := c.typeOf(n)
	if t == nil {
		return
	}
	if p, ok := t.Underlying().(*types.Pointer); ok { // `&{...}` elidido
		t = p.Elem()
	}
	switch u := t.Underlying().(type) {
	case *types.Struct:
		for i, e := range n.Elts {
			if kv, ok := e.(*ast.KeyValueExpr); ok {
				if id, ok := kv.Key.(*ast.Ident); ok {
					if f, ok := c.info.Uses[id].(*types.Var); ok {
						c.expr(kv.Value, f.Type())
					}
				}
			} else if i < u.NumFields() {
				c.expr(e, u.Field(i).Type())
			}
		}
	case *types.Slice:
		c.elems(n.Elts, nil, u.Elem())
	case *types.Array:
		c.elems(n.Elts, nil, u.Elem())
	case *types.Map:
		c.elems(n.Elts, u.Key(), u.Elem())
	}
}

func (c *convIndex) elems(elts []ast.Expr, key, elem types.Type) {
	for _, e := range elts {
		if kv, ok := e.(*ast.KeyValueExpr); ok {
			c.expr(kv.Key, key)
			c.expr(kv.Value, elem)
		} else {
			c.expr(e, elem)
		}
	}
}

// instances: argumento de tipo concreto de uma restrição com métodos
// (`F[T]` com `[X Namer]`): no Dart, T precisa ser um Namer.
func (c *convIndex) instances() {
	ids := make([]*ast.Ident, 0, len(c.info.Instances))
	for id := range c.info.Instances {
		ids = append(ids, id)
	}
	sort.Slice(ids, func(i, j int) bool { return ids[i].Pos() < ids[j].Pos() })
	for _, id := range ids {
		inst := c.info.Instances[id]
		var tps *types.TypeParamList
		switch o := c.info.Uses[id].(type) {
		case *types.Func:
			tps = o.Type().(*types.Signature).TypeParams()
		case *types.TypeName:
			if n, ok := o.Type().(*types.Named); ok {
				tps = n.TypeParams()
			}
		}
		if tps == nil {
			continue
		}
		for i := 0; i < tps.Len() && i < inst.TypeArgs.Len(); i++ {
			cons := tps.At(i).Constraint()
			if it, ok := cons.Underlying().(*types.Interface); ok && methodIface(it) && !mentionsTypeParam(cons) {
				c.conv(inst.TypeArgs.At(i), cons)
			}
		}
	}
}

// mentionsTypeParam: a restrição depende de parâmetros de tipo
// (`interface{ M() T }`): fica de fora (precisaria instanciar).
func mentionsTypeParam(t types.Type) bool {
	found := false
	var visit func(t types.Type)
	seen := map[types.Type]bool{}
	visit = func(t types.Type) {
		if found || t == nil || seen[t] {
			return
		}
		seen[t] = true
		switch t := types.Unalias(t).(type) {
		case *types.TypeParam:
			found = true
		case *types.Named:
			if args := t.TypeArgs(); args != nil {
				for i := 0; i < args.Len(); i++ {
					visit(args.At(i))
				}
			}
		case *types.Interface:
			for i := 0; i < t.NumMethods(); i++ {
				visit(t.Method(i).Type())
			}
		case *types.Signature:
			for i := 0; i < t.Params().Len(); i++ {
				visit(t.Params().At(i).Type())
			}
			for i := 0; i < t.Results().Len(); i++ {
				visit(t.Results().At(i).Type())
			}
		case *types.Pointer:
			visit(t.Elem())
		case *types.Slice:
			visit(t.Elem())
		case *types.Array:
			visit(t.Elem())
		case *types.Map:
			visit(t.Key())
			visit(t.Elem())
		case *types.Chan:
			visit(t.Elem())
		}
	}
	visit(t)
	return found
}
