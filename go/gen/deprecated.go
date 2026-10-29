package main

import (
	"go/ast"
	"go/parser"
	gotoken "go/token"
	"go/types"
	"os"
	"strconv"
	"strings"

	"golang.org/x/tools/go/packages"
)

// deprecations reads the "Deprecated:" paragraph of the Go doc (Go's own
// convention) of every declaration in the packages of [fns] and of the
// model's types, by [depKey]. Dart gets it as @Deprecated: the symbol stays,
// and the analyzer warns whoever uses it.
func (m *model) deprecations(fns []*fn) error {
	seen := map[string]bool{}
	var paths []string
	add := func(p *types.Package) {
		if p != nil && !seen[p.Path()] {
			seen[p.Path()] = true
			paths = append(paths, p.Path())
		}
	}
	for _, f := range fns {
		add(f.obj.Pkg())
	}
	for _, t := range m.types {
		if t.named != nil {
			add(t.named.Obj().Pkg())
		}
	}
	list, err := packages.Load(&packages.Config{Mode: packages.NeedName | packages.NeedFiles,
		Env: append(os.Environ(), "CGO_ENABLED=0")}, paths...)
	if err != nil {
		return err
	}
	m.deprecated = map[string]string{}
	fset := gotoken.NewFileSet()
	for _, p := range list {
		note := func(name string, docs ...*ast.CommentGroup) {
			for _, d := range docs {
				if msg := deprecation(d); msg != "" {
					m.deprecated[p.PkgPath+"."+name] = msg
					return
				}
			}
		}
		for _, file := range p.GoFiles {
			f, err := parser.ParseFile(fset, file, nil, parser.ParseComments|parser.SkipObjectResolution)
			if err != nil {
				return err
			}
			for _, d := range f.Decls {
				switch d := d.(type) {
				case *ast.FuncDecl:
					name := d.Name.Name
					if d.Recv != nil {
						name = recvName(d.Recv.List[0].Type) + "." + name
					}
					note(name, d.Doc)
				case *ast.GenDecl:
					for _, s := range d.Specs {
						switch s := s.(type) {
						case *ast.TypeSpec:
							note(s.Name.Name, s.Doc, d.Doc)
							if it, ok := s.Type.(*ast.InterfaceType); ok {
								for _, fm := range it.Methods.List {
									for _, n := range fm.Names {
										note(s.Name.Name+"."+n.Name, fm.Doc)
									}
								}
							}
						case *ast.ValueSpec:
							for _, n := range s.Names {
								note(n.Name, s.Doc, d.Doc)
							}
						}
					}
				}
			}
		}
	}
	return nil
}

func recvName(e ast.Expr) string {
	switch t := e.(type) {
	case *ast.StarExpr:
		return recvName(t.X)
	case *ast.IndexExpr:
		return recvName(t.X)
	case *ast.IndexListExpr:
		return recvName(t.X)
	case *ast.Ident:
		return t.Name
	}
	return ""
}

// deprecation: the text of the doc's "Deprecated: " paragraph, or "".
func deprecation(d *ast.CommentGroup) string {
	if d == nil {
		return ""
	}
	for _, par := range strings.Split(d.Text(), "\n\n") {
		if rest, ok := strings.CutPrefix(par, "Deprecated: "); ok {
			return strings.Join(strings.Fields(rest), " ")
		}
	}
	return ""
}

// depKey: the key of [o] in model.deprecated (pkg.Name, pkg.Type.Method).
func depKey(o types.Object) string {
	if f, ok := o.(*types.Func); ok {
		if r := f.Type().(*types.Signature).Recv(); r != nil {
			t := r.Type()
			if p, ok := t.(*types.Pointer); ok {
				t = p.Elem()
			}
			if n, ok := t.(*types.Named); ok {
				return objKey(n.Obj()) + "." + o.Name()
			}
		}
	}
	return objKey(o)
}

// deprecate puts @Deprecated with [msg] between a declaration's doc comment
// and the declaration ([src] is emitted Dart); an empty [msg] keeps [src].
func deprecate(src, msg string) string {
	if msg == "" {
		return src
	}
	at := 0
	for at < len(src) {
		line := src[at:]
		if i := strings.IndexByte(line, '\n'); i >= 0 {
			line = line[:i+1]
		}
		if t := strings.TrimLeft(line, " "); !strings.HasPrefix(t, "///") {
			indent := line[:len(line)-len(t)]
			lit := strings.ReplaceAll(strconv.Quote(msg), "$", `\$`)
			return src[:at] + indent + "@Deprecated(" + lit + ")\n" + src[at:]
		}
		at += len(line)
	}
	return src
}
