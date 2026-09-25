# goast: `-C <dir>` e metadados de build por pacote

- **Prioridade:** P0 · **Área:** infra
- **Depende de:** P0-infra-goast-padrao-windows

## Problema

Para despejar o grafo do corpus o goast precisa resolver import paths no módulo do corpus (`-C <dir>`) e dizer por pacote se há cgo e arquivos não-Go (`.s` = assembly), que decidem substituição. Hoje não há nenhum dos dois.

## Prova

```text
$ goast dump -C <modulo> repro.local/mp/...
flag provided but not defined: -C

$ goast dump <pacote> | chaves do pacote
['files', 'implements', 'imports', 'initOrder', 'name', 'path', 'reflectUsage', 'stdlibUsage', 'typeTable']
```

## Critério de pronto

- `-C` e vários alvos numa chamada; `otherFiles`/`cgo` no dump; schema 7 em `tools/goast/README.md`, `g2d/model.py` e `AGENTS.md`; teste Go.
