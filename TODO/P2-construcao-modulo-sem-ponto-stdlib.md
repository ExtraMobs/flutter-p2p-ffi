# Módulo com path sem ponto (`module gonil`) é tratado como stdlib

- **Prioridade:** P2 · **Área:** construcao
- **Depende de:** —

## Problema

`is_std` (`g2d/graph.py:49`) decide "stdlib" pelo primeiro segmento do import
path sem ponto. Um módulo local legítimo como `module gonil` (permitido pelo Go
para o módulo principal) cai nessa regra; o filtro `pkg != "main"` de
`Concurrency.std` (`g2d/services/concurrency.py:280`) e de `dualio`
(`g2d/services/dualio.py:167`) só cobre o modo loose (pacote `main` sem
`go.mod`). Com isso `Concurrency.forced_sync` (`concurrency.py:283`, última
linha) marca toda função do pacote como "função da stdlib" de formato fixo,
síncrona, e qualquer uma que suspenda — inclusive o próprio `main` — é recusada
em `Functions.enter_color` (`g2d/services/functions.py:114`) com a mensagem
enganosa "chamado pelo shim". O mesmo `is_std` é usado em `imports.py:118`,
`ifacecross.py:127/197`, `model.py:179` e `anon.py:62`, então outros sintomas
são prováveis.

## Prova

`go.mod`: `module r4` / `go 1.24`

```go
package main

import "fmt"

func main() {
	done := make(chan bool)
	go func() { done <- true }()
	fmt.Println(<-done)
}
```

```text
$ go run main.go
true
$ (cd tools/goast && go run . dump <dir> -o <dir>/d.json)
$ python -m g2d transpile <dir>/d.json -o <dir>/out
r4: não suportado [async:contexto-sincrono]: main precisa ser síncrono (chamado pelo shim) mas espera outra goroutine em main.go:5:6
```

Trocando só o `go.mod` para `module example.com/r4`, transpila e
`dart run lib/example.com/r4.dart` imprime `true`. Sem `go.mod` (modo loose,
pacote `main`) também funciona.

## No corpus

Nenhum: os 1108 pacotes não-stdlib do grafo de `github.com/ipfs/kubo/cmd/ipfs`
têm ponto no primeiro segmento
(`go list -deps -f '{{if not .Standard}}{{.ImportPath}}{{end}}' ... | awk -F/ '$1 !~ /\./' | wc -l` → `0`).
Afeta só repros/fixtures locais.

## Critério de pronto

- "stdlib" vem do goast (`Standard` do `go list`/`packages`) ou de uma lista
  fixa dos pacotes da stdlib, não do formato do path; um módulo `module r4`
  transpila e roda como `example.com/r4`.
