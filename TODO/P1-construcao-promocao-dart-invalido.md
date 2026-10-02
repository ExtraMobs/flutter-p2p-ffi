# Promoção por embedding que gera Dart inválido

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Dois casos em `g2d/services/promotion.py`:

- struct que embute tipo nomeado **não-struct** com método de receptor ponteiro (`type Counter
  int; func (c *Counter) Inc()`): o mixin da struct externa repassa `inc()` para um getter que não
  tem o método (a condição `struct or not m["ptr"]` em `declare`). Basta declarar a struct;
- tipo **local** que embute outro: o mixin usa o nome Go cru (`mixin Q$Promote { Q? get $Q; }`),
  mas a classe içada é `$_main$Q`. Dois tipos locais de mesmo nome em funções diferentes colidiriam.

## Prova

```go
package main

import "fmt"

type Counter int

func (c *Counter) Inc() { *c++ }

type Holder struct{ Counter }

type P struct{ X int }

func (p P) Get() int { return p.X }

func main() {
	h := Holder{}
	h.Counter.Inc()
	type Q struct{ P }
	fmt.Println(h, Q{P{1}}.Get())
}
```

```text
go run: {1} 1
dart analyze:
  error - The method 'inc' isn't defined for the type 'Holder'
  error - Undefined class 'Q'
```

## Critério de pronto

- Os dois casos emitem Dart válido e igual ao Go.
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` § embedding atualizado (hoje só marca ⚠️ o `Counter$Promote`).
