// go_module_index.go
//
// AST-based audit index for Go repositories, mirroring the methodology and
// output format of dart_ipfs's tool/generate_module_index.dart so the two
// can be read side by side. Generic over any Go module -- point it at kubo,
// go-libp2p, go-multiaddr-dns, or anything else with a go.mod.
//
// Per Go package (== one directory with .go files, same as Dart's "module"
// concept but at finer granularity) it writes a markdown file listing every
// file's doc comment, every declared type (struct/interface) with its
// methods/fields, every top-level func/var/const, each with:
//   - "calls"        -- identifiers invoked inside it (by name, NOT
//     resolved to a specific declaration)
//   - "referenced by" -- other declared members elsewhere whose body
//     mentions this exact name
//
// Go allows a type's methods to live in a different file than the type's
// own declaration (a common pattern -- e.g. type in foo.go, String() in
// foo_string.go). Association is therefore done at the PACKAGE level, not
// per file: every file in a package is parsed first, then methods are
// matched to their receiver type across the whole package, and finally
// each type is rendered under the file where it was actually declared
// (carrying all its methods, wherever they live).
//
// CAVEAT (same as the Dart tool): this walks the unresolved AST (go/parser,
// no go/types type-checking), so "calls"/"referenced by" match on
// identifier text, not resolved declarations. When a name is declared by
// more than one type, every declaration shares the same "referenced by"
// list, tagged to say so.
//
// The package-to-package import graph only follows imports whose path is
// prefixed by the target module's own import path (from go.mod); anything
// else (stdlib, third-party deps) is recorded as an external dependency,
// same as the Dart tool treats package:dart_ipfs_core as a [pkg] edge.
//
// Usage:
//
//	go run go_module_index.go <repo-root> <output-dir>
//	go run go_module_index.go -json <out.json> <repo-dir> [<repo-dir>...]
//
// The -json mode is a second, independent output format consumed by
// tool/audit_ast_nomenclature.py: one JSON document listing every Go
// declaration (exported and unexported) across any number of repos in a
// single process, without needing a resolvable go.mod for each one -- it
// walks files directly, so it also works on repos whose go.mod lives in a
// subdirectory (e.g. go-stdlib/src/go.mod) or is entirely absent.
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"go/types"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

type member struct {
	kind     string // method, field, function, variable, const
	name     string
	doc      string
	calls    map[string]bool
	declFile string
}

type typeDecl struct {
	kind     string // struct, interface
	name     string
	doc      string
	embeds   []string
	declFile string
	members  []*member // fields (declared alongside the type) + methods (from anywhere in the package)
}

type rawFunc struct {
	name     string
	doc      string
	calls    map[string]bool
	recvType string // "" if not a method
	declFile string
}

type pkgAudit struct {
	importPath string
	relDir     string
	doc        string
	fileDocs   map[string]string    // repo-relative file -> its own doc comment
	files      []string             // repo-relative file paths, this package, sorted
	types      map[string]*typeDecl // name -> type, this package
	funcs      []*rawFunc           // all funcs/methods, this package
	topVars    []*member            // top-level var/const, this package
}

func newMember(kind, name, declFile string) *member {
	return &member{kind: kind, name: name, calls: map[string]bool{}, declFile: declFile}
}

func docText(cg *ast.CommentGroup) string {
	if cg == nil {
		return ""
	}
	text := strings.TrimSpace(cg.Text())
	if i := strings.IndexByte(text, '\n'); i >= 0 {
		text = text[:i]
	}
	return strings.TrimSpace(text)
}

// isDeprecatedDoc reports whether cg contains a paragraph starting with the
// Go convention "Deprecated: ..." (godoc.org / go/doc treat this as the
// deprecation marker, regardless of which line of the comment it starts on).
func isDeprecatedDoc(cg *ast.CommentGroup) bool {
	if cg == nil {
		return false
	}
	for _, line := range strings.Split(cg.Text(), "\n") {
		if strings.HasPrefix(strings.TrimSpace(line), "Deprecated:") {
			return true
		}
	}
	return false
}

// collectCalls walks a node and records every identifier used as a call
// target or selector -- the Go analog of the Dart tool's _NameCollector.
func collectCalls(node ast.Node, out map[string]bool) {
	if node == nil {
		return
	}
	ast.Inspect(node, func(n ast.Node) bool {
		switch v := n.(type) {
		case *ast.CallExpr:
			switch fn := v.Fun.(type) {
			case *ast.Ident:
				out[fn.Name] = true
			case *ast.SelectorExpr:
				out[fn.Sel.Name] = true
			}
		case *ast.SelectorExpr:
			out[v.Sel.Name] = true
		case *ast.Ident:
			if v.Name != "_" {
				out[v.Name] = true
			}
		}
		return true
	})
}

func isExported(name string) bool {
	if name == "" {
		return false
	}
	r := name[0]
	return r >= 'A' && r <= 'Z'
}

func typeString(expr ast.Expr) string {
	if expr == nil {
		return ""
	}
	switch t := expr.(type) {
	case *ast.Ident:
		return t.Name
	case *ast.SelectorExpr:
		if id, ok := t.X.(*ast.Ident); ok {
			return id.Name + "." + t.Sel.Name
		}
		return t.Sel.Name
	case *ast.StarExpr:
		return "*" + typeString(t.X)
	default:
		return ""
	}
}

// auditFile parses one file and feeds its declarations into pa (package-
// level accumulator). Association of methods to types happens later, once
// every file in the package has been parsed.
func auditFile(fset *token.FileSet, path, relFile string, pa *pkgAudit) {
	src, err := parser.ParseFile(fset, path, nil, parser.ParseComments)
	if err != nil {
		return
	}
	if fd := docText(src.Doc); fd != "" {
		pa.fileDocs[relFile] = fd
		if pa.doc == "" {
			pa.doc = fd
		}
	}

	for _, decl := range src.Decls {
		switch d := decl.(type) {
		case *ast.GenDecl:
			switch d.Tok {
			case token.TYPE:
				for _, spec := range d.Specs {
					ts, ok := spec.(*ast.TypeSpec)
					if !ok || !isExported(ts.Name.Name) {
						continue
					}
					td := &typeDecl{name: ts.Name.Name, declFile: relFile}
					if ts.Doc != nil {
						td.doc = docText(ts.Doc)
					} else {
						td.doc = docText(d.Doc)
					}
					switch st := ts.Type.(type) {
					case *ast.StructType:
						td.kind = "struct"
						for _, f := range st.Fields.List {
							if len(f.Names) == 0 {
								td.embeds = append(td.embeds, typeString(f.Type))
								continue
							}
							for _, n := range f.Names {
								if !isExported(n.Name) {
									continue
								}
								m := newMember("field", n.Name, relFile)
								m.doc = docText(f.Doc)
								td.members = append(td.members, m)
							}
						}
					case *ast.InterfaceType:
						td.kind = "interface"
						for _, f := range st.Methods.List {
							if len(f.Names) == 0 {
								td.embeds = append(td.embeds, typeString(f.Type))
								continue
							}
							for _, n := range f.Names {
								if !isExported(n.Name) {
									continue
								}
								m := newMember("method", n.Name, relFile)
								m.doc = docText(f.Doc)
								td.members = append(td.members, m)
							}
						}
					default:
						continue
					}
					pa.types[td.name] = td
				}
			case token.VAR, token.CONST:
				kind := "variable"
				if d.Tok == token.CONST {
					kind = "const"
				}
				for _, spec := range d.Specs {
					vs, ok := spec.(*ast.ValueSpec)
					if !ok {
						continue
					}
					for i, n := range vs.Names {
						if !isExported(n.Name) {
							continue
						}
						m := newMember(kind, n.Name, relFile)
						m.doc = docText(vs.Doc)
						if i < len(vs.Values) {
							collectCalls(vs.Values[i], m.calls)
						}
						pa.topVars = append(pa.topVars, m)
					}
				}
			}
		case *ast.FuncDecl:
			if !isExported(d.Name.Name) {
				continue
			}
			rf := &rawFunc{name: d.Name.Name, doc: docText(d.Doc), calls: map[string]bool{}, declFile: relFile}
			// d.Body is nil for funcs declared without a body (e.g. the
			// assembly-implemented functions that riddle the stdlib, such
			// as runtime/syscall stubs). ast.Node is an interface, so a
			// typed-nil *ast.BlockStmt passed as ast.Node is NOT caught by
			// collectCalls' "node == nil" check and crashes go/ast.Inspect
			// with a nil pointer dereference. Guard at the call site.
			if d.Body != nil {
				collectCalls(d.Body, rf.calls)
			}
			if d.Recv != nil && len(d.Recv.List) > 0 {
				rf.recvType = strings.TrimPrefix(typeString(d.Recv.List[0].Type), "*")
			}
			pa.funcs = append(pa.funcs, rf)
		}
	}
}

// resolveMethods attaches each package's methods to their receiver type,
// searched across every file in the package -- Go allows a type and its
// methods to live in different files.
func resolveMethods(pa *pkgAudit) {
	for _, rf := range pa.funcs {
		m := newMember("function", rf.name, rf.declFile)
		m.doc = rf.doc
		m.calls = rf.calls
		if rf.recvType != "" {
			if td, ok := pa.types[rf.recvType]; ok {
				m.kind = "method"
				td.members = append(td.members, m)
				continue
			}
			// Receiver type not found as an exported struct/interface in
			// this package (e.g. unexported helper type) -- still record
			// it, qualified, rather than silently passing it off as a
			// bare top-level function.
			m.name = rf.recvType + "." + rf.name
		}
		pa.topVars = append(pa.topVars, m)
	}
}

var importPattern = regexp.MustCompile(`"([^"]+)"`)

func main() {
	if len(os.Args) >= 2 && os.Args[1] == "-json" {
		runJSONMode(os.Args[2:])
		return
	}
	runMarkdownMode(os.Args[1:])
}

func runMarkdownMode(args []string) {
	if len(args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: go run go_module_index.go <repo-root> <output-dir>")
		fmt.Fprintln(os.Stderr, "   or: go run go_module_index.go -json <out.json> <repo-dir> [<repo-dir>...]")
		os.Exit(1)
	}
	repoRoot := args[0]
	outDir := args[1]

	modPath := moduleImportPath(repoRoot)
	if modPath == "" {
		fmt.Fprintln(os.Stderr, "could not read module path from go.mod")
		os.Exit(1)
	}
	fmt.Fprintf(os.Stderr, "Module: %s\n", modPath)

	fset := token.NewFileSet()
	pkgs := map[string]*pkgAudit{}
	fileCount := 0

	filepath.Walk(repoRoot, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() {
			base := filepath.Base(path)
			if base == "vendor" || base == ".git" || strings.HasPrefix(base, ".") {
				return filepath.SkipDir
			}
			return nil
		}
		if !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		relDir, _ := filepath.Rel(repoRoot, filepath.Dir(path))
		relDir = filepath.ToSlash(relDir)
		if relDir == "." {
			relDir = ""
		}
		relFile, _ := filepath.Rel(repoRoot, path)
		relFile = filepath.ToSlash(relFile)

		pa, exists := pkgs[relDir]
		if !exists {
			imp := strings.TrimSuffix(modPath+"/"+relDir, "/")
			pa = &pkgAudit{importPath: imp, relDir: relDir, fileDocs: map[string]string{}, types: map[string]*typeDecl{}}
			pkgs[relDir] = pa
		}
		pa.files = append(pa.files, relFile)
		auditFile(fset, path, relFile, pa)
		fileCount++
		return nil
	})

	for _, pa := range pkgs {
		sort.Strings(pa.files)
		resolveMethods(pa)
	}

	fmt.Fprintf(os.Stderr, "Parsed %d files across %d packages\n", fileCount, len(pkgs))

	// Import graph: relDir -> set of other relDirs it imports (internal),
	// plus external deps.
	internalEdges := map[string]map[string]bool{}
	externalEdges := map[string]map[string]bool{}
	for relDir, pa := range pkgs {
		for _, relFile := range pa.files {
			content, err := os.ReadFile(filepath.Join(repoRoot, filepath.FromSlash(relFile)))
			if err != nil {
				continue
			}
			for _, line := range strings.Split(string(content), "\n") {
				line = strings.TrimSpace(line)
				if !strings.HasPrefix(line, "\"") {
					continue
				}
				m := importPattern.FindStringSubmatch(line)
				if m == nil {
					continue
				}
				target := m[1]
				if strings.HasPrefix(target, modPath) {
					targetRel := strings.TrimPrefix(strings.TrimPrefix(target, modPath), "/")
					if targetRel != relDir {
						if internalEdges[relDir] == nil {
							internalEdges[relDir] = map[string]bool{}
						}
						internalEdges[relDir][targetRel] = true
					}
				} else if !isStdlib(target) {
					if externalEdges[relDir] == nil {
						externalEdges[relDir] = map[string]bool{}
					}
					externalEdges[relDir][target] = true
				}
			}
		}
	}

	// Reverse reference index (by name), same by-name caveat as Dart tool.
	// Keys are repo-root-relative "file (Owner.Member)" labels.
	declaredBy := map[string][]string{}
	referencesOf := map[string][]string{}
	for _, pa := range pkgs {
		for _, td := range pa.types {
			for _, m := range td.members {
				declaredBy[m.name] = append(declaredBy[m.name], fmt.Sprintf("%s (%s.%s)", m.declFile, td.name, m.name))
			}
		}
		for _, m := range pa.topVars {
			declaredBy[m.name] = append(declaredBy[m.name], fmt.Sprintf("%s (%s)", m.declFile, m.name))
		}
	}
	for _, pa := range pkgs {
		for _, td := range pa.types {
			for _, m := range td.members {
				self := fmt.Sprintf("%s (%s.%s)", m.declFile, td.name, m.name)
				for call := range m.calls {
					if _, ok := declaredBy[call]; !ok {
						continue
					}
					referencesOf[call] = append(referencesOf[call], self)
				}
			}
		}
		for _, m := range pa.topVars {
			self := fmt.Sprintf("%s (%s)", m.declFile, m.name)
			for call := range m.calls {
				if _, ok := declaredBy[call]; !ok {
					continue
				}
				referencesOf[call] = append(referencesOf[call], self)
			}
		}
	}

	os.MkdirAll(outDir, 0o755)
	var relDirs []string
	for relDir := range pkgs {
		relDirs = append(relDirs, relDir)
	}
	sort.Strings(relDirs)

	for _, relDir := range relDirs {
		writePkgFile(outDir, pkgs[relDir], internalEdges[relDir], externalEdges[relDir], referencesOf, declaredBy)
	}
	writeOverview(outDir, modPath, relDirs, pkgs, internalEdges, fileCount)

	fmt.Fprintf(os.Stderr, "Wrote %d package files to %s\n", len(pkgs), outDir)
}

func isStdlib(pkg string) bool {
	first := strings.SplitN(pkg, "/", 2)[0]
	return !strings.Contains(first, ".")
}

func moduleImportPath(repoRoot string) string {
	f, err := os.Open(filepath.Join(repoRoot, "go.mod"))
	if err != nil {
		return ""
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if strings.HasPrefix(line, "module ") {
			return strings.TrimSpace(strings.TrimPrefix(line, "module"))
		}
	}
	return ""
}

func memberLine(owner *typeDecl, m *member, referencesOf map[string][]string, declaredBy map[string][]string) string {
	selfLabel := m.name
	if owner != nil {
		selfLabel = owner.name + "." + m.name
	}
	self := fmt.Sprintf("%s (%s)", m.declFile, selfLabel)
	var external []string
	for _, r := range referencesOf[m.name] {
		if r != self {
			external = append(external, r)
		}
	}
	var buf strings.Builder
	fmt.Fprintf(&buf, "- **%s** (%s)", m.name, m.kind)
	if m.doc != "" {
		fmt.Fprintf(&buf, " — %s", m.doc)
	}
	if len(m.calls) > 0 {
		var calls []string
		for c := range m.calls {
			calls = append(calls, c)
		}
		sort.Strings(calls)
		fmt.Fprintf(&buf, "\n  - calls: %s", strings.Join(calls, ", "))
	}
	if len(external) > 0 {
		ambiguity := ""
		if len(declaredBy[m.name]) > 1 {
			ambiguity = fmt.Sprintf(" (name shared by %d declarations -- not resolved to this one specifically, see caveat)", len(declaredBy[m.name]))
		}
		fmt.Fprintf(&buf, "\n  - referenced by (by name)%s:", ambiguity)
		sort.Strings(external)
		for _, r := range external {
			fmt.Fprintf(&buf, "\n    - `%s`", r)
		}
	}
	return buf.String()
}

func writePkgFile(outDir string, pa *pkgAudit, internal, external map[string]bool, referencesOf map[string][]string, declaredBy map[string][]string) {
	label := pa.relDir
	if label == "" {
		label = "(root)"
	}
	safeName := strings.ReplaceAll(label, "/", "_")

	// Group types and top-level members by the file where they're declared.
	typesByFile := map[string][]*typeDecl{}
	var typeNames []string
	for name := range pa.types {
		typeNames = append(typeNames, name)
	}
	sort.Strings(typeNames)
	for _, name := range typeNames {
		td := pa.types[name]
		typesByFile[td.declFile] = append(typesByFile[td.declFile], td)
	}
	topByFile := map[string][]*member{}
	for _, m := range pa.topVars {
		topByFile[m.declFile] = append(topByFile[m.declFile], m)
	}

	var buf strings.Builder
	fmt.Fprintf(&buf, "---\npackage: %s\nimport-path: %s\nkind: go AST audit\n---\n\n", label, pa.importPath)
	fmt.Fprintf(&buf, "# Package `%s` (`%s`)\n\n", label, pa.importPath)
	fmt.Fprintf(&buf, "_Generated by go_module_index.go via go/parser AST (unresolved, no go/types). \"Calls\"/\"referenced by\" match by identifier name, not resolved type. Do not edit by hand._\n\n")
	if pa.doc != "" {
		fmt.Fprintf(&buf, "%s\n\n", pa.doc)
	}

	if len(internal) > 0 {
		var deps []string
		for d := range internal {
			dl := d
			if dl == "" {
				dl = "(root)"
			}
			deps = append(deps, fmt.Sprintf("[%s](%s.md)", dl, strings.ReplaceAll(dl, "/", "_")))
		}
		sort.Strings(deps)
		fmt.Fprintf(&buf, "Depends on (internal): %s\n\n", strings.Join(deps, ", "))
	}
	if len(external) > 0 {
		var deps []string
		for d := range external {
			deps = append(deps, d)
		}
		sort.Strings(deps)
		fmt.Fprintf(&buf, "Depends on (external): %s\n\n", strings.Join(deps, ", "))
	}

	for _, f := range pa.files {
		hasContent := len(typesByFile[f]) > 0 || len(topByFile[f]) > 0
		if !hasContent && pa.fileDocs[f] == "" {
			continue
		}
		fmt.Fprintf(&buf, "## `%s`\n\n", f)
		if d := pa.fileDocs[f]; d != "" {
			fmt.Fprintf(&buf, "%s\n\n", d)
		}
		for _, t := range typesByFile[f] {
			extra := ""
			if len(t.embeds) > 0 {
				extra = " embeds " + strings.Join(t.embeds, ", ")
			}
			fmt.Fprintf(&buf, "### %s `%s`%s\n\n", t.kind, t.name, extra)
			if t.doc != "" {
				fmt.Fprintf(&buf, "%s\n\n", t.doc)
			}
			if len(t.members) == 0 {
				buf.WriteString("_(no exported members)_\n\n")
				continue
			}
			for _, m := range t.members {
				buf.WriteString(memberLine(t, m, referencesOf, declaredBy))
				buf.WriteByte('\n')
			}
			buf.WriteByte('\n')
		}
		for _, m := range topByFile[f] {
			fmt.Fprintf(&buf, "### top-level `%s` (%s)\n\n", m.name, m.kind)
			buf.WriteString(memberLine(nil, m, referencesOf, declaredBy))
			buf.WriteString("\n\n")
		}
	}

	os.WriteFile(filepath.Join(outDir, safeName+".md"), []byte(buf.String()), 0o644)
}

func writeOverview(outDir, modPath string, relDirs []string, pkgs map[string]*pkgAudit, internalEdges map[string]map[string]bool, fileCount int) {
	var buf strings.Builder
	fmt.Fprintf(&buf, "# Go Module Index — Overview\n\n")
	fmt.Fprintf(&buf, "Module: `%s`. Generated by `go_module_index.go`, mirroring dart_ipfs's `tool/generate_module_index.dart` for side-by-side comparison. %d files across %d packages.\n\n", modPath, fileCount, len(relDirs))
	fmt.Fprintf(&buf, "| Package | Files | Internal deps |\n|---|---|---|\n")
	for _, relDir := range relDirs {
		label := relDir
		if label == "" {
			label = "(root)"
		}
		safeName := strings.ReplaceAll(label, "/", "_")
		var deps []string
		for d := range internalEdges[relDir] {
			dl := d
			if dl == "" {
				dl = "(root)"
			}
			deps = append(deps, dl)
		}
		sort.Strings(deps)
		depsStr := "—"
		if len(deps) > 0 {
			depsStr = strings.Join(deps, ", ")
		}
		fmt.Fprintf(&buf, "| [%s](%s.md) | %d | %s |\n", label, safeName, len(pkgs[relDir].files), depsStr)
	}
	os.WriteFile(filepath.Join(outDir, "README.md"), []byte(buf.String()), 0o644)
}

// ---------------------------------------------------------------------------
// JSON mode.
//
// Independent from the markdown mode above: it does not need a resolvable
// go.mod (so it also works on repos like go-stdlib, whose go.mod lives in a
// subdirectory), includes unexported declarations, and emits one flat decl
// list per module instead of a per-package narrative. See the JSON schema
// in the package doc comment / tool/audit_ast_nomenclature.py's consumer.
// ---------------------------------------------------------------------------

type jsonDecl struct {
	Kind       string  `json:"kind"`
	Name       string  `json:"name"`
	Parent     *string `json:"parent"`
	File       string  `json:"file"`
	Doc        string  `json:"doc"`
	Deprecated bool    `json:"deprecated"`
	Exported   bool    `json:"exported"`
	Alias      bool    `json:"alias"`
	Target     string  `json:"target"`
}

type jsonParseError struct {
	File    string `json:"file"`
	Message string `json:"message"`
}

type jsonModule struct {
	Packages    map[string]string `json:"packages"`
	Decls       []jsonDecl        `json:"decls"`
	ParseErrors []jsonParseError  `json:"parseErrors"`
}

type jsonOutput struct {
	Version int                    `json:"version"`
	Modules map[string]*jsonModule `json:"modules"`
}

func runJSONMode(args []string) {
	if len(args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: go run go_module_index.go -json <out.json> <repo-dir> [<repo-dir>...]")
		os.Exit(1)
	}
	outPath := args[0]
	repoDirs := args[1:]

	cwd, err := os.Getwd()
	if err != nil {
		cwd = ""
	}

	out := jsonOutput{Version: 1, Modules: map[string]*jsonModule{}}
	for _, repoDir := range repoDirs {
		clean := strings.TrimRight(filepath.ToSlash(filepath.Clean(repoDir)), "/")
		key := clean
		if i := strings.LastIndex(clean, "/"); i >= 0 {
			key = clean[i+1:]
		}
		start := time.Now()
		mod := buildModuleJSON(cwd, repoDir)
		fmt.Fprintf(os.Stderr, "%s: %d decls across %d packages, %d parse errors (%s)\n",
			key, len(mod.Decls), len(mod.Packages), len(mod.ParseErrors), time.Since(start).Round(time.Millisecond))
		out.Modules[key] = mod
	}

	data, err := json.MarshalIndent(out, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to marshal JSON: %v\n", err)
		os.Exit(1)
	}
	if err := os.WriteFile(outPath, data, 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "failed to write %s: %v\n", outPath, err)
		os.Exit(1)
	}
}

// relFileFromCwd renders path relative to cwd (the project root, in
// practice), forward-slashed, so the JSON "file" field reads like
// "go-ipfs-reference/boxo/bitswap/client.go" regardless of whether the
// repo-dir argument was itself relative or absolute.
func relFileFromCwd(cwd, path string) string {
	if cwd != "" {
		if rel, err := filepath.Rel(cwd, path); err == nil {
			return filepath.ToSlash(rel)
		}
	}
	return filepath.ToSlash(path)
}

// buildModuleJSON walks every .go file under repoDir (skipping vendor,
// .git, dot-dirs, testdata and _test.go files) and parses it with
// go/parser (comments kept, no type-checking), tolerating files that fail
// to parse.
func buildModuleJSON(cwd, repoDir string) *jsonModule {
	mod := &jsonModule{Packages: map[string]string{}, Decls: []jsonDecl{}, ParseErrors: []jsonParseError{}}
	fset := token.NewFileSet()

	filepath.Walk(repoDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() {
			base := filepath.Base(path)
			if base == "vendor" || base == ".git" || base == "testdata" || strings.HasPrefix(base, ".") {
				return filepath.SkipDir
			}
			return nil
		}
		if !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}

		projFile := relFileFromCwd(cwd, path)
		src, perr := parser.ParseFile(fset, path, nil, parser.ParseComments)
		if perr != nil {
			mod.ParseErrors = append(mod.ParseErrors, jsonParseError{File: projFile, Message: perr.Error()})
			return nil
		}

		relDir, _ := filepath.Rel(repoDir, filepath.Dir(path))
		relDir = filepath.ToSlash(relDir)
		if relDir == "." {
			relDir = ""
		}
		if _, exists := mod.Packages[relDir]; !exists {
			mod.Packages[relDir] = src.Name.Name
		}

		mod.Decls = append(mod.Decls, declsFromFile(src, projFile)...)
		return nil
	})

	return mod
}

// exprSource renders the source text of a type expression, e.g. "[]byte" or
// "pkg.Foo". go/types.ExprString is purely syntactic (no type-checking
// needed) and matches Go source formatting closely enough for this purpose.
func exprSource(expr ast.Expr) string {
	if expr == nil {
		return ""
	}
	return types.ExprString(expr)
}

// embeddedBaseName returns the base name of an embedded field's type
// expression, dropping any package qualifier, pointer or generic
// instantiation: "sync.Mutex" -> "Mutex", "*Foo" -> "Foo", "Set[T]" -> "Set".
func embeddedBaseName(expr ast.Expr) string {
	switch t := expr.(type) {
	case *ast.Ident:
		return t.Name
	case *ast.SelectorExpr:
		return t.Sel.Name
	case *ast.StarExpr:
		return embeddedBaseName(t.X)
	case *ast.IndexExpr:
		return embeddedBaseName(t.X)
	case *ast.IndexListExpr:
		return embeddedBaseName(t.X)
	default:
		return exprSource(expr)
	}
}

// recvBaseName returns the receiver's base type name, stripping the pointer
// and any generic type parameters: "*Set[T]" -> "Set".
func recvBaseName(expr ast.Expr) string {
	switch t := expr.(type) {
	case *ast.Ident:
		return t.Name
	case *ast.StarExpr:
		return recvBaseName(t.X)
	case *ast.IndexExpr:
		return recvBaseName(t.X)
	case *ast.IndexListExpr:
		return recvBaseName(t.X)
	default:
		return ""
	}
}

// declsFromFile extracts every declaration record described in the JSON
// schema from one parsed file, exported and unexported alike.
func declsFromFile(src *ast.File, file string) []jsonDecl {
	var out []jsonDecl

	for _, decl := range src.Decls {
		switch d := decl.(type) {
		case *ast.GenDecl:
			switch d.Tok {
			case token.TYPE:
				for _, spec := range d.Specs {
					ts, ok := spec.(*ast.TypeSpec)
					if !ok {
						continue
					}
					doc := docText(ts.Doc)
					if doc == "" {
						doc = docText(d.Doc)
					}
					dep := isDeprecatedDoc(ts.Doc) || isDeprecatedDoc(d.Doc)
					name := ts.Name.Name

					switch st := ts.Type.(type) {
					case *ast.StructType:
						out = append(out, jsonDecl{Kind: "struct", Name: name, File: file, Doc: doc, Deprecated: dep, Exported: isExported(name)})
						if st.Fields != nil {
							for _, f := range st.Fields.List {
								fdoc := docText(f.Doc)
								fdep := isDeprecatedDoc(f.Doc)
								if len(f.Names) == 0 {
									fname := embeddedBaseName(f.Type)
									parent := name
									out = append(out, jsonDecl{Kind: "field", Name: fname, Parent: &parent, File: file, Doc: fdoc, Deprecated: fdep, Exported: isExported(fname)})
									continue
								}
								for _, n := range f.Names {
									parent := name
									out = append(out, jsonDecl{Kind: "field", Name: n.Name, Parent: &parent, File: file, Doc: fdoc, Deprecated: fdep, Exported: isExported(n.Name)})
								}
							}
						}
					case *ast.InterfaceType:
						out = append(out, jsonDecl{Kind: "interface", Name: name, File: file, Doc: doc, Deprecated: dep, Exported: isExported(name)})
						if st.Methods != nil {
							for _, f := range st.Methods.List {
								if len(f.Names) == 0 {
									// Embedded interface: ignored per spec.
									continue
								}
								fdoc := docText(f.Doc)
								fdep := isDeprecatedDoc(f.Doc)
								for _, n := range f.Names {
									parent := name
									out = append(out, jsonDecl{Kind: "method", Name: n.Name, Parent: &parent, File: file, Doc: fdoc, Deprecated: fdep, Exported: isExported(n.Name)})
								}
							}
						}
					default:
						out = append(out, jsonDecl{
							Kind:       "type",
							Name:       name,
							File:       file,
							Doc:        doc,
							Deprecated: dep,
							Exported:   isExported(name),
							Alias:      ts.Assign != token.NoPos,
							Target:     exprSource(ts.Type),
						})
					}
				}
			case token.VAR, token.CONST:
				kind := "var"
				if d.Tok == token.CONST {
					kind = "const"
				}
				for _, spec := range d.Specs {
					vs, ok := spec.(*ast.ValueSpec)
					if !ok {
						continue
					}
					doc := docText(vs.Doc)
					if doc == "" {
						doc = docText(d.Doc)
					}
					dep := isDeprecatedDoc(vs.Doc) || isDeprecatedDoc(d.Doc)
					for _, n := range vs.Names {
						if n.Name == "_" {
							continue
						}
						out = append(out, jsonDecl{Kind: kind, Name: n.Name, File: file, Doc: doc, Deprecated: dep, Exported: isExported(n.Name)})
					}
				}
			}
		case *ast.FuncDecl:
			name := d.Name.Name
			kind := "func"
			var parent *string
			if d.Recv != nil && len(d.Recv.List) > 0 {
				if base := recvBaseName(d.Recv.List[0].Type); base != "" {
					kind = "method"
					parent = &base
				}
			}
			out = append(out, jsonDecl{
				Kind:       kind,
				Name:       name,
				Parent:     parent,
				File:       file,
				Doc:        docText(d.Doc),
				Deprecated: isDeprecatedDoc(d.Doc),
				Exported:   isExported(name),
			})
		}
	}

	return out
}
