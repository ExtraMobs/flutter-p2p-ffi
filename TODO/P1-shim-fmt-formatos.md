# `fmt` formata errado alguns tipos e verbos

- **Prioridade:** P1 · **Área:** shim
- **Depende de:** —

## Problema

Divergências de formatação no shim `fmt`, todas sem `Unsupported`:

- `Sprint`/`Print` põem espaço entre operandos de tipo nomeado sobre string (`fmt.dart` testa
  `is! Golang.String` em vez de `StringBase`);
- nil aninhado com verbo diferente de `v` (`%d`, `%s`, `%x`) sai `%!d(<nil>)` em vez de `<nil>`/`0`;
- `&array`, `&slice` e `&map` no nível de topo saem sem o `&` (ou como endereço);
- slice de tipo nomeado sobre `byte` com `%s`/`%x`/`%q` é tratado como slice comum (o Go olha o Kind);
- `%x`/`%b` em float dentro de struct/slice lança `UnimplementedError` em runtime: o
  `g2d/behaviors/fmtcheck.py` só recusa esses verbos no nível de topo.

## Prova

```go
package main

import "fmt"

type S string

type Code byte

type W struct {
	P *int
	I interface{}
}

func main() {
	fmt.Println(fmt.Sprint(S("a"), 1, S("b"), 2))
	fmt.Printf("%d\n", W{})
	a := [2]int{1, 2}
	s := []string{"x"}
	fmt.Println(&a, &s)
	cs := []Code{65, 66}
	fmt.Printf("%s|%x|%q\n", cs, cs, cs)
}
```

```text
go run:
a1b2
{0 <nil>}
&[1 2] &[x]
AB|4142|"AB"
dart run:
a 1 b 2
{%!d(<nil>) %!d(<nil>)}
[1 2] 0xc0...
[%!s(main.Code=65) %!s(main.Code=66)]|[41 42]|['A' 'B']
```

E `fmt.Printf("%x\n", []float64{1.5})`: Go `[0x1.8p+00]`, Dart `UnimplementedError: fmt: %x de float`.

## Critério de pronto

- Cada item com oráculo Go; `fmtcheck` recusa `%x`/`%b` de float também aninhado (ou o shim
  implementa).
- Fixture e2e com o repro.
