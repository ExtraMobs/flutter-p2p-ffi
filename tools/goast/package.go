package main

import (
	"fmt"
	"go/token"
	"path/filepath"
	"reflect"
	"sort"
	"strconv"

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
