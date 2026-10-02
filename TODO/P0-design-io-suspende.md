# I/O que suspende atrás de interface da stdlib (`io.Reader`, `net.Conn`)

- **Prioridade:** P0 · **Área:** design (decisão D2 do `TODO/README.md`)
- **Depende de:** —

## Problema

Pela cor transitiva do M4, todo método no grupo de uma interface da stdlib
(`io.Reader`, `io.Writer`, `fmt.Stringer`, `sort.Interface`...) precisa ficar
síncrono, porque o shim o chama de forma síncrona. Um `Read` que espera outra
goroutine (canal, `Cond`, `Mutex` disputado) é recusado com
`async:contexto-sincrono`. Isso é exatamente o formato de I/O de rede e de
pipes, então o `net`, o `io.Pipe` e boa parte do libp2p ficam bloqueados por
este ponto, não só por falta de shim.

## Prova

```go
package main

import (
	"fmt"
	"io"
)

type chanReader struct{ ch chan []byte }

func (r *chanReader) Read(p []byte) (int, error) {
	b, ok := <-r.ch
	if !ok {
		return 0, io.EOF
	}
	return copy(p, b), nil
}

func main() {
	r := &chanReader{ch: make(chan []byte)}
	go func() {
		r.ch <- []byte("oi")
		close(r.ch)
	}()
	b, _ := io.ReadAll(r)
	fmt.Println(string(b))
}
```

```text
$ go run .
oi
$ goast dump . -o dump.json && python -m g2d transpile dump.json -o out
ioasync: não suportado [async:contexto-sincrono]: Read precisa ser síncrono (chamado pelo shim) mas espera outra goroutine em main.go:10:6
```

No grafo do kubo (`docs/audit.md`):

```text
| `async:contexto-sincrono` | 98 | 62 | 5 | `github.com/pion/transport/v3/packetio` buffer.go:188:6: Read precisa ser síncrono (chamado pelo shim) mas espera outra goroutine |
```

Na fronteira: `pion/transport/v3/packetio`, `benbjohnson/clock`,
`filecoin-project/go-clock`, `klauspost/compress/s2`, `multiformats/go-multistream`.

## Decisão pendente

1. **Interfaces de I/O do shim entram na cor como interface comum
   (recomendado).** `io.Reader`/`Writer`/`Closer`/`ReaderFrom`/`WriterTo` e as
   de `net` ficam `async` quando alguma implementação no grafo suspende (a
   cor já faz isso para interfaces geradas). Os shims que chamam esses
   métodos (`io.Copy`, `io.ReadAll`, `bufio`, `fmt.Fprint*`) ganham uma
   versão `$async`, como já existe no `sync` (`lock$async`), e o g2d escolhe
   a versão pela cor do argumento. Custo: duas versões de cada função de I/O
   no shim; `String()`/`Error()`/`Less` continuam síncronos.
2. **Tudo de I/O sempre `async`.** Mais simples no g2d, mas colore quase todo
   o grafo (qualquer `Write` num `bytes.Buffer` passaria a esperar), o que
   contraria a decisão do M4 de só colorir quem suspende.
3. **Manter como está.** I/O real só funcionaria por callbacks; `net` e
   `io.Pipe` seguem bloqueados.

## Critério de pronto

- Repro acima vira fixture; e2e idêntico em VM × JS × Wasm.
- `docs/mapping-spec.md` § "Cor transitiva" atualizado; audit regerado sem
  perder verde.
