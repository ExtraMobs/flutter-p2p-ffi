# Shim do pacote `sync/atomic`

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

Sem shim, 129 pacotes do grafo do kubo que usam `sync/atomic` não transpilam (`shim-ausente:sync/atomic`).
São 34 símbolos distintos.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:sync/atomic` | 142 | 65 | 10 | `github.com/cockroachdb/crlib/crsync` typed_atomic.go:21:1: pacote sem shim/transpilação: sync/atomic |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `sync/atomic` | 129 | ❌ | Load(78), Store(67), Add(50), Bool(34), Int64(32), CompareAndSwap(24), Value(21), AddUint64(20), Int32(20), LoadInt32(19), Pointer(19), Uint64(18), Swap(17), StoreInt32(15), LoadUint32(14), LoadInt64(13), LoadUint64(13), AddInt64(12), AddInt32(10), AddUint32(10), StoreInt64(10), StoreUint32(10), Uint32(10), StoreUint64(7), CompareAndSwapUint32(6), … (+9) |
```

## Critério de pronto

- `golib_dart/lib/sync/atomic.dart` registrado em `STDLIB_SHIMS` (`g2d/config.py`), cobrindo os símbolos da
  linha `sync/atomic` de `docs/stdlib-coverage.md` a partir dos mais usados; os ausentes continuam
  `Unsupported` (nunca chamada a função inexistente).
- Semântica com oráculo Go nos testes do golib_dart; fixture e2e em VM × JS × Wasm.
- Audit regerado e commitado.

## Notas

`atomic.Int64`/`Uint32`/`Bool`/`Value`/`Pointer[T]` e as funções `Add*`/`Load*`/`Store*`/`CompareAndSwap*`: num isolate só, operações simples sobre os fixed_types.
