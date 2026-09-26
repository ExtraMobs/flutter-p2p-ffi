package main

import (
	"bytes"
	"fmt"
	"go/ast"
	"go/printer"
	"go/token"
	"go/types"
	"path/filepath"
	"reflect"
	"sort"
	"strconv"
	"strings"

	"golang.org/x/tools/go/packages"
)

// dumpPackage produz o dump completo de um pacote: AST anotada por arquivo,
// tabela de tipos e inventários (imports, stdlib, reflect).
func dumpPackage(fset *token.FileSet, p *packages.Package) *PackageDump {
	w := &walker{fset: fset, info: p.TypesInfo, pkg: p.Types, tt: &typeTable{}}
	d := &PackageDump{Path: p.PkgPath, Name: p.Name}

	for i, f := range p.Syntax {
		path := f.Name.Name
		if i < len(p.GoFiles) {
			path = filepath.Base(p.GoFiles[i])
		}
		d.Files = append(d.Files, &FileDump{Path: path, AST: w.walk(reflect.ValueOf(f))})
	}

	d.Implements = dumpImplements(p, w.tt)
	d.InitOrder = dumpInitOrder(fset, p)
	d.TypeTable = w.tt.list
	d.Imports = dumpImports(p)
	d.StdlibUsage = dumpStdlibUsage(p)
	d.ReflectUsage = dumpReflectUsage(fset, p)
	for _, f := range p.OtherFiles {
		d.OtherFiles = append(d.OtherFiles, filepath.Base(f))
	}
	sort.Strings(d.OtherFiles)
	if m := p.Module; m != nil {
		d.Module = &ModuleDump{Path: m.Path, Version: m.Version}
	}
	return d
}

func dumpImports(p *packages.Package) []ImportDump {
	var out []ImportDump
	for _, f := range p.Syntax {
		for _, spec := range f.Imports {
			path, err := strconv.Unquote(spec.Path.Value)
			if err != nil {
				path = spec.Path.Value
			}
			name := ""
			if spec.Name != nil {
				name = spec.Name.Name
			} else if imp, ok := p.Imports[path]; ok && imp.Types != nil {
				name = imp.Types.Name()
			}
			out = append(out, ImportDump{Path: path, Name: name})
		}
	}
	return out
}

func qualifier(p *types.Package) string { return p.Path() }

// dumpStdlibUsage lista "<importpath>.<Símbolo>" de todo símbolo da stdlib
// usado. Stdlib = primeiro segmento do import path sem ponto.
func dumpStdlibUsage(p *packages.Package) []string {
	set := map[string]bool{}
	for _, obj := range p.TypesInfo.Uses {
		pkg := obj.Pkg()
		// Objetos do próprio pacote (inclusive PkgName de imports e locais)
		// nunca são stdlib, mesmo com path sem ponto (command-line-arguments).
		if pkg == nil || pkg == p.Types {
			continue
		}
		path := pkg.Path()
		first, _, _ := strings.Cut(path, "/")
		if strings.Contains(first, ".") {
			continue
		}
		set[path+"."+obj.Name()] = true
	}
	out := make([]string, 0, len(set))
	for s := range set {
		out = append(out, s)
	}
	sort.Strings(out)
	return out
}

// dumpReflectUsage registra toda seleção x.Sel que toca o pacote reflect.
func dumpReflectUsage(fset *token.FileSet, p *packages.Package) []ReflectUse {
	var out []ReflectUse
	for _, f := range p.Syntax {
		ast.Inspect(f, func(n ast.Node) bool {
			sel, ok := n.(*ast.SelectorExpr)
			if !ok {
				return true
			}
			obj := p.TypesInfo.Uses[sel.Sel]
			if obj == nil || obj.Pkg() == nil || obj.Pkg().Path() != "reflect" {
				return true
			}
			pos := fset.Position(sel.Pos())
			out = append(out, ReflectUse{
				Pos:  fmt.Sprintf("%s:%d:%d", filepath.Base(pos.Filename), pos.Line, pos.Column),
				Expr: printNode(fset, sel),
			})
			return true
		})
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Pos != out[j].Pos {
			return out[i].Pos < out[j].Pos
		}
		return out[i].Expr < out[j].Expr
	})
	return out
}

func printNode(fset *token.FileSet, n ast.Node) string {
	var b bytes.Buffer
	if err := printer.Fprint(&b, fset, n); err != nil {
		return ""
	}
	return b.String()
}

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

// dumpInitOrder: ordem de inicialização das variáveis de pacote
// (types.Info.InitOrder, já em ordem de dependência). Cada entrada lista o
// decl ("arquivo:offset") das variáveis do lado esquerdo do inicializador.
func dumpInitOrder(fset *token.FileSet, p *packages.Package) [][]string {
	out := [][]string{}
	for _, init := range p.TypesInfo.InitOrder {
		var lhs []string
		for _, v := range init.Lhs {
			pos := fset.Position(v.Pos())
			lhs = append(lhs, fmt.Sprintf("%s:%d", filepath.Base(pos.Filename), pos.Offset))
		}
		out = append(out, lhs)
	}
	return out
}
