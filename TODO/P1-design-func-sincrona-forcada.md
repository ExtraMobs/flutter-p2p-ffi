# Classes de func forçadas síncronas (`func()` por causa do `context.CancelFunc`)

- **Prioridade:** P1 · **Área:** design
- **Depende de:** —

## Problema

A cor de valor func é por classe de assinatura (`docs/mapping-spec.md` § "Cor transitiva"). Uma
classe que aparece numa assinatura da stdlib fica síncrona, porque o shim recebe/devolve funções
síncronas. `context.WithCancel` devolve `CancelFunc` (`func()`), então a classe `func()` é síncrona
em quase todo o grafo do kubo, e qualquer closure `func()` que suspende e é guardada como valor é
recusada (`async:valor-func`), mesmo quando só passa por código gerado.

## Prova

```go
// google.golang.org/grpc/internal/idle/idle.go
var timeAfterFunc = func(d time.Duration, f func()) *time.Timer {
	return time.AfterFunc(d, f)
}
...
	m.timer = timeAfterFunc(d, m.handleIdleTimeout) // idle.go:95
```

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `async:valor-func` | 111 | 66 | 3 | `google.golang.org/grpc/internal/idle` idle.go:95:29: função que suspende usada como valor de uma assinatura que precisa ficar síncrona |
```

## Critério de pronto

- Valores async de `func()` (e das outras classes forçadas só por shim) deixam de ser recusados sem
  quebrar o formato Dart que o shim espera; fixture e2e; audit regerado sem perder verde.

## Notas

Caminhos possíveis: o shim tipar callbacks/resultados como `FutureOr<...> Function()` e o g2d
embrulhar na fronteira (`go.async0(cancel)` no resultado de `WithCancel`); ou separar a classe de um
tipo nomeado da stdlib (`context.CancelFunc`) da classe da assinatura subjacente, embrulhando a
conversão síncrono → async e recusando só o sentido contrário.
