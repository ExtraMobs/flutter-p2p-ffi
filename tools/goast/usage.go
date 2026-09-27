package main

import (
	"bytes"
	"fmt"
	"go/ast"
	"go/printer"
	"go/token"
	"path/filepath"
	"sort"
	"strings"
)

// stdlibUsage lista "<importpath>.<Símbolo>" de todo símbolo da stdlib
// usado. Stdlib = primeiro segmento do import path sem ponto.
func (d *packageDumper) stdlibUsage() []string {
	set := map[string]bool{}
	for _, obj := range d.p.TypesInfo.Uses {
		pkg := obj.Pkg()
		// Objetos do próprio pacote (inclusive PkgName de imports e locais)
		// nunca são stdlib, mesmo com path sem ponto (command-line-arguments).
		if pkg == nil || pkg == d.p.Types {
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

// reflectUsage registra toda seleção x.Sel que toca o pacote reflect.
func (d *packageDumper) reflectUsage() []ReflectUse {
	var out []ReflectUse
	for _, f := range d.p.Syntax {
		ast.Inspect(f, func(n ast.Node) bool {
			sel, ok := n.(*ast.SelectorExpr)
			if !ok {
				return true
			}
			obj := d.p.TypesInfo.Uses[sel.Sel]
			if obj == nil || obj.Pkg() == nil || obj.Pkg().Path() != "reflect" {
				return true
			}
			pos := d.fset.Position(sel.Pos())
			out = append(out, ReflectUse{
				Pos:  fmt.Sprintf("%s:%d:%d", filepath.Base(pos.Filename), pos.Line, pos.Column),
				Expr: printNode(d.fset, sel),
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
