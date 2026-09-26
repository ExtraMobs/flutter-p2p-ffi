# Fixture e pipeline multi-pacote

- **Prioridade:** P0 · **Área:** infra
- **Depende de:** —

## Problema

`tests/test_golden.py` supõe um pacote por caso (`(pkg,) = parse_dump(...)`, `go run *.go`, um `.dart` por caso). Não há como ter um fixture golden/e2e com vários pacotes, nem o pipeline transpila o grafo de um módulo com dependências em ordem.

## Prova

Dump real do módulo `multi/init` (2 pacotes) passado ao que o `test_2_transpile` faz:

```text
pacotes no dump: ['repro.local/mp/a', 'repro.local/mp/cmd']
test_2_transpile: ValueError: too many values to unpack (expected 1, got 2)
```

## Critério de pronto

- Caso golden multi-pacote (diretório com `go.mod`), goldens por pacote, e2e `go run ./cmd` × Dart em VM × JS × Wasm.
- `AGENTS.md` (convenção de fixtures) atualizado.
