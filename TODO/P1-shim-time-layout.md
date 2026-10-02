# `time.Format`/`Parse` com layout

- **Prioridade:** P1 · **Área:** shim
- **Depende de:** —

## Problema

O shim `time` cobre `Time`, `Duration`, timers e `ParseDuration`
(`docs/mapping-spec.md` § "Stdlib"), mas não o interpretador de layouts:
faltam `Time.Format`, `AppendFormat`, `Parse`/`ParseInLocation`,
`MarshalJSON`/`UnmarshalJSON`/`MarshalText` e as constantes de layout
(`RFC3339`...). `Parse` aparece no audit; `Format` não, e gera Dart inválido
(ver `P1-infra-metodos-de-shim.md`).

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo
| `shim-simbolo:time.parse` | 10 | 10 | 2 | `github.com/gabriel-vasile/mimetype/internal/magic` text.go:504:6: símbolo sem shim: time.parse |
```

```go
package main

import (
	"fmt"
	"time"
)

func main() {
	t := time.Unix(0, 0).UTC()
	fmt.Println(t.Format("2006-01-02"))
}
```

```text
$ go run .
1970-01-01
$ goast dump . -o dump.json && python -m g2d transpile dump.json -o out && (cd out && dart analyze)
  error - lib/repro.local/tfmt.dart:18:11 - The method 'format' isn't defined for the type 'Time'. - undefined_method
```

`docs/stdlib-coverage.md` conta `Format` em 30 pacotes do grafo e `Parse` em 17.

## Critério de pronto

- Porta de `time/format.go` (`nextStdChunk`, mesmos erros
  `*time.ParseError`); oráculo em `golib_dart/test/time_test.dart`; repro
  vira fixture.
- `python -m g2d shims`; audit regerado.

## Limite registrado (não é deste artefato)

`Local` = UTC (o Go com `TZ=UTC`); fuso real exige `LoadLocation` e tzdata.
Está em `docs/mapping-spec.md` § "Stdlib".
