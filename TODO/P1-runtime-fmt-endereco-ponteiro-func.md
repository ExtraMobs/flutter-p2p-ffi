# `%v` de ponteiro não-struct e de func imprime o `toString` do Dart

- **Prioridade:** P1 · **Área:** runtime
- **Depende de:** —

## Problema

O Go imprime um endereço em hexadecimal (`0xc00000a0a8`) para `%v`/`Println` de `*T` (T não-struct),
func e chan. O `_appendV` do shim cai no `toString` do Dart: saída de forma diferente, em silêncio.
O valor do endereço não é reproduzível nem no Go; a forma (`0x` + hex) é. Ponteiro para struct
aninhado já sai como endereço (`Addr`).

## Prova

```go
package main

import "fmt"

func main() {
	x := 5
	p := &x
	f := func() {}
	var np *int
	fmt.Println(p, np)
	fmt.Printf("%v\n", p)
	fmt.Println(f)
}
```

```text
$ go run main.go
0xc00000a0a8 <nil>
0xc00000a0a8
0x7ff7e78808e0

$ goast dump <dir> -o d.json && python -m g2d transpile d.json -o out && dart run out/lib/main.dart
Instance of 'Box<Int>' <nil>
Instance of 'Box<Int>'
Closure: () => void
```

## Critério de pronto

- `go.Ptr`, função e canal no `_appendV`/`_Printf` saem como `0x` + hex estável por objeto (como o
  `Addr` aninhado); ⚠️ no `mapping-spec` (valor não reproduzível). Teste de forma no golib (regex), já
  que o e2e não compara endereços.
