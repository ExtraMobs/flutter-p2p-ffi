// Command gen_unicode gera lib/src/unicode/tables.g.dart a partir do pacote
// `unicode` do Go instalado: Categories, Properties e os aliases exportados
// (`Letter`=`L`, `Upper`=`Lu`, `Digit`=`Nd`...), mais Scripts (só o mapa e
// `Greek`, usado pelo grafo), CaseRanges e o ciclo de SimpleFold — estes
// dois em gen_unicode_case.go. Nenhum arquivo é `part` do gerador: os três
// escrevem para o mesmo stdout, concatenados pelo pipeline de geração.
//
//	go run tool/gen_unicode.go tool/gen_unicode_scripts.go tool/gen_unicode_case.go \
//	  | dart format > lib/src/unicode/tables.g.dart
//
// O teste test/unicode_tables_test.dart roda esse comando de novo e compara
// com o arquivo no repo (como test/isprint_test.dart faz para IsPrint), e
// também varre 0..0x10FFFF comparando os predicados/conversões do shim com
// o oráculo Go.
package main

import (
	"bufio"
	"fmt"
	"os"
	"sort"
	"unicode"
)

// dartName é o `lower_camel` de g2d/services/naming.py: primeira "palavra"
// (sigla incluída) em minúsculas — mesma regra usada para nomear, em Dart,
// os símbolos exportados de outro pacote (aqui, os do `unicode`). Mantido
// em sincronia manual com o Python; qualquer nome gerado que a máquina de
// import do g2d rejeitar (`shim-simbolo`) é sinal de que os dois divergiram.
func dartName(name string) string {
	run := 0
	for run < len(name) && isUpperASCII(name[run]) {
		run++
	}
	if run == 0 {
		return name
	}
	var cut int
	if run == len(name) || !isLowerASCII(name[run]) || run == 1 {
		cut = run
	} else {
		cut = run - 1
	}
	return lowerASCII(name[:cut]) + name[cut:]
}

func isUpperASCII(b byte) bool { return b >= 'A' && b <= 'Z' }
func isLowerASCII(b byte) bool { return b >= 'a' && b <= 'z' }
func lowerASCII(s string) string {
	b := []byte(s)
	for i, c := range b {
		if c >= 'A' && c <= 'Z' {
			b[i] = c + ('a' - 'A')
		}
	}
	return string(b)
}

// sortedKeys ordena as chaves de um map[string]*unicode.RangeTable (ordem
// determinística de saída, exigida pelo pipeline: travessia em ordem fixa).
func sortedKeys(m map[string]*unicode.RangeTable) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

// rangeTableCtor escreve a expressão `RangeTable(r16: ..., r32: ...,
// latinOffset: ...)` (sem `final`/nome/`;`): reusada tanto para os vars de
// nível de pacote (Categories, Properties) quanto para os valores inline do
// mapa `scripts`.
func rangeTableCtor(w *bufio.Writer, rt *unicode.RangeTable) {
	fmt.Fprint(w, "RangeTable(\n")
	if len(rt.R16) > 0 {
		fmt.Fprint(w, "  r16: Slice.of([\n")
		for _, r := range rt.R16 {
			fmt.Fprintf(w, "    Range16(lo: Golang.Uint16(0x%04x), hi: Golang.Uint16(0x%04x), stride: Golang.Uint16(%d)),\n",
				r.Lo, r.Hi, r.Stride)
		}
		fmt.Fprint(w, "  ], _range16Elem),\n")
	}
	if len(rt.R32) > 0 {
		fmt.Fprint(w, "  r32: Slice.of([\n")
		for _, r := range rt.R32 {
			fmt.Fprintf(w, "    Range32(lo: Golang.Uint32(0x%06x), hi: Golang.Uint32(0x%06x), stride: Golang.Uint32(%d)),\n",
				r.Lo, r.Hi, r.Stride)
		}
		fmt.Fprint(w, "  ], _range32Elem),\n")
	}
	if rt.LatinOffset != 0 {
		fmt.Fprintf(w, "  latinOffset: Golang.Int(%d),\n", rt.LatinOffset)
	}
	fmt.Fprint(w, ")")
}

func printRangeTable(w *bufio.Writer, dartVar string, rt *unicode.RangeTable) {
	fmt.Fprintf(w, "final RangeTable %s = ", dartVar)
	rangeTableCtor(w, rt)
	fmt.Fprint(w, ";\n\n")
}

// printAliases emite `final RangeTable alias = canonical;` para cada par
// (nome Go do alias, nome Go do valor canônico já emitido).
func printAliases(w *bufio.Writer, pairs [][2]string) {
	for _, p := range pairs {
		fmt.Fprintf(w, "final RangeTable %s = %s;\n", dartName(p[0]), dartName(p[1]))
	}
	fmt.Fprint(w, "\n")
}

func printCategories(w *bufio.Writer) {
	fmt.Fprint(w, "// unicode.Categories: as 29 categorias de 2 letras e as 7 combinadas\n")
	fmt.Fprint(w, "// (C, L, M, N, P, S, Z), todas na própria unicode.Categories do Go, mais\n")
	fmt.Fprint(w, "// os aliases legíveis (Letter=L, Upper=Lu...).\n")
	keys := sortedKeys(unicode.Categories)
	for _, k := range keys {
		printRangeTable(w, dartName(k), unicode.Categories[k])
	}
	aliases := [][2]string{
		{"Letter", "L"}, {"Upper", "Lu"}, {"Lower", "Ll"}, {"Title", "Lt"},
		{"Mark", "M"}, {"Number", "N"}, {"Digit", "Nd"}, {"Punct", "P"},
		{"Symbol", "S"}, {"Space", "Z"}, {"Other", "C"},
	}
	printAliases(w, aliases)
}

func printProperties(w *bufio.Writer) {
	fmt.Fprint(w, "// unicode.Properties: as propriedades do PropList.txt usadas pelo Go\n")
	fmt.Fprint(w, "// (STerm já é a própria chave do mapa, alias de Sentence_Terminal, como no Go).\n")
	keys := sortedKeys(unicode.Properties)
	for _, k := range keys {
		printRangeTable(w, dartName(k), unicode.Properties[k])
	}
}

func main() {
	w := bufio.NewWriter(os.Stdout)
	defer w.Flush()
	fmt.Fprint(w, "// Gerado por\n")
	fmt.Fprint(w, "// `go run tool/gen_unicode.go tool/gen_unicode_scripts.go tool/gen_unicode_case.go\n")
	fmt.Fprint(w, "//   | dart format`: as tabelas do pacote `unicode` do Go\n")
	fmt.Fprintf(w, "// (Unicode %s). NÃO EDITE.\n", unicode.Version)
	fmt.Fprint(w, "\n")
	fmt.Fprint(w, "part of '../../unicode.dart';\n\n")
	fmt.Fprintf(w, "/// `unicode.Version`.\n")
	fmt.Fprintf(w, "const version = '%s';\n\n", unicode.Version)
	printCategories(w)
	printProperties(w)
	printScripts(w)
	printCase(w)
}
