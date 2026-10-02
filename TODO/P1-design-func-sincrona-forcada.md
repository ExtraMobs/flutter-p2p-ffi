# Classes de func forçadas síncronas (`func()` por causa do `context.CancelFunc`)

- **Prioridade:** P1 · **Área:** design (decisão D7 do `TODO/README.md`)
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

## Decisão pendente

1. **Separar a classe de um tipo nomeado da stdlib (`context.CancelFunc`) da
   classe da assinatura subjacente (recomendado).** A `CancelFunc` continua
   síncrona; quando ela vira valor de `func()` comum, o g2d embrulha
   (`go.async0(cancel)`), e só o sentido contrário (closure async virando
   `CancelFunc`) é recusado. Mudança só na análise de cor; o shim fica como
   está.
2. **O shim aceitar e devolver `FutureOr<...> Function()`** e o g2d embrulhar
   na fronteira de cada shim. Mais geral (vale para outros callbacks), mas
   toca todos os shims que recebem ou devolvem funções.
