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

// packageDumper produz o dump de um pacote: a AST anotada de cada arquivo
// (walker), a tabela de tipos e os inventários. Os métodos se dividem entre
// package.go (arquivos, imports, ordem de init), usage.go (stdlib e reflect),
// implements.go e conversions*.go.
type packageDumper struct {
	fset *token.FileSet
	p    *packages.Package
	w    *walker
}

// dumpPackage produz o dump completo de um pacote: AST anotada por arquivo,
// tabela de tipos e inventários (imports, stdlib, reflect).
func dumpPackage(fset *token.FileSet, p *packages.Package) *PackageDump {
	w := &walker{fset: fset, info: p.TypesInfo, pkg: p.Types, tt: &typeTable{}}
	return (&packageDumper{fset: fset, p: p, w: w}).dump()
}

// dump monta o PackageDump. A ordem importa: os arquivos e o implements
// registram tipos na tabela, e os índices seguem a ordem de registro.
func (d *packageDumper) dump() *PackageDump {
	out := &PackageDump{Path: d.p.PkgPath, Name: d.p.Name}
	out.Files = d.files()
	out.Implements = d.implements()
	out.Conversions, out.Asserts = d.conversions()
	out.InitOrder = d.initOrder()
	out.TypeTable = d.w.tt.list
	out.Imports = d.imports()
	out.StdlibUsage = d.stdlibUsage()
	out.ReflectUsage = d.reflectUsage()
	out.OtherFiles = d.otherFiles()
	if m := d.p.Module; m != nil {
		out.Module = &ModuleDump{Path: m.Path, Version: m.Version}
	}
	return out
}

// files: a AST anotada de cada arquivo, com o nome base dele.
func (d *packageDumper) files() []*FileDump {
	var out []*FileDump
	for i, f := range d.p.Syntax {
		path := f.Name.Name
		if i < len(d.p.GoFiles) {
			path = filepath.Base(d.p.GoFiles[i])
		}
		out = append(out, &FileDump{Path: path, AST: d.w.walk(reflect.ValueOf(f))})
	}
	return out
}

// otherFiles: os arquivos não-Go (.s = assembly) do contexto de build, em
// ordem alfabética.
func (d *packageDumper) otherFiles() []string {
	var out []string
	for _, f := range d.p.OtherFiles {
		out = append(out, filepath.Base(f))
	}
	sort.Strings(out)
	return out
}

func (d *packageDumper) imports() []ImportDump {
	var out []ImportDump
	for _, f := range d.p.Syntax {
		for _, spec := range f.Imports {
			path, err := strconv.Unquote(spec.Path.Value)
			if err != nil {
				path = spec.Path.Value
			}
			name := ""
			if spec.Name != nil {
				name = spec.Name.Name
			} else if imp, ok := d.p.Imports[path]; ok && imp.Types != nil {
				name = imp.Types.Name()
			}
			out = append(out, ImportDump{Path: path, Name: name})
		}
	}
	return out
}

// initOrder: ordem de inicialização das variáveis de pacote
// (types.Info.InitOrder, já em ordem de dependência). Cada entrada lista o
// decl ("arquivo:offset") das variáveis do lado esquerdo do inicializador.
func (d *packageDumper) initOrder() [][]string {
	out := [][]string{}
	for _, init := range d.p.TypesInfo.InitOrder {
		var lhs []string
		for _, v := range init.Lhs {
			pos := d.fset.Position(v.Pos())
			lhs = append(lhs, fmt.Sprintf("%s:%d", filepath.Base(pos.Filename), pos.Offset))
		}
		out = append(out, lhs)
	}
	return out
}
