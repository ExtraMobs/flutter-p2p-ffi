# golib_dart

Core de adaptação do código gerado pelo `g2d`: shims manuais da stdlib Go e as
representações dos tipos primitivos Go.

## Layout

| Caminho | Conteúdo |
|---|---|
| `lib/fixed_types/golang.dart` (+ `golang/`) | Tipos primitivos Go (`Golang.Int8`, `Golang.Uint64`, `Golang.Float64`, `Golang.String`...). Não é stdlib: mantém o namespace do boilerplate, importado com prefixo `Golang`. |
| `lib/<import path Go>.dart` | Shim de um pacote da stdlib (`fmt.dart`, `math.dart`, `net.dart`, `net/netip.dart`, `internal/poll.dart`). O que é interno fica em `lib/src/<import path>/`: as partes (`part`) de uma library grande, como `src/fmt/print.dart` (o `pp` do Go) e `src/fmt/format.dart` (o `fmt`), e libraries auxiliares. |
| `lib/builtin.dart` | Universo Go e runtime do g2d; importado como `go`. Exporta `lib/src/runtime/`. |
| `lib/src/unicode/isprint.dart` | `unicode.IsPrint` do Go (faixas geradas por `go run tool/gen_isprint.go \| dart format`; `test/isprint_test.dart` confere com o Go instalado). |
| `lib/unicode.dart` (+ `lib/src/unicode/range_table.dart`, `predicates.dart`, `tables.g.dart`) | Shim do pacote `unicode`: `RangeTable`/`Range16`/`Range32`/`CaseRange` (structs de shim), predicados e conversões de caixa. `tables.g.dart` é gerado por `tool/gen_unicode*.go` a partir do `unicode` do **Go 1.26.5** (`GOTOOLCHAIN=go1.26.5`, a referência do projeto — difere do Go local em `Cn`/`LC`, mesmo relatando o mesmo `unicode.Version`); `test/unicode_tables_test.dart` confere o gerado em dia e varre 0..0x10FFFF contra `tool/oracle_unicode.go`. |

`fixed_types`, `net`, `net/netip` e `internal/poll` vêm de
`dart IPFS/packages/boilerplate`, mas a divisão em arquivos já não é a da
origem: `src/ints.dart` virou library + partes (`src/ints/`), e a espera de I/O
saiu do `Fd` para o `PollDesc` (`src/internal/poll/poll_desc.dart`, o
`pollDesc` do Go). A sincronização é por conteúdo, não por cópia de arquivo:
leve as correções abaixo para a origem, ou traga as de lá para os arquivos
correspondentes.

Os ports de `net`, `net/netip` e `internal/poll` mantêm a API Dart idiomática
da origem (`Ip`, `tryParse`...). Eles ainda não estão ligados ao g2d
(`STDLIB_SHIMS`), porque a API não segue a regra de nomes do transpilador.

## Runtime (`lib/src/runtime/`, prefixo `go`)

São as classes intermediárias: cada semântica Go que o Dart não tem vive aqui,
igual em VM, AOT, Wasm e JS. A tabela completa está em
`docs/mapping-spec.md`.

| Arquivo | Classes |
|---|---|
| `struct.dart` | `GoValue<T>` (base de valores com armazenamento: `$copy`, `$set` in-place, `$isValue`, `$ifaceCopy`), `GoStruct<T>` (`==` por `$fields`, method sets), `Addr` (ponteiro como valor) |
| `array.dart` | `GoArray<T>` (`[N]T` por valor, fatias compartilhando o armazenamento) |
| `iface.dart` | `assertType`/`assertIface`/`tryType`/`tryIface`/`isType`, `ifaceEq`, `goTypeName` (mensagens `interface conversion` do Go) |
| `slice.dart` | `Slice<T>` (array compartilhado, `append` com o `growslice` do Go 1.25), `growCap`; `base` para os tipos nomeados sobre slice (`Slice.alias`) |
| `map.dart` | `GoMap<K, V>` (nil, zero value, `lookup`, iteração tolerante a `delete`, `identity` para chave `*T`); `base` para os tipos nomeados sobre map (`GoMap.alias`) |
| `ptr.dart` | `Ptr<T>`: `Box`, `ElemPtr`, `FieldPtr`, `NilPtr` (ponteiro nil tipado em interface), `PtrView` (base de `N$Ptr`, ponteiro para nomeado não-struct com métodos) |
| `elem.dart` | `Elem<T>` (sizeof/ponteiros/zero de um tipo; `const`, um por tipo) |
| `panic.dart` | `GoError`, `Panic`, `RuntimeError`, `nilDeref`, `panicValue` (erros do Dart → `runtime.Error` do Go) |
| `defer.dart` | `Defers`, `recover(frame)` (só a chamada direta da função adiada recupera), `runMain` |
| `output*.dart` | `writeStdout`/`writeStderr`/`writeStderrBytes`/`getEnv`/`getPid`/`exitProcess` por import condicional (io × js_interop) |

## fixed_types: bases de operadores e identidade

- `src/base.dart`: `IntBase<S>`, `FloatBase<S>` e `StringBase<S>` (os
  operadores devolvem `S`), estendidas por todas as classes e pelos tipos
  nomeados gerados.
- `src/ints.dart` (helpers de palavra) e as partes em `src/ints/`: a
  representação dos inteiros (`SmallIntBase` em `small_int.dart`,
  `WideIntBase` em `wide_int.dart`) e uma base por largura (`Int8Base` …
  `Uint64Base`, em `width_bases.dart`). Um tipo nomeado gerado estende a base
  da sua largura e herda o mesmo caminho rápido do tipo subjacente.
- As interfaces `GoOrdered`, `GoNumber` e `GoReal` são os bounds de
  genéricos. `GoTyped` (`$goType`, `$methods`) é a identidade Go em runtime.
- `Int`, `Uint` e `Uintptr` são **classes próprias**; eram `typedef` de
  `Int64`/`Uint64` na origem, e isso quebrava type switch e reflexão.
  `Byte`/`Rune` continuam `typedef`, porque também são aliases no Go.

## fixed_types: semântica

A autoridade é a [spec do Go](https://go.dev/ref/spec): *Numeric types*,
*Integer operators*, *Integer overflow* e *Conversions*. Os testes diferenciais
rodam contra o `go` do PATH; a versão de referência do projeto é a 1.26.5
(`GOTOOLCHAIN=go1.26.5 dart test`), a mesma do goast e do corpus.

- **Inteiros:** sem `BigInt` no caminho comum, com a mesma representação em
  todas as plataformas.
  - Até 32 bits: um `int` normalizado à largura. O `*` de 32 bits usa limbs de
    16 bits, porque o produto passaria de 2⁵³ no JS.
  - 64 bits: duas palavras de 32 bits sem sinal (`$hi`/`$lo`), com carry,
    produto em limbs de 16 bits e shifts entre palavras.
  - Invariante: nenhum intermediário passa de 2⁵³, e todo resultado bitwise é
    renormalizado (no JS esses operadores devolvem 32 bits sem sinal).
  - `~/`/`%` de 64 bits: `int` quando os dois operandos cabem em ±2⁵³;
    senão, divisão binária sobre as palavras (no máximo 64 passos). O
    `toString` fora de ±2⁵³ usa uma divisão dessas por 10¹⁰.
  - Float → inteiro (`toInteger`) devolve os 64 bits como `Int64`, calculados
    em double (`T.from` trunca). Inteiro → float fora de ±2⁵³ arredonda direto
    das palavras (guarda, sticky, par).
  - `BigInt` só aparece nas fronteiras explícitas `fromBigInt`/`toBigInt`/
    `toIntExact` (constantes enormes, testes).
  - `toInt()` é a saída para índices, contagens e runas (exata em ±2⁵³).
    `T.from(v)` é a conversão Go entre larguras (trunca `$hi`/`$lo`).
  - `~/` é o `/` inteiro do Go e `%` é o resto truncado do Go; `~` é o `^`
    unário, e `andNot` é o `&^`.
  - Shift negativo lança `ArgumentError`; divisão por zero lança
    `IntegerDivisionByZeroException`.
- **Bool:** tem a classe `Bool`, mas o g2d usa o `bool` nativo, que se comporta
  de forma idêntica.
- **Float32:** binary32 em quatro bytes, com aritmética em binary64 e conversão
  explícita. **Float64:** binary64. Divisão por zero segue o IEEE.
- **String:** bytes arbitrários, inclusive UTF-8 inválido. `length`, `[]` e
  `slice` usam offsets em bytes. `toDart` rejeita UTF-8 inválido; `toString` é
  tolerante (U+FFFD).

## Correções em relação à origem

Cada uma tem teste contra oráculo Go (`test/go_float_extra_test.dart`, gerado
por `test/go_float_vectors_extra.go`):

1. **`Float32`/`Float64.toString`**: não existia (imprimia `Instance of`).
   Agora é o `%v` do Go (`strconv.FormatFloat(x, 'g', -1, bits)`). No float32,
   o desempate segue o do Ryu do Go: meio → par.
2. **`Complex64`/`Complex128.toString`**: era `($real+$imag i)`. Agora é o
   formato do Go: `(1.5-2i)`, `(NaN+Infi)`.
3. **`Float32`/`Float64.toInteger(width, signed:)`**: nova. É a conversão
   float → inteiro exatamente como o gc compila em amd64 (NaN e valores fora do
   intervalo seguem as regras de CVTTSD2SQ/SL; `uint64` tem o caminho ≥ 2⁶³).
4. **`String.toString`**: novo; decodificação tolerante para interpolação.
5. **`String[]` e `String.slice`**: checam os limites e lançam `BoundsError`,
   com a mensagem do Go. O `Uint8List` lança `RangeError` na VM e `IndexError`
   no JS, o que quebrava a paridade entre plataformas.
6. **Formatação de float sem `ByteData.getUint64`**, que não existe no
   dart2js.
7. **`String.decodeRune`, `String.runes()`, `String.fromRunes`**: novos. São o
   `utf8.DecodeRune` do Go (sequência inválida, truncada, overlong, surrogate
   ou acima de U+10FFFF → `(U+FFFD, 1)`) e o `string([]rune)` (runa inválida →
   U+FFFD). Oráculo: o fixture e2e `tests/golden/runes`.
8. **Inteiros reescritos sem `BigInt`** (`src/ints.dart`). Na origem, cada
   valor guardava um `Uint8List` e toda operação passava por `BigInt`.
   `$wrap(BigInt)` saiu; entraram `$hi`/`$lo`/`$signed`, `toInt()` e
   `T.from(v)`. `String.fromCodePoint` passou a receber `int`, e
   `toInteger` devolve `IntBase` em vez de `BigInt`. Oráculo: as
   matrizes `test/go_integer*_matrix*` (VM), o fixture e2e
   `tests/golden/widths` (VM, JS e Wasm) e um diferencial contra o Go com
   92.068 casos (operações, divisão fora de ±2⁵³, conversões, float ↔ int),
   com 0 falhas nas três plataformas. Laço de soma e indexação com
   `Golang.Int` mais laço de `Golang.Uint8`, melhor de 3:

   | Plataforma | Antes | Depois | Ganho |
   |---|---|---|---|
   | VM (JIT) | 620 ms | 19 ms | ~33× |
   | AOT | 600 ms | 7 ms | ~86× |
   | JS (dart2js -O2, Node) | 1916 ms | 40 ms | ~48× |
   | Wasm (dart2wasm, Node) | 649 ms | 17 ms | ~38× |

9. **`toIndex()` e mensagens de limites** (`src/base.dart`, `src/ints.dart`,
   `src/bounds.dart`, `string.dart`). Índice/contagem fora de ±2⁵³ vira um
   sentinela ±2⁵⁴ que guarda o texto exato do valor (`indexText`); antes a
   mensagem saía negativa na VM (uint64 ≥ 2⁶³) e arredondada no JS. Índice
   negativo sai sem ` with length n` (`withBound`, o `boundsNegErrorFmt` do Go).
10. **`ComplexBase`/`ComplexOps`** (`src/base.dart`, `complex64.dart`,
   `complex128.dart`): base dos tipos nomeados sobre complex, que delegam as
   operações ao valor do subjacente.

Chaves de map `Float64` (NaN nunca encontrado, +0 ≡ −0) foram auditadas e já
batiam com o Go.

## Verificação

```bash
dart pub get && dart analyze && dart test   # exige `go` no PATH (oráculos)
dart test -p node $(grep -L "dart:io" test/*_test.dart)   # mesmos testes no JS
```

## Lacunas conhecidas

- A matriz de conversões não cobre todos os pares de tipos.
- JS/Wasm: validados pelo e2e dos fixtures (Node) e pelos testes sem
  `dart:io`; os oráculos Go rodam só na VM (usam `Process`). Navegador: a
  saída cai no `print` por linha (bytes inválidos viram U+FFFD).
