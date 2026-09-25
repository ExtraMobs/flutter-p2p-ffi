// Command goast despeja a AST tipada de pacotes Go em JSON normalizado.
//
// Uso:
//
//	goast dump <alvo> [-o out.json]
//
// <alvo> é um diretório de pacote Go ou um padrão de pacote (ex.: ./...).
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
)

func main() {
	if len(os.Args) < 2 || os.Args[1] != "dump" {
		fmt.Fprintf(os.Stderr, "uso: goast dump <alvo> [-o out.json]\n")
		os.Exit(2)
	}
	fs := flag.NewFlagSet("dump", flag.ExitOnError)
	out := fs.String("o", "", "arquivo de saída (stdout se omitido)")
	// flag para no primeiro posicional; reparsear o resto aceita
	// "dump <alvo> -o x" além de "dump -o x <alvo>".
	fs.Parse(os.Args[2:])
	target := fs.Arg(0)
	if fs.NArg() > 0 {
		fs.Parse(fs.Args()[1:])
	}
	if target == "" || fs.NArg() > 0 {
		fmt.Fprintf(os.Stderr, "uso: goast dump <alvo> [-o out.json]\n")
		os.Exit(2)
	}

	doc, err := Dump(target)
	if err != nil {
		fmt.Fprintf(os.Stderr, "goast: %v\n", err)
		os.Exit(1)
	}
	data, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "goast: %v\n", err)
		os.Exit(1)
	}
	data = append(data, '\n')

	if *out == "" {
		os.Stdout.Write(data)
		return
	}
	if err := os.WriteFile(*out, data, 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "goast: %v\n", err)
		os.Exit(1)
	}
}
