# Pacotes do grafo com Dart inválido no audit

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** D8 (`P1-design-interfaces-entre-pacotes.md`) para o `deadline`

## Problema

O audit regerado em 2026-10-03 (Dart SDK 3.13.5, cache frio) mostra pacotes `dart-invalido`
que o `docs/audit.md` de 2026-10-02 dava como verdes. Rodando o audit do `main` (9f801ed) no
mesmo ambiente o resultado é o mesmo (157 verdes, 8 `dart-invalido`): não vem das correções
de §2c, e sim do ambiente em que o audit anterior foi gerado (versão do SDK ou cache antigo).
Os casos que sobram depois de §2c:

- `github.com/pion/transport/v3/deadline` e `v4/deadline`: `func afterFunc(...) timer { return
  time.AfterFunc(d, f) }`, com `timer` interface local (`Stop`, `Reset`) satisfeita pelo
  `*time.Timer` do shim (tipo de shim em interface local, D8).
- `golang.org/x/text/internal/language/compact`: `tag._full = tFull.$ifaceCopy()` atribui `Tag`
  a `$_fullTag?` (interface local não exportada que `Tag` não declara implementar).

(`crlib/fifo` está em `P1-construcao-generico-metodo-ptr-t.md`.)

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo   # main com #7–#10, 2026-10-03
$ (cd .g2d-cache/out && dart analyze lib/github.com/pion/transport/v3/deadline.dart \
     lib/golang.org/x/text/internal/language/compact.dart)
  error - lib/github.com/pion/transport/v3/deadline.dart:247:8 - A value of type 'Timer' can't be returned from the function '_afterFunc' because it has a return type of '$_timer?'. - return_of_invalid_type
  error - lib/golang.org/x/text/internal/language/compact.dart:295:13 - A value of type 'Tag' can't be assigned to a variable of type '$_fullTag?'. Try changing the type of the variable, or casting the right-hand type to '$_fullTag?'. - invalid_assignment
  error - lib/golang.org/x/text/internal/language/compact.dart:307:13 - A value of type 'Tag' can't be assigned to a variable of type '$_fullTag?'. Try changing the type of the variable, or casting the right-hand type to '$_fullTag?'. - invalid_assignment
```

(O `logtags` e o `func()` passado ao `time.AfterFunc` do `deadline` deixaram de
falhar com os PRs #7–#10.)

## Critério de pronto

- Cada caso vira repro mínimo + fixture em `tests/golden/` com Dart válido igual ao Go, ou
  `Unsupported` com código estável (o `deadline` pode ficar `Unsupported` até D8).
- Audit regerado sem `dart-invalido`.
