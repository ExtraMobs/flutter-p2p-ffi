# Contagem de shift constante grande sai crua no Dart

- **Prioridade:** P2 · **Área:** construcao
- **Depende de:** —

## Problema

`shift_count` em `g2d/services/operands.py` devolve o valor constante sem normalizar: contagem
float no goast (`1e6` vira `1e+06`) ou acima de int64 gera Dart inválido. `to_int` faz o mesmo com
índice constante enorme, e a mensagem de panic difere entre VM e JS.

## Prova

```go
package main

import "fmt"

func main() {
	var x uint64 = 3
	fmt.Println(x<<1e6, x>>1e6)
	var y uint32 = 3
	fmt.Println(y<<(1<<64-1), y>>(1<<63))
}
```

```text
go run: 0 0 / 0 0
dart analyze:
  error - argument_type_not_assignable ('double')         (x << 1e+06)
  error - integer_literal_out_of_range                     (18446744073709551615)
```

## Critério de pronto

- Contagem constante ≥ 64 vira 64 (resultado igual) e sempre inteira.
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
