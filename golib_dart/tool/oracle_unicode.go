// Command oracle_unicode varre 0..unicode.MaxRune e imprime, num formato
// compacto (faixas fechadas para os predicados booleanos, pares esparsos
// para as conversões de caixa), o resultado real do pacote `unicode` do Go
// instalado. test/unicode_tables_test.dart roda este comando e confere,
// runa a runa, contra o shim (golib_dart/lib/unicode.dart).
//
//	go run tool/oracle_unicode.go
package main

import (
	"bufio"
	"fmt"
	"os"
	"unicode"
)

func printRanges(w *bufio.Writer, name string, pred func(rune) bool) {
	fmt.Fprintf(w, "RANGES %s\n", name)
	start := rune(-1)
	for r := rune(0); r <= unicode.MaxRune+1; r++ {
		p := r <= unicode.MaxRune && pred(r)
		if p && start < 0 {
			start = r
		} else if !p && start >= 0 {
			fmt.Fprintf(w, "%d %d\n", start, r-1)
			start = -1
		}
	}
	fmt.Fprintln(w, "END")
}

func printPairs(w *bufio.Writer, name string, f func(rune) rune) {
	fmt.Fprintf(w, "PAIRS %s\n", name)
	for r := rune(0); r <= unicode.MaxRune; r++ {
		if v := f(r); v != r {
			fmt.Fprintf(w, "%d %d\n", r, v)
		}
	}
	fmt.Fprintln(w, "END")
}

func main() {
	w := bufio.NewWriter(os.Stdout)
	defer w.Flush()

	printRanges(w, "IsDigit", unicode.IsDigit)
	printRanges(w, "IsLetter", unicode.IsLetter)
	printRanges(w, "IsSpace", unicode.IsSpace)
	printRanges(w, "IsUpper", unicode.IsUpper)
	printRanges(w, "IsLower", unicode.IsLower)
	printRanges(w, "IsTitle", unicode.IsTitle)
	printRanges(w, "IsControl", unicode.IsControl)
	printRanges(w, "IsMark", unicode.IsMark)
	printRanges(w, "IsNumber", unicode.IsNumber)
	printRanges(w, "IsPunct", unicode.IsPunct)
	printRanges(w, "IsSymbol", unicode.IsSymbol)
	printRanges(w, "IsGraphic", unicode.IsGraphic)
	printRanges(w, "IsPrint", unicode.IsPrint)
	printRanges(w, "Greek", func(r rune) bool { return unicode.Is(unicode.Greek, r) })
	printRanges(w, "Soft_Dotted", func(r rune) bool { return unicode.Is(unicode.Soft_Dotted, r) })

	printPairs(w, "ToUpper", unicode.ToUpper)
	printPairs(w, "ToLower", unicode.ToLower)
	printPairs(w, "ToTitle", unicode.ToTitle)
	printPairs(w, "SimpleFold", unicode.SimpleFold)
}
