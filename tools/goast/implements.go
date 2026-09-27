package main

import (
	"go/ast"
	"go/types"
	"sort"

	"golang.org/x/tools/go/packages"
)

// methodIface: interface com métodos cuja única restrição além deles é
// `comparable` (`interface{ comparable; M() }` serve de bound com métodos).
// Uniões de tipos ficam de fora: não viram `implements` no Dart.
func methodIface(it *types.Interface) bool {
	return it.NumMethods() > 0 && methodsOrComparable(it)
}

func methodsOrComparable(it *types.Interface) bool {
	for i := 0; i < it.NumEmbeddeds(); i++ {
		e := it.EmbeddedType(i)
		if e == types.Universe.Lookup("comparable").Type() {
			continue
		}
		ei, ok := e.Underlying().(*types.Interface)
		if !ok || !methodsOrComparable(ei) {
			return false
		}
	}
	return true
}

// ifaceIndex: as interfaces com métodos que um tipo do pacote pode
// satisfazer. As nomeadas alcançáveis (universo `error`, pacote e as
// exportadas dos imports diretos), as genéricas (instanciadas por tipo, ver
// instanceFor) e as anônimas usadas no pacote (`interface{ M() }`, já na
// tabela de tipos).
type ifaceIndex struct {
	named, generic []*types.Named
	anon           []*types.Interface
}

func newIfaceIndex(p *packages.Package) *ifaceIndex {
	ix := &ifaceIndex{}
	ix.addScope(types.Universe, false)
	ix.addScope(p.Types.Scope(), false)
	imps := p.Types.Imports()
	sort.Slice(imps, func(i, j int) bool { return imps[i].Path() < imps[j].Path() })
	for _, imp := range imps {
		ix.addScope(imp.Scope(), true)
	}
	ix.addAnon(p)
	return ix
}

// addScope registra as interfaces nomeadas com métodos de um escopo.
func (ix *ifaceIndex) addScope(scope *types.Scope, exportedOnly bool) {
	for _, name := range scope.Names() {
		tn, ok := scope.Lookup(name).(*types.TypeName)
		if !ok || tn.IsAlias() || (exportedOnly && !tn.Exported()) {
			continue
		}
		named, ok := tn.Type().(*types.Named)
		if !ok {
			continue
		}
		if it, ok := named.Underlying().(*types.Interface); ok && methodIface(it) {
			if named.TypeParams().Len() > 0 {
				ix.generic = append(ix.generic, named)
			} else {
				ix.named = append(ix.named, named)
			}
		}
	}
}

// addAnon registra as interfaces anônimas: literais `interface{...}` com
// métodos fora de uma declaração de tipo (o subjacente de `type I
// interface{...}` não conta), sem repetir tipos idênticos.
func (ix *ifaceIndex) addAnon(p *packages.Package) {
	declared := map[ast.Expr]bool{}
	for _, f := range p.Syntax {
		ast.Inspect(f, func(n ast.Node) bool {
			switch n := n.(type) {
			case *ast.TypeSpec:
				if !n.Assign.IsValid() {
					declared[n.Type] = true
				}
			case *ast.InterfaceType:
				it, ok := p.TypesInfo.TypeOf(n).(*types.Interface)
				if declared[n] || !ok || !methodIface(it) {
					break
				}
				for _, seen := range ix.anon {
					if types.Identical(seen, it) {
						return true
					}
				}
				ix.anon = append(ix.anon, it)
			}
			return true
		})
	}
}

// implementedBy: as interfaces que t ou *t satisfaz, como índices da tabela
// de tipos, na ordem nomeadas, instâncias genéricas e anônimas.
func (ix *ifaceIndex) implementedBy(t types.Type, tt *typeTable) []any {
	satisfies := func(iface *types.Interface) bool {
		return types.Implements(t, iface) || types.Implements(types.NewPointer(t), iface)
	}
	var impl []any
	for _, it := range ix.named {
		if satisfies(it.Underlying().(*types.Interface)) {
			impl = append(impl, tt.ref(it))
		}
	}
	for _, g := range ix.generic {
		if inst := instanceFor(g, t); inst != nil && satisfies(inst.Underlying().(*types.Interface)) {
			impl = append(impl, tt.ref(inst))
		}
	}
	for _, iface := range ix.anon {
		if satisfies(iface) {
			impl = append(impl, tt.ref(iface))
		}
	}
	return impl
}

// implements: para cada tipo nomeado (não-interface) de nível de pacote, as
// interfaces do ifaceIndex que T ou *T satisfaz. Tipo genérico conta
// instanciado com os próprios parâmetros (`KeyList[K]`). Ordem
// determinística.
func (d *packageDumper) implements() []jobject {
	ix := newIfaceIndex(d.p)
	var out []jobject
	scope := d.p.Types.Scope()
	for _, name := range scope.Names() {
		tn, ok := scope.Lookup(name).(*types.TypeName)
		if !ok || tn.IsAlias() {
			continue
		}
		named, ok := tn.Type().(*types.Named)
		if !ok {
			continue
		}
		if _, iface := named.Underlying().(*types.Interface); iface {
			continue
		}
		var t types.Type = named
		if tps := named.TypeParams(); tps.Len() > 0 {
			args := make([]types.Type, tps.Len())
			for i := range args {
				args[i] = tps.At(i)
			}
			inst, err := types.Instantiate(nil, named, args, false)
			if err != nil {
				continue
			}
			t = inst
		}
		if impl := ix.implementedBy(t, d.w.tt); len(impl) > 0 {
			out = append(out, jobject{{"type", d.w.tt.ref(named)}, {"interfaces", impl}})
		}
	}
	return out
}
