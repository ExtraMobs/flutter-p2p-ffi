# Método não exportado sombreia nome de pacote igual

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Em Go, `sub` (constante do pacote) e o método `(*T).sub` convivem: dentro do método, `sub` é a
constante. No Dart os dois viram `_sub`, e o membro da classe sombreia o top-level: o corpo passa o
método onde o Go passava a constante. Dart inválido (`dart-invalido` no audit), sem `Unsupported`.

## Prova

```go
package main

import "fmt"

type op int

const sub op = 1

type T struct{}

func (t *T) sub(o op) op { return o + 1 }

func (t *T) Sub() op { return t.sub(sub) }

func main() { fmt.Println((&T{}).Sub()) }
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json -o out && (cd out && dart analyze)
  error - lib/shadow.dart:57:31 - The argument type '$_op Function($_op)' can't be assigned to the parameter type '$_op'.  - argument_type_not_assignable
```

Reconferido em 2026-10-02. No grafo do kubo o caso que motivou o artefato
(`github.com/cskr/pubsub`) está verde hoje e o audit mostra 0 `dart-invalido`,
mas o g2d continua emitindo Dart inválido sem `Unsupported` para o repro.

## Critério de pronto

- Referência a nome de pacote dentro de classe que tem membro de mesmo nome Dart sai qualificada
  (ex. prefixo da própria library) ou um dos nomes é renomeado; fixture com o repro.
