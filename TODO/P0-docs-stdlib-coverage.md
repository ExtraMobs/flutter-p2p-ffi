# Gerador de `docs/stdlib-coverage.md`

- **Prioridade:** P0 · **Área:** docs
- **Depende de:** P0-infra-audit

## Problema

O `AGENTS.md` lista `docs/stdlib-coverage.md` (símbolo stdlib usado × shim) como documento vivo gerado; o gerador e o arquivo não existem. É o que prioriza os TODOs de `shim`. Os dados brutos já saem no `stdlibUsage` do goast.

## Prova

```text
$ ls docs/stdlib-coverage.md
ls: cannot access 'docs/stdlib-coverage.md': No such file or directory
```

## Critério de pronto

- Gerado pela auditoria a partir de `stdlibUsage` × `STDLIB_SHIMS`/símbolos dos shims; determinístico.
