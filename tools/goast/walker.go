package main

import (
	"fmt"
	"go/ast"
	"go/token"
	"go/types"
	"path/filepath"
	"reflect"
	"unicode"
	"unicode/utf8"
)

var (
	posType   = reflect.TypeOf(token.Pos(0))
	tokType   = reflect.TypeOf(token.Token(0))
	objType   = reflect.TypeOf((*ast.Object)(nil))
	scopeType = reflect.TypeOf((*ast.Scope)(nil))
)

// walker serializa genericamente qualquer ast.Node via reflection e anota
// os nós com a informação de tipos (chaves com prefixo "$", que não colidem
// com campos da AST).
type walker struct {
	fset *token.FileSet
	info *types.Info
	pkg  *types.Package
	tt   *typeTable
	fold map[*types.Package]map[string]bool // exportados com gêmeo por caixa
}

func (w *walker) walk(v reflect.Value) any {
	if !v.IsValid() {
		return nil
	}
	t := v.Type()

	switch v.Kind() {
	case reflect.Pointer, reflect.Interface:
		if v.IsNil() {
			return nil
		}
		// *ast.Object e *ast.Scope criam ciclos: não seguir.
		if t == objType {
			o := v.Interface().(*ast.Object)
			return jobject{
				{"node", "Object"},
				{"name", o.Name},
				{"kind", o.Kind.String()},
			}
		}
		if t == scopeType {
			return nil
		}
		out := w.walk(v.Elem())
		if n, ok := v.Interface().(ast.Node); ok && v.Kind() == reflect.Pointer {
			if obj, ok := out.(jobject); ok {
				out = w.annotate(n, obj)
			}
		}
		return out
	}

	if t == posType {
		p := w.fset.Position(v.Interface().(token.Pos))
		if !p.IsValid() {
			return nil
		}
		return jobject{
			{"file", filepath.Base(p.Filename)},
			{"line", p.Line},
			{"column", p.Column},
			{"offset", p.Offset},
		}
	}
	if t == tokType {
		return v.Interface().(token.Token).String()
	}

	switch v.Kind() {
	case reflect.Struct:
		// Todo struct alcançável na árvore é um nó AST.
		fields := jobject{{"node", t.Name()}}
		for i := 0; i < t.NumField(); i++ {
			f := t.Field(i)
			if !f.IsExported() {
				continue
			}
			fields = append(fields, jpair{lowerFirst(f.Name), w.walk(v.Field(i))})
		}
		return fields
	case reflect.Slice, reflect.Array:
		if v.Kind() == reflect.Slice && v.IsNil() {
			return nil
		}
		list := make([]any, v.Len())
		for i := 0; i < v.Len(); i++ {
			list[i] = w.walk(v.Index(i))
		}
		return list
	case reflect.Map:
		if v.IsNil() {
			return nil
		}
		m := map[string]any{}
		for _, k := range v.MapKeys() {
			m[fmt.Sprint(k.Interface())] = w.walk(v.MapIndex(k))
		}
		return m
	default:
		return v.Interface()
	}
}

func lowerFirst(s string) string {
	r, size := utf8.DecodeRuneInString(s)
	return string(unicode.ToLower(r)) + s[size:]
}
