# `fmt.Printf` / `Sprintf` / `Errorf` (verbos de formatação)

- **Prioridade:** P1 · **Área:** shim
- **Depende de:** —

## Problema

O shim `fmt` só tem `Println`/`Print`/`Sprint`; o g2d emite chamadas a funções inexistentes (Dart inválido em silêncio, sem `Unsupported`).

## Prova

```go
package main

import "fmt"

func main() {
	fmt.Printf("%d-%s\n", 7, "x")
	s := fmt.Sprintf("%v", []int{1})
	err := fmt.Errorf("falhou: %w", nil)
	fmt.Println(s, err)
}
```

```text
$ dart analyze
error - main.dart:13:9 - The function 'printf' isn't defined.
error - main.dart:17:27 - The function 'sprintf' isn't defined.
error - main.dart:23:27 - The function 'errorf' isn't defined.
$ go run main.go
7-x
[1] falhou: %!w(<nil>)
```

Medido no grafo do kubo:

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

| código | ocorrências | pacotes | na fronteira | exemplo |
| `dart:undefined_function` | 33 | 9 | 9 | `github.com/klauspost/compress` 49:34: error: The function 'pow' isn't defined. |
```

Os `dart:undefined_function` de `sprintf`/`errorf` do audit (rtcerr, digerror, grpclog, otlptrace...) são este artefato; ver `P1-shim-math-completo` para a correção comum (símbolo de shim inexistente → Unsupported).

## Critério de pronto

- Verbos do `fmt` com oráculo Go (incl. `%w`, `%!verbo(...)`, largura/precisão); e2e VM × JS × Wasm.
- O g2d passa a recusar símbolo stdlib sem shim (em vez de emitir chamada inexistente).
