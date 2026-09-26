# `g2d audit`: todos os problemas do grafo, não só o primeiro

- **Prioridade:** P0 · **Área:** infra
- **Depende de:** P0-infra-import-entre-pacotes

## Problema

Não há comando que meça o grafo real. O Engine para no primeiro `Unsupported` do pacote; a auditoria precisa de modo coleta (registra e segue na próxima declaração), rodar `dart analyze` no que gerou (pega emissão silenciosa de Dart inválido, ver os P1/P2 marcados como tal) e gerar `docs/audit.md` (status por pacote em ordem topológica, ranking de construções, % limpo).

## Prova

```text
$ python -m g2d audit
usage: g2d [-h] {transpile,graph} ...
g2d: error: argument cmd: invalid choice: 'audit' (choose from transpile, graph)
```

## Critério de pronto

- `python -m g2d audit <alvo> -C <dir>` determinístico (duas rodadas, saídas idênticas); `docs/audit.md` gerado; teste unitário do agrupamento.
