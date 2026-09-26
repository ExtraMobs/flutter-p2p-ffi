// Command goast despeja a AST tipada de pacotes Go em JSON normalizado.
//
// Uso:
//
//	goast dump [-C dir] [-o out.json | -outdir dir] <alvo>...
//
// <alvo> é um diretório de pacote Go, um padrão de pacote (ex.: ./...) ou
// @arquivo com um alvo por linha (a linha de comando do Windows é curta
// para o grafo inteiro). Com -C, os alvos são resolvidos no módulo de dir.
// Com -outdir, cada pacote vira um documento próprio em
// <dir>/<import path>.json.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const usage = "uso: goast dump [-C dir] [-o out.json | -outdir dir] <alvo>...\n"

func main() {
	if len(os.Args) < 2 || os.Args[1] != "dump" {
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}
	fs := flag.NewFlagSet("dump", flag.ExitOnError)
	out := fs.String("o", "", "arquivo de saída (stdout se omitido)")
	outDir := fs.String("outdir", "", "um JSON por pacote em <outdir>/<import path>.json")
	dir := fs.String("C", "", "diretório do módulo onde os alvos são resolvidos")
	// flag para no primeiro posicional; reparsear o resto aceita flags
	// depois dos alvos ("dump <alvo> -o x") além de antes.
	var targets []string
	for args := os.Args[2:]; ; args = fs.Args()[1:] {
		fs.Parse(args)
		if fs.NArg() == 0 {
			break
		}
		targets = append(targets, fs.Arg(0))
	}
	targets, err := expandTargets(targets)
	if err != nil {
		fail(err)
	}
	if len(targets) == 0 || (*out != "" && *outDir != "") {
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}

	doc, err := Dump(*dir, targets...)
	if err != nil {
		fail(err)
	}
	if *outDir == "" {
		writeDoc(*out, doc)
		return
	}
	for _, p := range doc.Packages {
		one := *doc
		one.Packages = []*PackageDump{p}
		path := filepath.Join(*outDir, filepath.FromSlash(p.Path)+".json")
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			fail(err)
		}
		writeDoc(path, &one)
	}
}

// expandTargets troca cada @arquivo pelas linhas não vazias do arquivo.
func expandTargets(targets []string) ([]string, error) {
	var out []string
	for _, t := range targets {
		if !strings.HasPrefix(t, "@") {
			out = append(out, t)
			continue
		}
		data, err := os.ReadFile(t[1:])
		if err != nil {
			return nil, err
		}
		for _, line := range strings.Split(string(data), "\n") {
			if line = strings.TrimSpace(line); line != "" {
				out = append(out, line)
			}
		}
	}
	return out, nil
}

func writeDoc(path string, doc *DumpDoc) {
	data, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		fail(err)
	}
	data = append(data, '\n')
	if path == "" {
		os.Stdout.Write(data)
		return
	}
	if err := os.WriteFile(path, data, 0o644); err != nil {
		fail(err)
	}
}

func fail(err error) {
	fmt.Fprintf(os.Stderr, "goast: %v\n", err)
	os.Exit(1)
}
