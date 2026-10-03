# Cor de valor func por classe: closure vira `async` só por chamar um campo `func()`

- **Prioridade:** P1 · **Área:** design
- **Depende de:** —

## Problema

A decisão D7 (2026-10-02) separou os tipos de função nomeados da stdlib
(`context.CancelFunc`) da classe `func()` e soltou as outras amarras da
`func()` (métodos de tipos genéricos, `sync.OnceFunc`, pacotes sem shim).
Agora a `func()` é `async` no grafo do kubo, e toda chamada por valor dela
espera. Uma closure que só chama um campo `func()` que guarda um
`CancelFunc` (síncrono de fato) vira `async`, e não pode mais ser devolvida
como `CancelFunc`: `async:valor-func`. A cor é por classe de assinatura,
não por campo.

## Prova

```go
// go.uber.org/fx/internal/fxclock/clock.go
type deadlineCtx struct {
	cancelInner func()   // recebe o CancelFunc de context.WithCancel
	...
}

func (c *deadlineCtx) cancel(err error) {
	c.mu.Lock()
	if c.err == nil {
		...
		c.cancelInner()  // chamada por valor da classe func(), agora async
	}
	c.mu.Unlock()
}

func (c *Mock) WithTimeout(...) (context.Context, context.CancelFunc) {
	...
	return ctx, func() { dctx.cancel(context.Canceled) }  // clock.go:142
}
```

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo
| `async:valor-func` | 67 | 48 | 2 | `go.uber.org/fx/internal/fxclock` clock.go:142:14: função que suspende usada como valor de uma assinatura que precisa ficar síncrona |
```

`fxclock` era verde antes do D7 (o `grpc/internal/idle`, exemplo do artefato
antigo, ficou verde no lugar dele).

## Proposta

Classe própria para campo não exportado de tipo func (todas as escritas
estão no pacote): `("field", pacote, tipo, campo)`, ligada à classe da
assinatura só quando o campo é lido sem ser chamado ou recebe um valor
`func()` comum; escrita de `CancelFunc` ou de função citada direto só
acrescenta a cor dela. O tipo Dart do campo passa a vir da classe dele
(declaração, construtor, `$copy`, literal composto, seletor).

## Critério de pronto

- `fxclock` volta a verde; fixture com campo `func()` guardando
  `CancelFunc` e devolvido numa closure como `CancelFunc`; e2e em VM × JS ×
  Wasm; audit regerado sem perder verde.
