# goast: padrão `dir/...` e `./...` quebram no Windows

- **Prioridade:** P0 · **Área:** infra
- **Depende de:** —

## Problema

`resolveTarget` faz `os.Stat("<dir>\\...")`; o Windows normaliza o componente `...` e devolve o próprio diretório, então o alvo vira pattern `.` (raiz do módulo, sem `.go`). Só funciona passar o import path (`mod/...`) com o processo já dentro do módulo.

## Prova

Módulo `repro.local/mp` com pacotes `a` e `cmd` (sem `.go` na raiz):

```text
$ goast dump <modulo>/...
goast: carregando "<modulo>/...": erros de carregamento:
-: no Go files in <modulo> (fallback loose: nenhum arquivo .go em "<modulo>/...")

$ cd <modulo> && goast dump ./...
goast: carregando "./...": erros de carregamento:
-: no Go files in <modulo> (fallback loose: nenhum arquivo .go em "./...")

$ cd <modulo> && goast dump repro.local/mp/...     # funciona
```

## Critério de pronto

- `goast dump <dir>/...` e `./...` funcionam no Windows; teste em `tools/goast/dump_test.go`.
