# Shim do pacote `strings` (parcial)

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

O shim `strings` existe com parte dos símbolos (`Builder`, `contains`, `containsRune`, `count`, `hasPrefix`, `hasSuffix`, `index`, `indexByte`, `join`, `lastIndex`, `split`, `splitN`, `trimFunc`, `trimLeftFunc`, `trimPrefix`, `trimRightFunc`, `trimSuffix`); os que faltam viram
`Unsupported` `shim-simbolo:strings.<nome>`. Somando as linhas abaixo: 207 ocorrências de pacote,
39 na fronteira (334 pacotes do grafo usam `strings`).

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-simbolo:strings.trimSpace` | 47 | 33 | 9 | `github.com/blang/semver/v4` semver.go:240:6: símbolo sem shim: strings.trimSpace |
| `shim-simbolo:strings.equalFold` | 20 | 14 | 7 | `github.com/pion/webrtc/v4/internal/fmtp` fmtp.go:92:6: símbolo sem shim: strings.equalFold |
| `shim-simbolo:strings.toLower` | 47 | 35 | 4 | `github.com/gabriel-vasile/mimetype/internal/charset` charset.go:163:6: símbolo sem shim: strings.toLower |
| `shim-simbolo:strings.map` | 4 | 4 | 3 | `github.com/go-logfmt/logfmt` encode.go:179:6: símbolo sem shim: strings.map |
| `shim-simbolo:strings.trim` | 16 | 13 | 2 | `github.com/klauspost/cpuid/v2` cpuid.go:991:6: símbolo sem shim: strings.trim |
| `shim-simbolo:strings.replaceAll` | 10 | 8 | 2 | `github.com/pion/rtcp` compound_packet.go:23:1: símbolo sem shim: strings.replaceAll |
| `shim-simbolo:strings.Reader` | 7 | 6 | 2 | `github.com/anmitsu/go-shlex` shlex.go:74:6: símbolo sem shim: strings.Reader |
| `shim-simbolo:strings.fieldsFunc` | 5 | 4 | 2 | `github.com/ipld/go-ipld-prime/datamodel` path.go:113:6: símbolo sem shim: strings.fieldsFunc |
| `shim-simbolo:strings.replace` | 11 | 10 | 1 | `github.com/blang/semver/v4` range.go:205:6: símbolo sem shim: strings.replace |
| `shim-simbolo:strings.repeat` | 11 | 8 | 1 | `github.com/RaduBerinde/btreemap` node.go:29:1: símbolo sem shim: strings.repeat |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `strings` | 334 | ✅ | Join(112), HasPrefix(104), Split(91), Contains(71), ToLower(66), Builder(63), String(63), TrimSpace(63), TrimPrefix(51), HasSuffix(50), WriteString(47), Index(32), TrimSuffix(32), IndexByte(30), Replace(30), SplitN(27), WriteByte(26), Cut(23), EqualFold(23), Grow(21), Trim(21), LastIndex(20), ReplaceAll(17), SplitSeq(16), TrimRight(16), Compare(12), ContainsRune(12), Repeat(12), ToUpper(12), WriteRune(12), LastIndexByte(11), Fields(10), NewReader(10), TrimLeft(10), ContainsAny(9), FieldsFunc(8), Len(8), Count(7), CutPrefix(7), Map(7), Write(6), IndexAny(5), IndexFunc(4), IndexRune(4), Cap(3), LastIndexAny(3), NewReplacer(3), CutSuffix(2), LastIndexFunc(2), Reset(2), Lines(1), Read(1), Reader(1), Seek(1), Size(1), SplitAfter(1), Title(1), TrimFunc(1) |
```

## Critério de pronto

- Os símbolos da linha `strings` de `docs/stdlib-coverage.md`, a partir dos que mais destravam a
  fronteira; semântica com oráculo Go (fixture e2e em VM × JS × Wasm ou teste no golib_dart).
- `python -m g2d shims`; audit regerado e commitado.

## Notas

`Builder`, `Reader`, `NewReader`, `NewReplacer` são tipos struct de shim:
`P1-design-structs-de-shim.md`. `ToLower`/`ToUpper`, `TrimSpace`, `EqualFold`, `Fields`, `Title`
dependem de tabelas Unicode do Go (gerar como `src/unicode/isprint.dart`, conferidas por teste).
`SplitSeq`/`FieldsSeq` dependem de `iter` (range-over-func). O resto (`Replace`/`ReplaceAll`, `Cut`,
`Trim`/`TrimLeft`/`TrimRight`, `Repeat`, `Compare`, `LastIndexByte`, `IndexAny`, `ContainsAny`,
`CutPrefix`, `Map`...) é barato: porta do fonte do Go, fixture em `tests/golden/bytesstrings`.
