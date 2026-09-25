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
	d.TypeTable = w.tt.list
	d.Imports = dumpImports(p)
	d.StdlibUsage = dumpStdlibUsage(p)
	d.ReflectUsage = dumpReflectUsage(fset, p)
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

// dumpImplements: para cada tipo nomeado (não-interface) de nível de pacote,
// as interfaces nomeadas com métodos, alcançáveis (pacote, imports diretos e
// o universo `error`), que T ou *T satisfaz. Ordem determinística.
func dumpImplements(p *packages.Package, tt *typeTable) []jobject {
	var ifaces []*types.Named
	addScope := func(scope *types.Scope, exportedOnly bool) {
		for _, name := range scope.Names() {
			tn, ok := scope.Lookup(name).(*types.TypeName)
			if !ok || tn.IsAlias() || (exportedOnly && !tn.Exported()) {
				continue
			}
			named, ok := tn.Type().(*types.Named)
			if !ok || named.TypeParams().Len() > 0 {
				continue
			}
			if it, ok := named.Underlying().(*types.Interface); ok && it.IsMethodSet() && it.NumMethods() > 0 {
				ifaces = append(ifaces, named)
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

	var out []jobject
	scope := p.Types.Scope()
	for _, name := range scope.Names() {
		tn, ok := scope.Lookup(name).(*types.TypeName)
		if !ok || tn.IsAlias() {
			continue
		}
		named, ok := tn.Type().(*types.Named)
		if !ok || named.TypeParams().Len() > 0 {
			continue
		}
		if _, iface := named.Underlying().(*types.Interface); iface {
			continue
		}
		var impl []any
		for _, it := range ifaces {
			iface := it.Underlying().(*types.Interface)
			if types.Implements(named, iface) || types.Implements(types.NewPointer(named), iface) {
				impl = append(impl, tt.ref(it))
			}
		}
		if len(impl) > 0 {
			out = append(out, jobject{{"type", tt.ref(named)}, {"interfaces", impl}})
		}
	}
	return out
}
