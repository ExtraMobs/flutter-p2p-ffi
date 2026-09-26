package main

import (
	"fmt"
	"go/token"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"

	"golang.org/x/tools/go/packages"
)

// DumpDoc é a raiz do JSON emitido pelo goast.
type DumpDoc struct {
	SchemaVersion int            `json:"schemaVersion"`
	Tool          string         `json:"tool"`
	GoVersion     string         `json:"goVersion"`
	Packages      []*PackageDump `json:"packages"`
}

// PackageDump é o dump de um único pacote Go (a unidade de trabalho).
type PackageDump struct {
	Path         string       `json:"path"`
	Name         string       `json:"name"`
	Files        []*FileDump  `json:"files"`
	Imports      []ImportDump `json:"imports"`
	TypeTable    []jobject    `json:"typeTable"`
	Implements   []jobject    `json:"implements"`
	InitOrder    [][]string   `json:"initOrder"`
	StdlibUsage  []string     `json:"stdlibUsage"`
	ReflectUsage []ReflectUse `json:"reflectUsage"`
}

// FileDump associa o caminho do arquivo-fonte à sua AST.
type FileDump struct {
	Path string `json:"path"`
	AST  any    `json:"ast"`
}

// ImportDump registra um import do pacote.
type ImportDump struct {
	Path string `json:"path"`
	Name string `json:"name"`
}

// ReflectUse registra um ponto de uso do pacote reflect.
type ReflectUse struct {
	Pos  string `json:"pos"` // "file:line:column"
	Expr string `json:"expr"`
}

// Dump carrega o(s) pacote(s) indicados por target e produz o documento JSON.
func Dump(target string) (*DumpDoc, error) {
	fset := token.NewFileSet()
	cfg := &packages.Config{
		Mode: packages.NeedName | packages.NeedFiles | packages.NeedSyntax |
			packages.NeedTypes | packages.NeedTypesInfo | packages.NeedImports,
		Fset: fset,
	}
	pattern, err := resolveTarget(cfg, target)
	if err != nil {
		return nil, err
	}
	pkgs, loadErr := packages.Load(cfg, pattern)
	if loadErr == nil {
		if len(pkgs) == 0 {
			loadErr = fmt.Errorf("nenhum pacote encontrado para %q", target)
		} else {
			var errs []string
			for _, p := range pkgs {
				for _, e := range p.Errors {
					errs = append(errs, e.Error())
				}
			}
			if len(errs) > 0 {
				loadErr = fmt.Errorf("erros de carregamento:\n%s", strings.Join(errs, "\n"))
			}
		}
	}
	if loadErr != nil {
		// Fallback: arquivos .go soltos fora de módulo (fixtures, casos
		// simples que só importam a stdlib).
		loose, looseErr := loadLoose(fset, target)
		if looseErr != nil {
			return nil, fmt.Errorf("carregando %q: %w (fallback loose: %v)", target, loadErr, looseErr)
		}
		pkgs = []*packages.Package{loose}
	}

	// Ordem determinística: import path alfabético.
	sort.Slice(pkgs, func(i, j int) bool { return pkgs[i].PkgPath < pkgs[j].PkgPath })

	doc := &DumpDoc{
		SchemaVersion: 6,
		Tool:          "goast",
		GoVersion:     runtime.Version(),
	}
	for _, p := range pkgs {
		doc.Packages = append(doc.Packages, dumpPackage(fset, p))
	}
	return doc, nil
}

// resolveTarget interpreta o alvo: diretório vira pattern "." com Dir
// ajustado; "dir/..." vira pattern "./..." com Dir = dir; o restante é
// tratado como padrão de pacote (import path ou ./...).
//
// O sufixo "/..." é testado antes do diretório: no Windows, os.Stat("dir\...")
// normaliza o componente "..." e devolve o próprio dir.
func resolveTarget(cfg *packages.Config, target string) (string, error) {
	pattern := "."
	dir := target
	if strings.HasSuffix(target, "/...") {
		pattern, dir = "./...", strings.TrimSuffix(target, "/...")
		if dir == "" || dir == "." {
			return pattern, nil
		}
	}
	if st, err := os.Stat(filepath.FromSlash(dir)); err == nil && st.IsDir() {
		abs, err := filepath.Abs(filepath.FromSlash(dir))
		if err != nil {
			return "", err
		}
		cfg.Dir = abs
		return pattern, nil
	}
	return target, nil
}
