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

// dumpImplements: para cada tipo nomeado (não-interface) de nível de pacote,
// as interfaces com métodos que T ou *T satisfaz: as nomeadas alcançáveis
// (pacote, imports diretos e o universo `error`), as instâncias de interfaces
// genéricas alcançáveis cujos argumentos saem dos métodos de T (`Key[k8]`
// para `Xor(k8) k8`) e as anônimas usadas no pacote (`interface{ M() }`, já
// na tabela de tipos). Tipo genérico conta instanciado com os próprios
// parâmetros (`KeyList[K]`). Ordem determinística.
func dumpImplements(p *packages.Package, tt *typeTable) []jobject {
	var ifaces, generic []*types.Named
	addScope := func(scope *types.Scope, exportedOnly bool) {
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
					generic = append(generic, named)
				} else {
					ifaces = append(ifaces, named)
				}
			}
		}
	}
	addScope(types.Universe, false)
	addScope(p.Types.Scope(), false)
	imps := p.Types.Imports()
	sort.Slice(imps, func(i, j int) bool { return imps[i].Path() < imps[j].Path() })
	for _, imp := range imps {
		addScope(imp.Scope(), true)
	}
	// Interfaces anônimas: literais `interface{...}` com métodos fora de uma
	// declaração de tipo (o subjacente de `type I interface{...}` não conta).
	var anon []*types.Interface
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
				for _, seen := range anon {
					if types.Identical(seen, it) {
						return true
					}
				}
				anon = append(anon, it)
			}
			return true
		})
	}

	var out []jobject
	scope := p.Types.Scope()
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
		satisfies := func(iface *types.Interface) bool {
			return types.Implements(t, iface) || types.Implements(types.NewPointer(t), iface)
		}
		var impl []any
		for _, it := range ifaces {
			if satisfies(it.Underlying().(*types.Interface)) {
				impl = append(impl, tt.ref(it))
			}
		}
		for _, g := range generic {
			if inst := instanceFor(g, t); inst != nil && satisfies(inst.Underlying().(*types.Interface)) {
				impl = append(impl, tt.ref(inst))
			}
		}
		for _, iface := range anon {
			if satisfies(iface) {
				impl = append(impl, tt.ref(iface))
			}
		}
		if len(impl) > 0 {
			out = append(out, jobject{{"type", tt.ref(named)}, {"interfaces", impl}})
		}
	}
	return out
}
