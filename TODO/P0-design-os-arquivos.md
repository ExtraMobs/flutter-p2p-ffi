# `os`: sistema de arquivos real

- **Prioridade:** P0 · **Área:** design (decisão D3 do `TODO/README.md`)
- **Depende de:** —

## Problema

O shim `os` cobre o recorte portável (ambiente, `Exit`, `Getpid`,
`Stdout`/`Stderr`, erros sentinela, `PathError`, `FileMode`; ver
`docs/mapping-spec.md` § "Stdlib"). Falta tudo que toca arquivo (`Open`,
`OpenFile`, `Create`, `ReadFile`, `WriteFile`, `Stat`, `Lstat`, `Remove`,
`Rename`, `MkdirAll`, `File.Read`/`Seek`/`Stat`, `io/fs.FileInfo`/`DirEntry`),
e isso espera uma decisão: o JS e o Wasm não têm `dart:io`, e o e2e exige a
mesma saída nas três plataformas.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo
| `shim-simbolo:os.open` | 36 | 22 | 4 | `github.com/prometheus/procfs/internal/util` readfile.go:26:6: símbolo sem shim: os.open |
| `shim-simbolo:os.stat` | 20 | 16 | 3 | `github.com/ipfs/kubo/misc/fsutil` fsutil.go:13:6: símbolo sem shim: os.stat |
| `shim-simbolo:io/fs.DirEntry` | 6 | 5 | 3 | `github.com/facebookgo/atomicfile` atomicfile.go:15:1: símbolo sem shim: io/fs.DirEntry |
| `shim-simbolo:os.readFile` | 18 | 14 | 2 | `github.com/crackcomm/go-gitignore` ignore.go:173:6: símbolo sem shim: os.readFile |
| `shim-simbolo:os.openFile` | 15 | 10 | 1 | `github.com/syndtr/goleveldb/leveldb/storage` file_storage.go:53:6: símbolo sem shim: os.openFile |
```

Somando os códigos `os.*` e `io/fs.*`: 206 ocorrências, 24 na fronteira.

## Decisão pendente

1. **Arquivos reais em toda plataforma que tenha (recomendado).** Backend
   por import condicional, como `src/runtime/output.dart`: `dart:io` na
   VM/AOT; `node:fs` via `js_interop` no JS/Wasm sob Node (é onde o e2e
   roda, então os fixtures continuam idênticos); no navegador, as funções
   devolvem `*PathError` com `ENOSYS`, como o Go faz em `js/wasm` sem
   `fs`.
2. **Só VM/AOT.** Mais simples, mas os fixtures de arquivo não passariam no
   e2e de JS/Wasm, o que quebra a regra 7 do `AGENTS.md`.
3. **Sistema de arquivos em memória** em todas as plataformas. Igual em
   todo lugar, mas o kubo não conseguiria ler o próprio repositório.

A branch `claude/wip-os` tem erros e constantes do `os` (snapshot de
subagente) que servem de base para qualquer opção.

## Critério de pronto

- Símbolos da linha `os` de `docs/stdlib-coverage.md`, dos mais usados para
  os menos; os ausentes seguem `Unsupported`.
- Oráculo Go nos testes do golib_dart; fixture e2e em VM × JS × Wasm.
- Audit regerado.
- Depois disso: `os.Args` real, `Stdin.Read`, `Hostname`, `Environ`,
  `Setenv`, `Signal`/`Process`.
