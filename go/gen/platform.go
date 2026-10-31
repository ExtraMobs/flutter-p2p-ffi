package main

import (
	"go/types"
	"os"
	"sort"

	"golang.org/x/tools/go/packages"
)

const platformWhy = "declared otherwise or missing on some target"

// targets: the platforms the host is built for (tool/build.dart), as
// GOOS/GOARCH.
var targets = [][2]string{{"windows", "amd64"}, {"linux", "amd64"}, {"android", "arm64"}, {"android", "amd64"}}

// platformConsts: the exported constants of [paths] whose value is not the
// same on every target (os.DevNull is "NUL" on Windows, "/dev/null" on
// linux). A Dart literal would carry the value of the machine that ran the
// generator, so they become getters that ask the host (resolve); the value
// is "", or why it is left out (a constant some targets lack). Likewise
// [decls]: the other exported symbols (types, functions, variables, methods,
// by their root line) some target lacks or declares otherwise (syscall's
// SysProcAttr, DLLError): code using them would not compile everywhere. Only
// the packages with files a build constraint leaves out are compared, each
// type-checked under every target.
func platformConsts(paths []string) (out map[string]string, objs map[string]*types.Const, decls map[string]bool, err error) {
	list, err := packages.Load(&packages.Config{Mode: packages.NeedName | packages.NeedFiles}, paths...)
	if err != nil {
		return nil, nil, nil, err
	}
	var check []string
	for _, p := range list {
		if len(p.IgnoredFiles) > 0 {
			check = append(check, p.PkgPath)
		}
	}
	sort.Strings(check)
	out, objs, decls = map[string]string{}, map[string]*types.Const{}, map[string]bool{}
	if len(check) == 0 {
		return out, objs, decls, nil
	}
	vals := map[string]map[string]bool{} // constant → its values
	seen := map[string]int{}             // constant → on how many targets
	declOf := map[string]string{}        // another symbol → its declaration on the first target
	declOn := map[string]int{}           // and on how many targets it is the same
	decl := func(k, d string) {
		if v, ok := declOf[k]; !ok {
			declOf[k] = d
		} else if v != d {
			return
		}
		declOn[k]++
	}
	for _, t := range targets {
		cfg := &packages.Config{
			Mode: packages.NeedName | packages.NeedTypes,
			Env:  append(os.Environ(), "GOOS="+t[0], "GOARCH="+t[1], "CGO_ENABLED=0"),
		}
		ps, err := packages.Load(cfg, check...)
		if err != nil {
			return nil, nil, nil, err
		}
		for _, p := range ps {
			if p.Types == nil {
				continue
			}
			for _, n := range p.Types.Scope().Names() {
				k := p.PkgPath + "." + n
				o := p.Types.Scope().Lookup(n)
				if !o.Exported() {
					continue
				}
				if tn, ok := o.(*types.TypeName); ok {
					decl(k, types.TypeString(tn.Type().Underlying(), nil))
					ms := types.NewMethodSet(types.NewPointer(tn.Type()))
					for i := 0; i < ms.Len(); i++ {
						if f := ms.At(i).Obj(); f.Exported() {
							decl(k+"."+f.Name(), types.TypeString(f.Type(), nil))
						}
					}
					continue
				}
				c, ok := o.(*types.Const)
				if !ok {
					decl(k, types.TypeString(o.Type(), nil))
					continue
				}
				if vals[k] == nil {
					vals[k] = map[string]bool{}
				}
				vals[k][c.Val().ExactString()] = true
				seen[k]++
				if objs[k] == nil {
					objs[k] = c
				}
			}
		}
	}
	for k, vs := range vals {
		switch {
		case seen[k] < len(targets):
			out[k] = "constant that only some targets have"
		case len(vs) > 1:
			out[k] = ""
		}
	}
	for k := range objs {
		if _, ok := out[k]; !ok {
			delete(objs, k)
		}
	}
	for k := range declOf {
		if declOn[k] < len(targets) {
			decls[k] = true
		}
	}
	return out, objs, decls, nil
}
