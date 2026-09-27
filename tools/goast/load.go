package main

import (
	"fmt"
	"go/token"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"golang.org/x/tools/go/packages"
)

func load(dir string, targets []string) (*token.FileSet, []*packages.Package, error) {
	fset := token.NewFileSet()
	cfg := &packages.Config{
		Mode: packages.NeedName | packages.NeedFiles | packages.NeedSyntax |
			packages.NeedTypes | packages.NeedTypesInfo | packages.NeedImports |
			packages.NeedModule,
		Fset: fset,
		Dir:  dir,
	}
	target := strings.Join(targets, " ")
	if len(targets) > 3 {
		target = fmt.Sprintf("%s ... (%d alvos)", targets[0], len(targets))
	}
	patterns := targets
	if dir == "" && len(targets) == 1 {
		pattern, err := resolveTarget(cfg, targets[0])
		if err != nil {
			return nil, nil, err
		}
		patterns = []string{pattern}
	}
	pkgs, loadErr := packages.Load(cfg, patterns...)
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
	if loadErr != nil && dir == "" && len(targets) == 1 {
		// Fallback: arquivos .go soltos fora de módulo (fixtures, casos
		// simples que só importam a stdlib).
		loose, looseErr := loadLoose(fset, target)
		if looseErr != nil {
			return nil, nil, fmt.Errorf("carregando %q: %w (fallback loose: %v)", target, loadErr, looseErr)
		}
		pkgs = []*packages.Package{loose}
	} else if loadErr != nil {
		return nil, nil, fmt.Errorf("carregando %q: %w", target, loadErr)
	}

	// Ordem determinística: import path alfabético.
	sort.Slice(pkgs, func(i, j int) bool { return pkgs[i].PkgPath < pkgs[j].PkgPath })
	return fset, pkgs, nil
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
