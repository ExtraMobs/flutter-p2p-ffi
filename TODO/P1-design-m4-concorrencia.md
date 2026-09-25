# M4: goroutines, canais, `select`

- **Prioridade:** P1 · **Área:** design
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

## Critério de pronto

- Desenho (`Chan<T>`, scheduler sobre async/Streams, `select`, `sync`) registrado no `mapping-spec.md`; fixtures e2e.

## Notas

Artefato guarda-chuva: quebrar em artefatos menores ao começar o M4.
