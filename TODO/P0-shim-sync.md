# Shim do pacote `sync`

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** P0-design-m4-concorrencia (WaitGroup, Cond)

## Problema

Sem shim, 386 pacotes do grafo do kubo que usam `sync` não transpilam (`shim-ausente:sync`).
São 35 símbolos distintos.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:sync` | 692 | 305 | 36 | `github.com/cockroachdb/pebble/v2/internal/intern` intern.go:9:1: pacote sem shim/transpilação: sync |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `sync` | 386 | ❌ | Lock(265), Unlock(265), Mutex(209), Once(134), Do(133), RWMutex(120), RLock(110), RUnlock(110), Wait(97), WaitGroup(89), Done(82), Add(81), Get(80), Pool(80), Put(80), New(77), Cond(16), Go(15), Broadcast(13), Map(13), Load(11), NewCond(10), L(8), LoadOrStore(8), Signal(7), … (+10) |
```

## Critério de pronto

- `golib_dart/lib/sync.dart` registrado em `STDLIB_SHIMS` (`g2d/config.py`), cobrindo os símbolos da
  linha `sync` de `docs/stdlib-coverage.md` a partir dos mais usados; os ausentes continuam
  `Unsupported` (nunca chamada a função inexistente).
- Semântica com oráculo Go nos testes do golib_dart; fixture e2e em VM × JS × Wasm.
- Audit regerado e commitado.

## Notas

`Mutex`/`RWMutex`/`Once`/`Pool`/`Map` têm semântica trivial num isolate só; `WaitGroup` e `Cond` só fazem sentido com goroutines (M4).
