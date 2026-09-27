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

## Notas do shim `io`: `io.Pipe`

`golib_dart/lib/io.dart` porta o resto de `io.go`/`multi.go` (interfaces, `ReadFull`/`ReadAll`/`Copy*`,
`LimitedReader`, `SectionReader`, `OffsetWriter`, `MultiReader`/`MultiWriter`, `TeeReader`, `Discard`,
`NopCloser`; ver `docs/mapping-spec.md`), mas `Pipe`/`PipeReader`/`PipeWriter` ficam de fora: no Go,
`Write` bloqueia até um `Read` correspondente consumir os mesmos bytes (e vice-versa) — é
`sync`/goroutines puros (`pipe.go` usa só um canal e um `sync.Once`, sem I/O de verdade). Sem goroutines
suspendendo (M4), um `Write` sem leitor pronto teria que devolver na hora (errado) ou travar para sempre
(o "deadlock" do `sync`, mas aqui numa operação que o Go corpus espera que complete depois que a outra
goroutine agir). Com goroutines: `Write`/`Read` suspendem (`async`) até parear com a outra ponta, do
mesmo jeito que `Chan<T>` sem buffer; `CloseWithError` acorda quem estiver esperando com o erro.

