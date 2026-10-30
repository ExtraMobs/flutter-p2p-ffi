package main

import (
	"go/types"
	"os"
	"sort"

	"golang.org/x/tools/go/packages"
)

// targets: the platforms the host is built for (tool/build.dart), as
// GOOS/GOARCH.
var targets = [][2]string{{"windows", "amd64"}, {"linux", "amd64"}, {"android", "arm64"}, {"android", "amd64"}}

// platformConsts: the exported constants of [paths] whose value is not the
// same on every target (os.DevNull is "NUL" on Windows, "/dev/null" on
// linux). A Dart literal would carry the value of the machine that ran the
// generator, so they become getters that ask the host (resolve); the value
// is "", or why it is left out (a constant some targets lack). Only the
// packages with files a build constraint leaves out are compared, each
// type-checked under every target.
func platformConsts(paths []string) (map[string]string, map[string]*types.Const, error) {
	list, err := packages.Load(&packages.Config{Mode: packages.NeedName | packages.NeedFiles}, paths...)
	if err != nil {
		return nil, nil, err
	}
	var check []string
	for _, p := range list {
		if len(p.IgnoredFiles) > 0 {
			check = append(check, p.PkgPath)
		}
	}
	sort.Strings(check)
	out := map[string]string{}
	objs := map[string]*types.Const{}
	if len(check) == 0 {
		return out, objs, nil
	}
	vals := map[string]map[string]bool{} // constant → its values
	seen := map[string]int{}             // constant → on how many targets
	for _, t := range targets {
		cfg := &packages.Config{
			Mode: packages.NeedName | packages.NeedTypes,
			Env:  append(os.Environ(), "GOOS="+t[0], "GOARCH="+t[1], "CGO_ENABLED=0"),
		}
		ps, err := packages.Load(cfg, check...)
		if err != nil {
			return nil, nil, err
		}
		for _, p := range ps {
			if p.Types == nil {
				continue
			}
			for _, n := range p.Types.Scope().Names() {
				c, ok := p.Types.Scope().Lookup(n).(*types.Const)
				if !ok || !c.Exported() {
					continue
				}
				k := p.PkgPath + "." + n
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
	return out, objs, nil
}
