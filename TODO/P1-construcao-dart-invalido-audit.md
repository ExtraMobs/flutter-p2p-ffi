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
  `*time.Timer` do shim (tipo de shim em interface local, D8); e o `func()` passado onde o shim
  espera `FutureOr<void> Function()`.
- `golang.org/x/text/internal/language/compact`: `tag._full = tFull.$ifaceCopy()` atribui `Tag`
  a `$_fullTag?` (interface local não exportada que `Tag` não declara implementar).
- `github.com/cockroachdb/logtags`: `unnecessary_cast` (warning) no type switch sobre
  `fmt.Stringer`: `final fmt.Stringer? v$1 = $t2 as fmt.Stringer;` depois de `$t2 is fmt.Stringer`.

(`crlib/fifo` está em `P1-construcao-generico-metodo-ptr-t.md`.)

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo
$ (cd .g2d-cache/out && dart analyze lib/github.com/pion/transport/v3/deadline.dart \
     lib/golang.org/x/text/internal/language/compact.dart lib/github.com/cockroachdb/logtags.dart)
  error - lib/github.com/pion/transport/v3/deadline.dart:247:8 - A value of type 'Timer' can't be returned from the function '_afterFunc' because it has a return type of '$_timer?'. - return_of_invalid_type
  error - lib/github.com/pion/transport/v3/deadline.dart:247:26 - The argument type 'void Function()?' can't be assigned to the parameter type 'FutureOr<void> Function()'.  - argument_type_not_assignable
  error - lib/golang.org/x/text/internal/language/compact.dart:295:13 - A value of type 'Tag' can't be assigned to a variable of type '$_fullTag?'. - invalid_assignment
warning - lib/github.com/cockroachdb/logtags.dart:442:27 - Unnecessary cast. Try removing the cast. - unnecessary_cast
```

## Critério de pronto

- Cada caso vira repro mínimo + fixture em `tests/golden/` com Dart válido igual ao Go, ou
  `Unsupported` com código estável (o `deadline` pode ficar `Unsupported` até D8).
- Audit regerado sem `dart-invalido`.
