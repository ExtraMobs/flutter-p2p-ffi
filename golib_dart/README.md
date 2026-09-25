# golib_dart

Core de adaptação do código gerado pelo `g2d`: shims manuais da stdlib Go e as
representações dos tipos primitivos Go.

## Layout

| Caminho | Conteúdo |
|---|---|
| `lib/fixed_types/golang.dart` (+ `golang/`) | Tipos primitivos Go (`Golang.Int8`, `Golang.Uint64`, `Golang.Float64`, `Golang.String`...). Não é stdlib: mantém o namespace do boilerplate, importado com prefixo `Golang`. |
| `lib/<import path Go>.dart` | Shim de um pacote da stdlib (`fmt.dart`, `math.dart`, `net.dart`, `net/netip.dart`, `internal/poll.dart`). Partes internas em `lib/src/<import path>/`. |
| `lib/builtin.dart` | Universo Go e runtime do g2d; importado como `go`. Exporta `lib/src/runtime/`. |

`fixed_types`, `net`, `net/netip` e `internal/poll` vêm de
`dart IPFS/packages/boilerplate`. Para sincronizar, copie de novo e reaplique as
correções abaixo, ou leve-as para a origem.

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
| `slice.dart` | `Slice<T>` (array compartilhado, `append` com o `growslice` do Go 1.25), `growCap` |
| `map.dart` | `GoMap<K, V>` (nil, zero value, `lookup`, iteração tolerante a `delete`) |
| `ptr.dart` | `Ptr<T>`: `Box`, `ElemPtr`, `FieldPtr`, `NilPtr` (ponteiro nil tipado em interface) |
| `elem.dart` | `Elem<T>` (sizeof/ponteiros/zero de um tipo; `const`, um por tipo) |
| `panic.dart` | `GoError`, `Panic`, `RuntimeError`, `nilDeref`, `panicValue` (erros do Dart → `runtime.Error` do Go) |
| `defer.dart` | `Defers`, `recover(frame)` (só a chamada direta da função adiada recupera), `runMain` |
| `output*.dart` | `writeStdout`/`writeStderr`/`exitProcess` por import condicional (io × js_interop) |

## fixed_types: bases de operadores e identidade

- `src/base.dart`: `IntBase<S>`, `FloatBase<S>` e `StringBase<S>` (os
  operadores devolvem `S`), estendidas por todas as classes e pelos tipos
  nomeados gerados.
- As interfaces `GoOrdered`, `GoNumber` e `GoReal` são os bounds de
  genéricos. `GoTyped` (`$goType`, `$methods`) é a identidade Go em runtime.
- `Int`, `Uint` e `Uintptr` são **classes próprias**; eram `typedef` de
  `Int64`/`Uint64` na origem, e isso quebrava type switch e reflexão.
  `Byte`/`Rune` continuam `typedef`, porque também são aliases no Go.

## fixed_types: semântica

A autoridade é a [spec do Go](https://go.dev/ref/spec): *Numeric types*,
*Integer operators*, *Integer overflow* e *Conversions*. Os testes diferenciais
rodam contra o Go instalado (1.25.7 windows/amd64).

- **Inteiros:** guardam 1, 2, 4 ou 8 bytes privados, conforme a largura.
  - `BigInt` só aparece em aritmética intermediária exata.
  - Conversões em tempo de execução truncam.
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

Chaves de map `Float64` (NaN nunca encontrado, +0 ≡ −0) foram auditadas e já
batiam com o Go.

## Verificação

```bash
dart pub get && dart analyze && dart test   # exige `go` no PATH (oráculos)
dart test -p node $(grep -L "dart:io" test/*_test.dart)   # mesmos testes no JS
```

## Lacunas conhecidas

- Não há iteração de runes nem conversão string ↔ `[]rune`.
- A matriz de conversões não cobre todos os pares de tipos.
- JS/Wasm: validados pelo e2e dos fixtures (Node) e pelos testes sem
  `dart:io`; os oráculos Go rodam só na VM (usam `Process`). Navegador: a
  saída cai no `print` por linha (bytes inválidos viram U+FFFD).
