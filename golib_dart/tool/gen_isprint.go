// Command gen_isprint gera lib/src/unicode/isprint.dart: as faixas de runas
// para as quais unicode.IsPrint é verdade (o strconv.IsPrint tem a mesma
// definição). O teste test/isprint_test.dart confere que o arquivo está em
// dia com o Go instalado.
//
//	go run tool/gen_isprint.go | dart format > lib/src/unicode/isprint.dart
package main

import (
	"fmt"
	"unicode"
)

func main() {
	fmt.Printf("// Gerado por `go run tool/gen_isprint.go | dart format`: unicode.IsPrint\n")
	fmt.Printf("// do Go (Unicode %s). NÃO EDITE.\n\n", unicode.Version)
	fmt.Print(`/// ` + "`unicode.IsPrint`" + ` / ` + "`strconv.IsPrint`" + ` do Go: letras, marcas, números,
/// pontuação, símbolos e o espaço ASCII.
library;

bool isPrint(int r) {
  if (r < 0x80) return r >= 0x20 && r < 0x7f;
  var lo = 0, hi = _ranges.length ~/ 2 - 1;
  while (lo <= hi) {
    final m = (lo + hi) >> 1;
    if (r < _ranges[2 * m]) {
      hi = m - 1;
    } else if (r > _ranges[2 * m + 1]) {
      lo = m + 1;
    } else {
      return true;
    }
  }
  return false;
}

/// Faixas fechadas [início, fim] das runas imprimíveis acima do ASCII.
const _ranges = <int>[
`)
	start := -1
	for r := rune(0x80); r <= unicode.MaxRune+1; r++ {
		p := r <= unicode.MaxRune && unicode.IsPrint(r)
		if p && start < 0 {
			start = int(r)
		} else if !p && start >= 0 {
			fmt.Printf("  0x%04X, 0x%04X,\n", start, int(r)-1)
			start = -1
		}
	}
	fmt.Print("];\n")
}
