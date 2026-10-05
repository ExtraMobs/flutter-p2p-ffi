package main

import (
	"go/ast"
	"go/token"
	"go/types"
)

// convIndex junta, num pacote, as conversões implícitas ou explícitas de um
// valor de tipo concreto para um tipo interface (atribuição, argumento,
// retorno, elemento de literal composto, envio em canal, chave de map,
// comparação, conversão `I(x)`, argumento de tipo com restrição de métodos)
// e os alvos dinâmicos (type assertion, case de type switch, conversão de
// uma interface para outra). O g2d junta os de todos os pacotes do grafo
// para declarar `implements` entre pacotes que não se importam
// (`conversions`/`asserts` no README).
type convIndex struct {
	info    *types.Info
	tt      *typeTable
	pairs   [][2]types.Type
	asserts []types.Type
}

// concrete: o tipo nomeado (ou *nomeado) não-interface que pode carregar
// métodos; nil para os outros (básicos, compostos sem nome, interfaces).
func concrete(t types.Type) types.Type {
	t = types.Unalias(t)
	base := t
	if p, ok := t.(*types.Pointer); ok {
		base = types.Unalias(p.Elem())
	}
	n, ok := base.(*types.Named)
	if !ok {
		return nil
	}
	if _, iface := n.Underlying().(*types.Interface); iface {
		return nil
	}
	return t
}

func isIface(t types.Type) bool {
	if t == nil {
		return false
	}
	_, ok := t.Underlying().(*types.Interface)
	return ok && !isTypeParam(t)
}

func isTypeParam(t types.Type) bool {
	_, ok := types.Unalias(t).(*types.TypeParam)
	return ok
}

// conv registra a conversão de src (tipo do valor) para dst.
func (c *convIndex) conv(src, dst types.Type) {
	if src == nil || dst == nil || !isIface(dst) {
		return
	}
	if isIface(src) {
		if !types.Identical(src, dst) && methodIface(dst.Underlying().(*types.Interface)) {
			c.assert(dst) // interface → interface: o tipo dinâmico precisa de dst
		}
		return
	}
	if t := concrete(src); t != nil {
		for _, p := range c.pairs {
			if types.Identical(p[0], t) && types.Identical(p[1], dst) {
				return
			}
		}
		c.pairs = append(c.pairs, [2]types.Type{t, dst})
	}
}

func (c *convIndex) assert(t types.Type) {
	if !isIface(t) || !methodIface(t.Underlying().(*types.Interface)) {
		return
	}
	for _, a := range c.asserts {
		if types.Identical(a, t) {
			return
		}
	}
	c.asserts = append(c.asserts, t)
}

func (c *convIndex) typeOf(e ast.Expr) types.Type {
	if tv, ok := c.info.Types[e]; ok {
		return tv.Type
	}
	return nil
}

// expr: e é usado onde se espera dst (nil = sem alvo).
func (c *convIndex) expr(e ast.Expr, dst types.Type) {
	if e == nil || dst == nil {
		return
	}
	if lit, ok := ast.Unparen(e).(*ast.CompositeLit); ok && lit.Type == nil {
		return // `{...}` elidido: o tipo é o do contexto, sem conversão
	}
	c.conv(c.typeOf(e), dst)
}

// results: os valores rs atribuídos aos alvos dsts (um a um ou tupla).
func (c *convIndex) results(rs []ast.Expr, dsts []types.Type) {
	if len(rs) == len(dsts) {
		for i, r := range rs {
			c.expr(r, dsts[i])
		}
		return
	}
	if len(rs) == 1 {
		if tup, ok := c.typeOf(rs[0]).(*types.Tuple); ok {
			for i := 0; i < tup.Len() && i < len(dsts); i++ {
				c.conv(tup.At(i).Type(), dsts[i])
			}
		} else if len(dsts) > 0 { // comma-ok: `v, ok = x.(T)`, `m[k]`, `<-ch`
			c.expr(rs[0], dsts[0])
		}
	}
}

// collect percorre os arquivos do pacote.
func (c *convIndex) collect(files []*ast.File) {
	var funcs []*types.Signature // função envolvente (retornos)
	var visit func(n ast.Node) bool
	visit = func(n ast.Node) bool {
		switch n := n.(type) {
		case *ast.FuncDecl:
			if n.Body == nil {
				return false
			}
			sig, _ := c.info.Defs[n.Name].Type().(*types.Signature)
			funcs = append(funcs, sig)
			ast.Inspect(n.Body, visit)
			funcs = funcs[:len(funcs)-1]
			return false
		case *ast.FuncLit:
			sig, _ := c.typeOf(n).(*types.Signature)
			funcs = append(funcs, sig)
			ast.Inspect(n.Body, visit)
			funcs = funcs[:len(funcs)-1]
			return false
		case *ast.ReturnStmt:
			if len(funcs) > 0 && funcs[len(funcs)-1] != nil {
				r := funcs[len(funcs)-1].Results()
				var dsts []types.Type
				for i := 0; i < r.Len(); i++ {
					dsts = append(dsts, r.At(i).Type())
				}
				c.results(n.Results, dsts)
			}
		case *ast.AssignStmt:
			if n.Tok == token.ASSIGN {
				var dsts []types.Type
				for _, l := range n.Lhs {
					dsts = append(dsts, c.typeOf(l))
				}
				c.results(n.Rhs, dsts)
			}
		case *ast.ValueSpec:
			if n.Type != nil {
				t := c.typeOf(n.Type)
				dsts := make([]types.Type, len(n.Names))
				for i := range dsts {
					dsts[i] = t
				}
				c.results(n.Values, dsts)
			}
		case *ast.CallExpr:
			c.call(n)
		case *ast.CompositeLit:
			c.composite(n)
		case *ast.SendStmt:
			if ch, ok := c.typeOf(n.Chan).Underlying().(*types.Chan); ok {
				c.expr(n.Value, ch.Elem())
			}
		case *ast.IndexExpr:
			if m, ok := c.typeOf(n.X).Underlying().(*types.Map); ok {
				c.expr(n.Index, m.Key())
			}
		case *ast.BinaryExpr:
			if n.Op == token.EQL || n.Op == token.NEQ {
				c.expr(n.X, c.typeOf(n.Y))
				c.expr(n.Y, c.typeOf(n.X))
			}
		case *ast.TypeAssertExpr:
			if n.Type != nil {
				c.assert(c.typeOf(n.Type))
			}
		case *ast.CaseClause:
			for _, e := range n.List {
				if tv, ok := c.info.Types[e]; ok && tv.IsType() {
					c.assert(tv.Type)
				}
			}
		}
		return true
	}
	for _, f := range files {
		ast.Inspect(f, visit)
	}
	c.instances()
}

// conversions: os pares tipo concreto → interface do pacote e os alvos
// dinâmicos (ver convIndex), na ordem em que aparecem.
func (d *packageDumper) conversions() ([]jobject, []any) {
	c := &convIndex{info: d.p.TypesInfo, tt: d.w.tt}
	c.collect(d.p.Syntax)
	pairs := []jobject{}
	for _, p := range c.pairs {
		pairs = append(pairs, jobject{{"type", d.w.tt.ref(p[0])}, {"iface", d.w.tt.ref(p[1])}})
	}
	asserts := []any{}
	for _, a := range c.asserts {
		asserts = append(asserts, d.w.tt.ref(a))
	}
	return pairs, asserts
}
