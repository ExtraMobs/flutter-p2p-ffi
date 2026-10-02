package main

import (
	"bufio"
	"fmt"
	"unicode"
)

// deltaOf lê os 3 deltas de uma unicode.CaseRange (Delta é o array não
// exportado `d [MaxCase]rune`; indexar por fora do pacote unicode funciona
// mesmo sem poder nomear o tipo).
func deltaOf(cr unicode.CaseRange) [3]int32 {
	return [3]int32{
		int32(cr.Delta[unicode.UpperCase]),
		int32(cr.Delta[unicode.LowerCase]),
		int32(cr.Delta[unicode.TitleCase]),
	}
}

// printCase emite `_caseRanges` (usada por to()/toUpper/toLower/toTitle) e
// `caseRanges` (unicode.CaseRanges, público), mais `_foldPairs`: o ciclo
// completo de SimpleFold, obtido chamando a função real do Go para toda
// runa 0..MaxRune — não precisa dos `asciiFold`/`caseOrbit` internos (não
// exportados) para ser fiel, porque already é a mesma função tabulada.
func printCase(w *bufio.Writer) {
	fmt.Fprint(w, "// unicode.CaseRanges: usada por to()/toUpper()/toLower()/toTitle().\n")
	fmt.Fprint(w, "final List<CaseRange> _caseRanges = [\n")
	for _, cr := range unicode.CaseRanges {
		d := deltaOf(cr)
		fmt.Fprintf(w, "  CaseRange(lo: Golang.Uint32(0x%06x), hi: Golang.Uint32(0x%06x), delta: [%d, %d, %d]),\n",
			cr.Lo, cr.Hi, d[0], d[1], d[2])
	}
	fmt.Fprint(w, "];\n\n")
	fmt.Fprint(w, "/// `unicode.CaseRanges`.\n")
	fmt.Fprint(w, "final Slice<CaseRange> caseRanges = Slice.of(_caseRanges, _caseRangeElem);\n\n")

	fmt.Fprint(w, "// Ciclo completo de unicode.SimpleFold: pares (r, SimpleFold(r)) para\n")
	fmt.Fprint(w, "// toda runa onde SimpleFold(r) != r, em ordem crescente de r.\n")
	fmt.Fprint(w, "final List<(int, int)> _foldPairs = [\n")
	for r := rune(0); r <= unicode.MaxRune; r++ {
		if f := unicode.SimpleFold(r); f != r {
			fmt.Fprintf(w, "  (0x%06x, 0x%06x),\n", r, f)
		}
	}
	fmt.Fprint(w, "];\n")
}
