package main

import (
	"bytes"
	"cmp"
	"fmt"
	"go/types"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"slices"
	"sort"
	"strings"
	"sync"
)

// Dart paths (owner's decisions, 2026-10-29): every Go package is one library
// under lib/go/, at the package's path after the host of its URL, so the author
// is part of it and two modules with the same name do not meet; the module's
// own segment drops the `go-` prefix and its major version goes after it
// (github.com/ipfs/go-cid → go/ipfs/cid.dart, github.com/ipld/go-car/v2/index →
// go/ipld/car/v2/index.dart, golang.org/x/crypto/sha3 → go/x/crypto/sha3.dart,
// lukechampine.com/blake3 → go/blake3.dart); the Go standard library sits
// beside the authors (context → go/context.dart). Each Go type lives only in
// the library of its package, and no public library re-exports another
// (checkPublicExports).

var (
	modulesOnce sync.Once
	modules     []string // the go.mod modules, longest path first
)

// goModules: the modules of the build (`go list -m all`), so a package path
// maps to its module without a hand-kept table.
func goModules() []string {
	modulesOnce.Do(func() {
		out, err := exec.Command("go", "list", "-m", "-f", "{{.Path}}", "all").Output()
		if err != nil {
			panic(fmt.Sprintf("gen: go list -m all: %v", err))
		}
		modules = strings.Fields(string(out))
		sort.Slice(modules, func(i, j int) bool { return len(modules[i]) > len(modules[j]) })
	})
	return modules
}

var majorRE = regexp.MustCompile(`/v[0-9]+$`)

// dartPath: the library of a Go package, relative to lib/.
func dartPath(pkgPath string) string {
	var p string
	if first, _, _ := strings.Cut(pkgPath, "/"); !strings.Contains(first, ".") {
		p = "go/" + pkgPath // the standard library
	} else {
		mod := ""
		for _, m := range goModules() {
			if pkgPath == m || strings.HasPrefix(pkgPath, m+"/") {
				mod = m
				break
			}
		}
		if mod == "" {
			panic("gen: package outside the modules of go.mod: " + pkgPath)
		}
		dir, _ := moduleDir(mod)
		p = "go/" + dir + strings.TrimPrefix(pkgPath, majorRE.ReplaceAllString(mod, ""))
	}
	return pathChars.Replace(p) + ".dart"
}

// pathChars: what a Dart file name cannot have.
var pathChars = strings.NewReplacer("-", "_", ".", "_")

// moduleDir: the folder of a module under lib/go/ (ipfs/cid) and the author's
// part of it (ipfs/; empty for a host of its own, lukechampine.com/blake3). A
// module nested in another (github.com/ipld/go-ipld-prime/storage/bsadapter)
// keeps the outer one's path (ipld/ipld_prime/storage/bsadapter).
func moduleDir(mod string) (dir, author string) {
	base := majorRE.ReplaceAllString(mod, "")
	for _, outer := range goModules() { // longest first: the closest outer module
		if outer != mod && strings.HasPrefix(base, majorRE.ReplaceAllString(outer, "")+"/") {
			dir, author := moduleDir(outer)
			return dir + strings.TrimPrefix(base, majorRE.ReplaceAllString(outer, "")), author
		}
	}
	host, rest, _ := strings.Cut(base, "/")
	if rest == "" { // a module that is only a host (go.opencensus.io): its name, as an author
		name := strings.TrimPrefix(strings.TrimPrefix(host, "www."), "go.")
		name = name[:max(strings.LastIndex(name, "."), 0)]
		return name, name + "/"
	}
	i := strings.LastIndex(rest, "/")
	return rest[:i+1] + strings.TrimPrefix(rest[i+1:], "go-"), rest[:i+1]
}

var (
	authorsOnce sync.Once
	authors     map[string]string // a module's folder, as under lib/go/ → its author's part
)

// classPath: the library path a type's class is named after, without the
// author (go/ipfs/boxo/mfs.dart → go/boxo/mfs.dart), so the classes keep the
// short names (BoxoMfsRoot, Cid); the generator refuses two equal ones.
func classPath(path string) string {
	authorsOnce.Do(func() {
		authors = map[string]string{}
		for _, m := range goModules() {
			if dir, author := moduleDir(m); author != "" {
				authors[pathChars.Replace(dir)] = pathChars.Replace(author)
			}
		}
	})
	p := strings.TrimPrefix(path, "go/")
	for dir, author := range authors { // the folders of one author share it
		if rest, ok := strings.CutPrefix(p, dir); ok && (rest == "" || rest[0] == '/' || rest == ".dart") {
			return "go/" + strings.TrimPrefix(p, author)
		}
	}
	return path
}

// Namespaces (owner's decisions, option a, and 2026-10-29): one import,
// `package:p2p_ffi/p2p_ffi.dart`. The package-level members of a Go package
// (functions, constants, variables, option constructors) are reached through a
// tree of const objects: the top-level constant `go`, then one getter per
// segment of the library path, the author first (`go.ipfs.boxo.mfs.newRoot(...)`),
// lowerCamelCase as Dart names constants and getters, generated in
// lib/src/go.dart; each library adds its members as an extension on its class
// (`extension GoIpfsBoxoMfsApi on GoIpfsBoxoMfs`). Dart has no nested types, so
// a type keeps a top-level name, unique in the whole package: the library's
// path without the author in front (`BoxoMfsRoot`), minus the words the Go name
// already starts with (`cid.Cid` → `Cid`).

// libWords: the words of a library path (go/boxo/mfs.dart → boxo mfs,
// go/libp2p_kad_dht.dart → libp2p kad dht).
func libWords(path string) []string {
	p := strings.TrimSuffix(strings.TrimPrefix(path, "go/"), ".dart")
	return strings.FieldsFunc(p, func(r rune) bool { return r == '/' || r == '_' })
}

// libPrefix: the start of the library's class names (BoxoMfs).
func libPrefix(path string) string {
	var b strings.Builder
	for _, w := range libWords(path) {
		b.WriteString(capitalize(w))
	}
	return b.String()
}

// qualType: the Dart class of the Go type [goName] of library [path]
// (ipfs/boxo/mfs Root → BoxoMfsRoot, ipfs/cid Cid → Cid, ipfs/boxo/path Path →
// BoxoPath).
func qualType(path, goName string) string {
	if c, ok := classMarks[path+" "+goName]; ok {
		return c
	}
	pre, ws := typeParts(path, goName)
	return escapeType(strings.Join(pre, "") + strings.Join(ws, ""))
}

// Class collisions (owner's decision, 2026-10-29): when two types get the same
// class, the one with the longer Go name is marked with a `_` and keeps its Go
// name whole: after its path (grpc.BackoffConfig → Grpc_BackoffConfig, beside
// grpc/backoff.Config → GrpcBackoffConfig; gob.GobDecoder →
// EncodingGob_GobDecoder), or at its own `_` when it has one
// (errorspb.EncodedError_Leaf → ErrorsErrorspbEncodedError_Leaf). The
// declaration carries `// ignore: camel_case_types`.
var classMarks = map[string]string{} // library path + " " + Go name → its class

// markClasses fills classMarks from every class, as (library path, Go name).
func markClasses(classes [][2]string) {
	clear(classMarks)
	byName := map[string][][2]string{}
	seen := map[[2]string]bool{}
	for _, c := range classes {
		if !seen[c] {
			seen[c] = true
			byName[qualType(c[0], c[1])] = append(byName[qualType(c[0], c[1])], c)
		}
	}
	for _, group := range byName {
		slices.SortFunc(group, func(a, b [2]string) int { return cmp.Compare(len(a[1]), len(b[1])) })
		for _, c := range group[1:] {
			if len(c[1]) > len(group[0][1]) { // a tie is left to goTree, which refuses it
				classMarks[c[0]+" "+c[1]] = markedType(c[0], c[1])
			}
		}
	}
}

// markedType: the class of a type whose plain name another one has.
func markedType(path, goName string) string {
	if !strings.Contains(strings.Trim(goName, "_"), "_") {
		return libPrefix(classPath(path)) + "_" + camelType(goName)
	}
	pre, _ := typeParts(path, goName)
	var segs []string
	for _, s := range strings.Split(goName, "_") {
		if s != "" {
			segs = append(segs, camelType(s))
		}
	}
	return strings.Join(pre, "") + strings.Join(segs, "_")
}

func camelType(goName string) string {
	var b strings.Builder
	for _, w := range words(goName) {
		b.WriteString(capitalize(w))
	}
	return b.String()
}

// typeParts: the words of qualType's class, the path's and the Go name's.
func typeParts(path, goName string) (pre, ws []string) {
	for _, w := range libWords(classPath(path)) {
		pre = append(pre, capitalize(w))
	}
	for _, w := range words(goName) {
		ws = append(ws, capitalize(w))
	}
	k := 0 // the last k words of the path are the first k of the name
	for n := min(len(pre), len(ws)); n > 0; n-- {
		if strings.Join(pre[len(pre)-n:], "") == strings.Join(ws[:n], "") {
			k = n
			break
		}
	}
	return pre[:len(pre)-k], ws
}

// nsClass: the namespace class of a library path or of a folder of them
// (go/ipfs/boxo/mfs.dart and go/ipfs/boxo/mfs → GoIpfsBoxoMfs; the root, "" →
// Go).
func nsClass(path string) string { return "Go" + libPrefix(path) }

// nsPath: how Dart reaches the namespace (go/ipfs/boxo/mfs.dart →
// go.ipfs.boxo.mfs).
func nsPath(path string) string {
	segs := []string{nsRootConst}
	for _, seg := range strings.Split(strings.TrimSuffix(strings.TrimPrefix(path, "go/"), ".dart"), "/") {
		segs = append(segs, nsMember(seg))
	}
	return strings.Join(segs, ".")
}

// nsRootConst: the top-level constant at the root of the tree.
const nsRootConst = "go"

// Layers (owner's decisions, 2026-10-29): a package's constants and option
// constructors are not members of its namespace but of a layer under it, so
// they do not hide a sub-package (crypto.MD5 and crypto/md5, grpc.Peer and
// grpc/peer): `enums`, a constant of a named type (`go.crypto.enums.md5`,
// `go.multiformats.multicodec.enums.raw`), `consts`, the other constants
// (`go.ipfs.cid.consts.raw`, `go.os.consts.devNull`), and `options`, a function
// or variable that is a functional option
// (`go.libp2p.libp2p.options.listenAddrStrings`). The other variables and
// functions stay members of the namespace.
var layers = []string{"consts", "enums", "options"}

var layerDoc = map[string]string{"consts": "constants", "enums": "constants of a named type", "options": "option constructors"}

// memberLayer: the layer of a package-level object ("" = its namespace): a
// constant's, or `options` for a function or variable of a named type whose
// name ends in Option (owner's decision, 2026-10-30: grpc.Peer's CallOption,
// an interface).
func memberLayer(o types.Object) string {
	if l := constLayer(o); l != "" {
		return l
	}
	var t types.Type
	switch o := o.(type) {
	case *types.Func:
		res, _ := splitErr(o.Type().(*types.Signature).Results())
		if len(res) != 1 {
			return ""
		}
		t = res[0]
	case *types.Var:
		t = o.Type()
	default:
		return ""
	}
	if n, ok := types.Unalias(t).(*types.Named); ok && strings.HasSuffix(n.Obj().Name(), "Option") {
		return "options"
	}
	return ""
}

// constLayer: the layer of a package-level object ("" when it is not a
// constant).
func constLayer(o types.Object) string {
	c, ok := o.(*types.Const)
	if !ok {
		return ""
	}
	if _, named := types.Unalias(c.Type()).(*types.Named); named {
		return "enums"
	}
	return "consts"
}

// layerPath: the path of a library's layer, as if it were a library under it
// (go/ipfs/cid.dart, consts → go/ipfs/cid/consts.dart): nsClass and nsPath
// name it (GoIpfsCidConsts, go.ipfs.cid.consts).
func layerPath(path, layer string) string {
	return strings.TrimSuffix(path, ".dart") + "/" + layer + ".dart"
}

// hiddenClasses: the classes goTree left out of the single import, each with
// its libraries (API.md).
var hiddenClasses [][2]string

// typeDeclRE: the declaration of the class or mixin [name].
func typeDeclRE(name string) *regexp.Regexp {
	return regexp.MustCompile(`(?m)^(?:(?:final|abstract|base|sealed|interface) )*(?:class|mixin) ` + regexp.QuoteMeta(name) + `(?:[^A-Za-z0-9_$]|$)`)
}

// nsMember: the getter of a path segment (libp2p_kad_dht → libp2pKadDht).
func nsMember(seg string) string { return memberName(seg) }

const generatedHeader = "// Generated by go/gen"

// dartPkg: the name of the Dart package (pubspec.yaml); pkgPrefix: the start of
// its library URIs.
const (
	dartPkg   = "p2p_ffi"
	pkgPrefix = "package:" + dartPkg + "/"
)

// checkPublicExports: no public library (lib/ outside lib/src/) re-exports
// another, so each type has a single public library. The only exception is
// lib/p2p_ffi.dart, the entry point of the runtime, which may export what lives
// in lib/src/ (the service, the errors, GoHandle). [out] holds the generated
// files (paths relative to go/), checked with the hand-written ones in [libDir].
func checkPublicExports(libDir string, out map[string][]byte) error {
	files := map[string][]byte{}
	for name, src := range out {
		if rel, ok := strings.CutPrefix(name, "../lib/"); ok {
			files[rel] = src
		}
	}
	err := filepath.WalkDir(libDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".dart") {
			return err
		}
		rel := filepath.ToSlash(strings.TrimPrefix(path, filepath.Clean(libDir)+string(filepath.Separator)))
		if _, generated := files[rel]; generated {
			return nil
		}
		src, err := os.ReadFile(path)
		if err == nil && !bytes.HasPrefix(src, []byte(generatedHeader)) {
			files[rel] = src
		}
		return err
	})
	if err != nil {
		return err
	}
	var bad []string
	for _, rel := range sortedKeys(files) {
		if strings.HasPrefix(rel, "src/") {
			continue
		}
		for i, line := range strings.Split(string(files[rel]), "\n") {
			target, ok := strings.CutPrefix(line, "export '")
			if !ok {
				continue
			}
			target, _, _ = strings.Cut(target, "'")
			if rel == dartPkg+".dart" && (strings.HasPrefix(target, "src/") || strings.HasPrefix(target, pkgPrefix+"src/")) {
				continue
			}
			bad = append(bad, fmt.Sprintf("lib/%s:%d re-exports '%s'", rel, i+1, target))
		}
	}
	if len(bad) > 0 {
		return fmt.Errorf("a public library re-exports another (each type has a single public library; only lib/p2p_ffi.dart may export lib/src/):\n  %s", strings.Join(bad, "\n  "))
	}
	return nil
}

// declRE: uma declaração de nível de library no Dart (gerado e formatado, ou
// escrito à mão no mesmo estilo): classe, constante, getter ou função.
var declRE = regexp.MustCompile(`^(?:(?:final |abstract |sealed |base |interface )*class|mixin|extension|const|final|var) +([A-Za-z_$][A-Za-z0-9_$]*)|^[A-Za-z_$][A-Za-z0-9_$<>?, .]*? (?:get +)?([A-Za-z_$][A-Za-z0-9_$]*) *(?:\(|\{|=>)`)

// publicNames: os nomes públicos de nível de library de [src].
func publicNames(src []byte) []string {
	var out []string
	for _, line := range strings.Split(string(src), "\n") {
		if line == "" || line[0] == ' ' || line[0] == '/' || line[0] == '}' || strings.HasPrefix(line, "import ") || strings.HasPrefix(line, "export ") || strings.HasPrefix(line, "library") || strings.HasPrefix(line, "part ") {
			continue
		}
		m := declRE.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		n := m[1] + m[2]
		if n != "" && n[0] != '_' {
			out = append(out, n)
		}
	}
	return out
}

// memberRE: a member of an extension or class, formatted (two spaces in).
var memberRE = regexp.MustCompile(`^  (?:static )?(?:[A-Za-z_$(][A-Za-z0-9_$<>?, .()]*? )?(?:get |set )?([A-Za-z_$][A-Za-z0-9_$]*) *(?:\(|=>|\{|<|;)`)

// extMembers: the names [src]'s extensions declare (`goX.<name>`). A
// declaration dart format broke after its type continues on the lines
// indented further.
// [on]: only the extensions on that class ("": all of them).
func extMembers(src []byte, on string) []string {
	var out []string
	in := false
	lines := strings.Split(string(src), "\n")
	for i, line := range lines {
		switch {
		case strings.HasPrefix(line, "extension "):
			in = on == "" || strings.HasSuffix(line, " on "+on+" {")
		case line == "}":
			in = false
		case in && strings.HasPrefix(line, "  ") && !strings.HasPrefix(line, "   ") && !strings.HasPrefix(line, "  /") && !strings.HasPrefix(line, "  @") && !strings.HasPrefix(line, "  }"):
			decl := line
			m := memberRE.FindStringSubmatch(decl)
			for j := i + 1; m == nil && j < len(lines) && strings.HasPrefix(lines[j], "    "); j++ {
				decl += " " + strings.TrimSpace(lines[j])
				m = memberRE.FindStringSubmatch(decl)
			}
			if m != nil && m[1][0] != '_' {
				out = append(out, m[1])
			}
		}
	}
	return out
}

// goTree: lib/src/go.dart, the root constant `go`, the namespace
// classes (one per folder or library under lib/go/) and the export of every
// library. [libs]: the library
// paths (relative to lib/) → their source, the generated and the hand-written
// ones, with the generated part of a hand-written one appended; [goPaths]: the
// Go package of each library, when known. It fails when two exported names
// are the same, or a member of a library's namespace hides a sub-namespace.
// A library's layers (consts, enums, options) are leaves under it.
func goTree(libs map[string][]byte, goPaths map[string]string, runtime []string) ([]byte, error) {
	lays := map[string]string{} // a layer, as a library path → its doc
	for path, src := range libs {
		for _, layer := range layers {
			if lp := layerPath(path, layer); bytes.Contains(src, []byte(" on "+nsClass(lp)+" {")) {
				lays[lp] = "The " + layerDoc[layer] + " of `" + nsPath(path) + "`"
			}
		}
	}
	doc := func(path string) (string, bool) { // a package's or a layer's
		if gp, ok := goPaths[path]; ok {
			return "Go: package `" + gp + "`", true
		}
		d, ok := lays[path]
		return d, ok
	}
	kids := map[string]map[string]bool{} // folder ("" = the root) → its child segments
	nodes := sortedKeys(libs)            // the libraries and the layers
	for _, lp := range sortedKeys(lays) {
		if _, ok := libs[lp]; ok {
			return nil, fmt.Errorf("lib/%s: a package with the name of a layer", lp)
		}
		nodes = append(nodes, lp)
	}
	sort.Strings(nodes)
	for _, path := range nodes {
		p := strings.TrimSuffix(strings.TrimPrefix(path, "go/"), ".dart")
		segs := strings.Split(p, "/")
		for i := range segs {
			dir := strings.Join(segs[:i], "/")
			if kids[dir] == nil {
				kids[dir] = map[string]bool{}
			}
			kids[dir][segs[i]] = true
		}
	}
	owner := map[string]string{} // exported name → its library
	var dup []string
	claim := func(name, where string) {
		if prev, ok := owner[name]; ok {
			dup = append(dup, fmt.Sprintf("%s (%s and %s)", name, prev, where))
			return
		}
		owner[name] = where
	}
	for _, n := range runtime {
		claim(n, "lib/p2p_ffi.dart")
	}
	// a class two modules declare (bbloom.Bloom of ipfs and of AndreasBriese)
	// leaves the single import (owner's decision, 2026-10-30): `hide`, and
	// the library of each origin has it
	declaredIn := map[string][]string{} // a class → the libraries that declare it
	for _, path := range sortedKeys(libs) {
		for _, n := range publicNames(libs[path]) {
			if typeDeclRE(n).Match(libs[path]) && !slices.Contains(declaredIn[n], path) {
				declaredIn[n] = append(declaredIn[n], path)
			}
		}
	}
	hide := map[string][]string{} // a library → the classes it does not export
	hiddenClasses = nil
	for _, n := range sortedKeys(declaredIn) {
		if ps := declaredIn[n]; len(ps) > 1 {
			for _, p := range ps {
				hide[p] = append(hide[p], n)
			}
			hiddenClasses = append(hiddenClasses, [2]string{n, strings.Join(ps, " ")})
		}
	}
	for _, path := range sortedKeys(libs) {
		for _, n := range publicNames(libs[path]) {
			if !slices.Contains(hide[path], n) {
				claim(n, "lib/"+path)
			}
		}
		dir := strings.TrimSuffix(strings.TrimPrefix(path, "go/"), ".dart")
		getters := map[string]bool{}
		for seg := range kids[dir] {
			getters[nsMember(seg)] = true
		}
		for _, n := range extMembers(libs[path], nsClass(path)) {
			if getters[n] {
				dup = append(dup, fmt.Sprintf("%s.%s: a member of lib/%s and a sub-namespace", nsPath(path), n, path))
			}
		}
	}
	var b strings.Builder
	b.WriteString(generatedHeader + ` from the libraries under lib/go/; do not edit.

/// The Go packages as namespaces: ` + "`go.<author>.<package>`" + ` reaches a package's
/// functions, constants and variables (` + "`go.ipfs.boxo.mfs.newRoot(...)`" + `); its
/// types are top-level classes named after the package (` + "`BoxoMfsRoot`" + `).
library;

`)
	for _, path := range sortedKeys(libs) {
		if h := hide[path]; len(h) > 0 {
			fmt.Fprintf(&b, "export '%s%s' hide %s;\n", pkgPrefix, path, strings.Join(h, ", "))
			continue
		}
		fmt.Fprintf(&b, "export '%s%s';\n", pkgPrefix, path)
	}
	getters := func(dir string) string {
		var g strings.Builder
		for _, seg := range sortedKeys(kids[dir]) {
			sub := strings.TrimPrefix(dir+"/"+seg, "/")
			d, ok := doc("go/" + sub + ".dart")
			if !ok {
				d = "`" + sub + "`"
			}
			fmt.Fprintf(&g, "\n  /// %s.\n  %s get %s => const %s._();\n", d, nsClass("go/"+sub), nsMember(seg), nsClass("go/"+sub))
		}
		return g.String()
	}
	claim(nsRootConst, "lib/src/go.dart")
	fmt.Fprintf(&b, "\n/// The Go packages: the authors (`%[1]s.ipfs`) and the standard library (`%[1]s.context`).\nconst %[1]s = %[2]s._();\n", nsRootConst, nsClass(""))
	for _, dir := range sortedKeys(kids) {
		if dir == "" {
			claim(nsClass(""), "lib/src/go.dart")
			fmt.Fprintf(&b, "\n/// `%s`.\nfinal class %s {\n  const %s._();\n%s}\n", nsRootConst, nsClass(""), nsClass(""), getters(""))
			continue
		}
		claim(nsClass("go/"+dir), "lib/src/go.dart")
		doc := "`" + nsPath("go/"+dir) + "`"
		if gp, ok := goPaths["go/"+dir+".dart"]; ok {
			doc = "Go: package `" + gp + "`, as `" + nsPath("go/"+dir) + "`"
		}
		fmt.Fprintf(&b, "\n/// %s.\nfinal class %s {\n  const %s._();\n%s}\n", doc, nsClass("go/"+dir), nsClass("go/"+dir), getters(dir))
	}
	for _, path := range nodes { // a library or a layer without a folder of its own
		dir := strings.TrimSuffix(strings.TrimPrefix(path, "go/"), ".dart")
		if _, ok := kids[dir]; ok {
			continue
		}
		claim(nsClass("go/"+dir), "lib/src/go.dart")
		d := "`" + nsPath("go/"+dir) + "`"
		if pd, ok := doc(path); ok {
			d = pd + ", as `" + nsPath("go/"+dir) + "`"
		}
		fmt.Fprintf(&b, "\n/// %s.\nfinal class %s {\n  const %s._();\n}\n", d, nsClass("go/"+dir), nsClass("go/"+dir))
	}
	if len(dup) > 0 {
		sort.Strings(dup)
		return nil, fmt.Errorf("names that clash in the single import:\n  %s", strings.Join(dup, "\n  "))
	}
	return formatDart("src/go.dart", b.String()), nil
}

// staleGenerated: arquivos gerados em lib/ que o gerador não produz mais (o
// pacote saiu das raízes ou mudou de lugar).
func staleGenerated(out map[string][]byte) []string {
	var stale []string
	_ = filepath.WalkDir("../lib", func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".dart") {
			return err
		}
		name := "../lib/" + filepath.ToSlash(strings.TrimPrefix(path, filepath.Clean("../lib")+string(filepath.Separator)))
		if _, ok := out[name]; ok {
			return nil
		}
		if src, err := os.ReadFile(path); err == nil && bytes.HasPrefix(src, []byte(generatedHeader)) {
			stale = append(stale, name)
		}
		return nil
	})
	sort.Strings(stale)
	return stale
}
