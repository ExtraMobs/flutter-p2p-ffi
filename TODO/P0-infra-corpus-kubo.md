# Corpus kubo fixado

- **Prioridade:** P0 · **Área:** infra
- **Depende de:** P0-infra-goast-grafo

## Problema

O `AGENTS.md` cita `tests/corpus/` (pacotes reais), que não existe. Falta um módulo que fixe o kubo (e por transitividade o boxo e todas as deps) numa versão, com contexto de build fixo (`CGO_ENABLED=0 GOOS=linux GOARCH=amd64`, Go 1.26.5, exigido pelo kubo v0.43.1).

## Prova

```text
$ ls tests/corpus
ls: cannot access 'tests/corpus': No such file or directory
```

Module cache local: `github.com/ipfs/boxo@v0.41.0` presente; `github.com/ipfs/kubo` ausente
(precisa de `go mod download`).

## Critério de pronto

- `tests/corpus/kubo/{go.mod,go.sum,deps.go}` versionados; `python -m g2d graph` lista o grafo; versão e contexto documentados no `AGENTS.md`.
