# M4: goroutines, canais, `select`

- **Prioridade:** P0 · **Área:** design
- **Depende de:** —

## Problema

Nada de concorrência é suportado; o kubo/boxo depende disso em quase todo pacote de rede.

## Prova

```go
package main

import "fmt"

func main() {
	ch := make(chan int)
	go func() { ch <- 42 }()
	fmt.Println(<-ch)
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: make de chan
```

Medido no grafo do kubo:

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

| código | ocorrências | pacotes | na fronteira | exemplo |
| `tipo:chan` | 200 | 92 | 11 | `github.com/cskr/pubsub` pubsub.go:28:1: tipo chan |
| `make:chan` | 81 | 57 | 7 | `github.com/cskr/pubsub` pubsub.go:43:16: make de chan |
| `stmt:GoStmt` | 9 | 8 | 0 | `go.opencensus.io/stats/view` worker.go:34:2: statement GoStmt |
| `stmt:SelectStmt` | 6 | 3 | 0 | `github.com/syndtr/goleveldb/leveldb` db_compaction.go:382:4: statement SelectStmt |
| `zero-value:chan` | 7 | 6 | 0 | `github.com/pion/turn/v4/internal/client` transaction.go:48:6: zero value de chan |
| `range:chan` | 2 | 2 | 1 | `github.com/ipfs/go-datastore/query` query_impl.go:84:2: range sobre chan |
| `operador-unario:<-` | 3 | 2 | 0 | `github.com/pion/srtp/v3` session_srtcp.go:98:16: operador unário <- |
```

## Critério de pronto

- Desenho (`Chan<T>`, scheduler sobre async/Streams, `select`, `sync`) registrado no `mapping-spec.md`; fixtures e2e.

## Notas

Artefato guarda-chuva: quebrar em artefatos menores ao começar o M4.

## Notas do shim `sync` (já existe, sem goroutines)

`golib_dart/lib/sync.dart` implementa `Mutex`, `RWMutex`, `Once`, `WaitGroup`, `Pool`, `Map`, `Cond` e
`OnceFunc`/`OnceValue(s)` para uma goroutine só: esperas que só outra goroutine resolveria são o
deadlock do Go (`go.fatal`). Com goroutines, `Lock`/`Wait`/`Cond.Wait` precisam suspender (async) em vez
de encerrar, e `WaitGroup.Go` (ausente hoje) passa a existir.

## Runtime (feito)

A parte de `golib_dart` está pronta e testada (VM, JS e Wasm); falta só o lado do g2d (análise de cor
e emissão de `go`/`chan`/`<-`/`select`/`range` sobre canal — nenhuma mudança em `g2d/` neste commit).
Detalhe completo em `docs/mapping-spec.md` § "Concorrência (M4) — runtime". Resumo:

- **`go.Chan<T>`** (`golib_dart/lib/src/runtime/chan.dart`): `make`/`send`/`recv`/`recv2`/`close`,
  FIFO de remetentes e receptores (sem buffer = entrega direta, com buffer = fila), canal nil bloqueia
  pra sempre, panics com as mensagens exatas do Go (`send on closed channel`, `close of closed
  channel`, `close of nil channel`, `makechan: size out of range`, conferidas com `go run`).
- **`go.select`/`go.selectNow`** (`select.dart`): `SelectCase`/`SendCase<T>`/`RecvCase<T>`; escolha
  uniforme pseudoaleatória entre prontos, como o Go; canal nil nunca fica pronto.
- **`go.spawn`/deadlock** (`sched.dart`): `go f()` sempre agenda (nunca roda síncrono); contadores de
  goroutines vivas/bloqueadas + `holdEvents`/`releaseEvents` (fontes de evento externo, pra outros
  shims como `time.Sleep` usarem depois) detectam `fatal error: all goroutines are asleep -
  deadlock!` (código 2, igual ao Go) depois que as microtasks assentam.
- **`go.runMain`** (`defer.dart`): aceita `main` assíncrono; ao terminar, descarrega stdout/stderr e
  encerra NA HORA (código 0/2), mesmo com goroutines/timers pendentes, como o Go ao retornar de
  `main`. Resolvido de caminho: bug de truncamento do `exit()` (VM e Node, sem esperar I/O pendente)
  e um gap do `dart2js` sob Node (precisa do global `self`, que o Node não define, pro primeiro
  `await` de QUALQUER programa gerado — nem precisa de goroutine).
- **`Defers.runAsync`**: como `run()`, mas aguardando defer que devolve `Future`; o quadro que
  `recover()` consulta passou de pilha global pra `Zone` por chamada (goroutines intercaladas através
  de um `await` no meio de um defer quebrariam a pilha global — `defer_async_test.dart` prova).
- **`sync` `$async`** (`lock$async`, `rLock$async`, `wait$async`, `do$async`, `WaitGroup.go`):
  suspendem de verdade em vez de `fatal`; RWMutex com preferência de escritor. Síncrono continua
  valendo pra uma goroutine só; travado com outras vivas é limite do g2d (`fatal` `g2d: ...`).

Testes: `golib_dart/test/{chan,select,sync_async,defer_async}_test.dart` (unitários) e
`golib_dart/test/fixtures/{deadlock_recv,panic_goroutine,immediate_exit}.dart` (subprocesso, VM/JS/Wasm,
conferidos com `go run`). Golden do g2d (`defers`, `deferbuiltin`, `defernamed`, `syncshim`,
`syncatomic`, `hello`) continuam idênticos em VM/JS/Wasm.

