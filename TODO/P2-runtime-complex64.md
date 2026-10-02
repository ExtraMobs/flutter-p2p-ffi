# Multiplicação de `complex64` arredonda a cada termo

- **Prioridade:** P2 · **Área:** runtime
- **Depende de:** —

## Problema

O gc multiplica `complex64` em float64 e arredonda uma vez; `Complex64.operator *`
(`golib_dart/lib/fixed_types/golang/complex64.dart`) arredonda cada termo em float32.

## Prova

```go
package main

import "fmt"

func main() {
	a := float32(1) + float32(1)/4096
	x := complex(a, 1)
	fmt.Println(x * x)
	big := complex(float32(3e38), float32(3e38))
	fmt.Println(big * big)
}
```

```text
go run:   (0.00048834085+2.0004883i) / (0+Infi)
dart run: (0.00048828125+2.0004883i) / (NaN+Infi)      (VM e JS)
```

## Critério de pronto

- `*` (e `/`) de `complex64` calculados em float64 e arredondados uma vez; oráculo Go.
