package main

import (
	"fmt"
	"go/ast"
	"go/importer"
	"go/parser"
	"go/token"
	"go/types"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"golang.org/x/tools/go/packages"
)

// loadLoose carrega arquivos .go soltos (fora de um módulo Go) com go/parser
// + go/types. Cobre pacotes que só importam a stdlib — suficiente para os
// fixtures de golden tests. É o fallback quando packages.Load não encontra
// um módulo.
func loadLoose(fset *token.FileSet, target string) (*packages.Package, error) {
	files, err := looseGoFiles(target)
	if err != nil {
		return nil, err
	}

	syntax := make([]*ast.File, 0, len(files))
	for _, f := range files {
		af, err := parser.ParseFile(fset, f, nil, parser.ParseComments)
		if err != nil {
			return nil, fmt.Errorf("parseando %q: %w", f, err)
		}
		syntax = append(syntax, af)
	}

	info := &types.Info{
		Types:      map[ast.Expr]types.TypeAndValue{},
		Defs:       map[*ast.Ident]types.Object{},
		Uses:       map[*ast.Ident]types.Object{},
		Selections: map[*ast.SelectorExpr]*types.Selection{},
		Instances:  map[*ast.Ident]types.Instance{},
	}
	conf := types.Config{Importer: importer.Default()}
	pkgPath := syntax[0].Name.Name
	typesPkg, err := conf.Check(pkgPath, fset, syntax, info)
	if err != nil {
		return nil, fmt.Errorf("checando tipos de %q: %w", target, err)
	}

	imports := map[string]*packages.Package{}
	for _, imp := range typesPkg.Imports() {
		imports[imp.Path()] = &packages.Package{PkgPath: imp.Path(), Name: imp.Name(), Types: imp}
	}
	return &packages.Package{
		PkgPath:   typesPkg.Path(),
		Name:      typesPkg.Name(),
		Syntax:    syntax,
		GoFiles:   files,
		Types:     typesPkg,
		TypesInfo: info,
		Imports:   imports,
	}, nil
}

// looseGoFiles resolve o alvo do modo loose: um arquivo .go ou um diretório
// com arquivos .go (não recursivo, exclui _test.go), em ordem alfabética.
func looseGoFiles(target string) ([]string, error) {
	st, err := os.Stat(filepath.FromSlash(target))
	if err != nil {
		return nil, fmt.Errorf("alvo %q não existe: %w", target, err)
	}
	if !st.IsDir() {
		if strings.HasSuffix(target, ".go") {
			return []string{filepath.FromSlash(target)}, nil
		}
		return nil, fmt.Errorf("alvo %q não é diretório nem arquivo .go", target)
	}
	entries, err := os.ReadDir(filepath.FromSlash(target))
	if err != nil {
		return nil, err
	}
	var files []string
	for _, e := range entries {
		name := e.Name()
		if e.IsDir() || !strings.HasSuffix(name, ".go") || strings.HasSuffix(name, "_test.go") {
			continue
		}
		files = append(files, filepath.Join(filepath.FromSlash(target), name))
	}
	if len(files) == 0 {
		return nil, fmt.Errorf("nenhum arquivo .go em %q", target)
	}
	sort.Strings(files)
	return files, nil
}
