# Campo/método com o nome de um tipo não exportado sombreia a classe

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Tipo não exportado `t` vira a classe `_t`, e campo/método não exportado `t` vira o membro `_t`. Dentro
da classe, o membro sombreia a classe: Dart inválido em silêncio. O caso comum é embutir uma struct
não exportada (`type mac struct{ macGeneric }`: o campo embutido tem o nome do tipo), mas vale para
qualquer campo ou método com o nome de um tipo não exportado do pacote.

## Prova

```go
package main

import "fmt"

type macGeneric struct{ n int }

func (h *macGeneric) Write(p []byte) int { h.n += len(p); return h.n }

type mac struct{ macGeneric }

func main() {
	var m mac
	m.Write([]byte("abc"))
	fmt.Println(m.Write([]byte("de")), m.n)
}
```

```text
$ go run main.go
5 5

$ goast dump <dir> -o dump.json && python -m g2d transpile dump.json -o out && dart analyze out/lib/main.dart
  error - main.dart:48:9 - Undefined class '_macGeneric'. ... - undefined_class
  error - main.dart:48:65 - The instance member '_macGeneric' can't be accessed in an initializer. ... - implicit_this_reference_in_initializer
  error - main.dart:53:3 - Undefined class '_macGeneric'. ... - undefined_class
```

No grafo do kubo (`docs/audit.md`): `golang.org/x/crypto/internal/poly1305` fica `dart-invalido`
(`dart:undefined_class`×8, `dart:implicit_this_reference_in_initializer`×3), com todas as dependências
verdes.

## Critério de pronto

- Nomes Dart de tipos não exportados e de membros não exportados em espaços disjuntos (ex.: tipo
  `_T$macGeneric`, ou membro com sufixo quando coincide com um tipo do pacote), regra em `naming.py`
  e em `docs/mapping-spec.md` (Identificadores); conferir junto com
  `P1-design-tipos-nao-exportados-entre-libraries.md`, que mexe nos mesmos nomes.
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; goldens regerados.
