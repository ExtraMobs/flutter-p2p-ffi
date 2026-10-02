package main

import (
	"bufio"
	"fmt"
	"unicode"
)

// printScripts emite `greek` (o único script que o grafo do kubo usa hoje,
// docs/stdlib-coverage.md) como var de nível de pacote, e o mapa `scripts`
// com todos os scripts do Go (unicode.Scripts["Han"]...), para o caso de um
// pacote futuro precisar de outro por nome. Os scripts não viram vars
// individuais: são ~160, e nenhum além de Greek está em uso — evita nomes
// Dart nunca conferidos por um caso real.
func printScripts(w *bufio.Writer) {
	fmt.Fprint(w, "// unicode.Scripts: só Greek (o único script usado pelo grafo do kubo,\n")
	fmt.Fprint(w, "// docs/stdlib-coverage.md) tem var própria; os demais só no mapa `scripts`\n")
	fmt.Fprint(w, "// (unicode.Scripts no Go), por nome.\n")
	printRangeTable(w, dartName("Greek"), unicode.Scripts["Greek"])

	keys := sortedKeys(unicode.Scripts)
	fmt.Fprint(w, "final Map<String, RangeTable> scripts = {\n")
	for _, k := range keys {
		fmt.Fprintf(w, "  '%s': ", k)
		if k == "Greek" {
			fmt.Fprint(w, "greek")
		} else {
			rangeTableCtor(w, unicode.Scripts[k])
		}
		fmt.Fprint(w, ",\n")
	}
	fmt.Fprint(w, "};\n\n")
}
