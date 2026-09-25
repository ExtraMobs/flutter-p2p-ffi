# Gerador de `docs/reflection-report.md`

- **Prioridade:** P0 · **Área:** docs
- **Depende de:** P0-infra-audit

## Problema

Documento vivo prometido no `AGENTS.md` (usos de `reflect` resolvidos × pendentes); não existe. Dados brutos já saem no `reflectUsage` do goast. Base do M5.

## Prova

```text
$ ls docs/reflection-report.md
ls: cannot access 'docs/reflection-report.md': No such file or directory
```

## Critério de pronto

- Gerado pela auditoria a partir de `reflectUsage`; determinístico.
