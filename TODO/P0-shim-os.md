# Shim do pacote `os`

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

Sem shim, 181 pacotes do grafo do kubo que usam `os` não transpilam (`shim-ausente:os`).
São 110 símbolos distintos.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:os` | 261 | 111 | 28 | `github.com/cockroachdb/redact/internal/rfmt` print.go:220:6: pacote sem shim/transpilação: os |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `os` | 181 | ❌ | Getenv(59), Stderr(47), Close(45), Open(34), Stat(27), File(26), FileMode(23), ReadFile(22), IsNotExist(20), Remove(20), ErrNotExist(18), O_CREATE(18), OpenFile(18), Fd(17), Exit(16), Name(15), O_WRONLY(14), FileInfo(13), Stdout(12), MkdirAll(11), Rename(11), Create(10), PathError(10), Getpid(9), Write(9), … (+85) |
```

## Critério de pronto

- `golib_dart/lib/os.dart` registrado em `STDLIB_SHIMS` (`g2d/config.py`), cobrindo os símbolos da
  linha `os` de `docs/stdlib-coverage.md` a partir dos mais usados; os ausentes continuam
  `Unsupported` (nunca chamada a função inexistente).
- Semântica com oráculo Go nos testes do golib_dart; fixture e2e em VM × JS × Wasm.
- Audit regerado e commitado.

## Notas

Decidir o recorte: `Getenv`, `Exit`, `Stdout`/`Stderr` (já há `writeStdout`), erros (`ErrNotExist`...); sistema de arquivos só onde o `dart:io` existe (import condicional).
