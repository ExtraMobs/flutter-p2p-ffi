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
| `lib/time.dart` (+ `src/time/sleep.dart`), `lib/context.dart` (+ `src/context/impl.dart`) | Timers do `time` (`Sleep`, `Timer`, `Ticker`, `After`, `AfterFunc`, `Tick`) e o pacote `context`, sobre o escalonador do runtime (M4). `test/fixtures/<caso>.go` + `<caso>.dart` são programas inteiros (o `.dart` escrito como o g2d emitiria) que `test/timer_context_oracle_test.dart` compara com `go build` em VM, JS e Wasm (stdout em bytes, código de saída, `fatal error`). |
| `lib/reflect.dart` (+ `src/reflect/`) | Shim `reflect` (M5, D1): `RType<T>` (descritor estático que o g2d gera por tipo; básicos e construtores `rt*` exportados também por `builtin.dart`), `Type`/`Value`/`StructTag`/`DeepEqual` lendo só o descritor; `Call`/`Method`/`MakeFunc`/`FuncOf` em `src/reflect/func.dart` (as closures tipadas do `MakeFunc`, `src/reflect/make_func.dart`, são geradas por `tool/gen_make_func.py`), `StructOf`/`Select`/operações de canal em `struct_of.dart`/`select.dart`/`chan_ops.dart`. `test/reflect_test.dart` usa um descritor escrito como o g2d emitiria. |
| `lib/net.dart` (+ `src/net/`), `lib/net/netip.dart` (+ `src/net/netip/`) | `net` sem rede (endereços e erros: `IP`, `IPMask`, `IPNet`, `HardwareAddr`, `TCPAddr`/`UDPAddr`/`IPAddr`/`UnixAddr`, `OpError`, `DNSError`, `ErrClosed`...) e `net/netip` inteiro, portados do Go 1.26 com a forma Go (`IP` é subclasse de `Slice` como os nomeados gerados; `SHIM_NAMED_CLASSES`). `test/net_test.dart` compara com o oráculo `test/go_net_vectors.go`. |
| `lib/encoding/json.dart` (+ `src/encoding/json/`), `lib/encoding.dart` | Port do `encoding/json` v1 sobre o shim `reflect`; `encoding` só com as interfaces `Text`/`Binary` `Marshaler`/`Unmarshaler`. |
| `lib/src/net/sys/` | Motor de rede por plataforma (D4), API Dart simples sob o shim `net` do Go: `sys.dart` reexporta `common.dart` (`SysAddr`, `SysError`/`SysTimeout`/`SysClosed`/`SysCanceled`/`SysDnsError`, `SysTcpConn`/`SysTcpListener`/`SysUdpConn`, `SysInterface`, IP em texto, `Deadline`, `heldIo` — a espera que segura o detector de deadlock) e, por import condicional, `sys_io.dart` (VM/AOT: TCP pelo `Fd` do `internal/poll`, UDP por `RawDatagramSocket` com o mesmo `PollDesc`, IP pelo `getaddrinfo`, TXT pelo cliente próprio `dns_client.dart` + `dns_msg.dart` lendo `/etc/resolv.conf`; partes `io_*.dart`), `sys_js.dart` (JS e Wasm: sob Node, `node:net`/`dgram`/`dns`/`os`/`fs` por `dart:js_interop` via `process.getBuiltinModule`; no navegador, decidido em runtime, toda operação lança `EOPNOTSUPP`; partes `js_*.dart`) ou `sys_stub.dart`. `linux_iface.dart`: índice/MTU/MAC/flags de `/sys/class/net` (VM e Node). `test/net_sys_test.dart` roda os cenários de `test/net_sys_node/` na VM e compara a saída de `main.dart` compilado para JS e Wasm (Node); `browser_main.dart` + `run_as_browser.mjs` simulam o navegador. Limites ⚠️ no cabeçalho de cada arquivo e em "Lacunas conhecidas". |

`fixed_types` e `internal/poll` vêm de
`dart IPFS/packages/boilerplate`, mas a divisão em arquivos já não é a da
origem: `src/ints.dart` virou library + partes (`src/ints/`), e a espera de I/O
saiu do `Fd` para o `PollDesc` (`src/internal/poll/poll_desc.dart`, o
`pollDesc` do Go). A sincronização é por conteúdo, não por cópia de arquivo:
leve as correções abaixo para a origem, ou traga as de lá para os arquivos
correspondentes.

O port de `internal/poll` mantém a API Dart idiomática da origem e não está
ligado ao g2d. Os antigos ports de `net` e `net/netip` do boilerplate (`Ip`,
`tryParse`, sobre `dart:io`) foram substituídos por portas diretas do Go 1.26
(`ip.go`, `netip.go`...) com a forma Go, sem `dart:io` (VM, JS e Wasm) e
registradas em `STDLIB_SHIMS`; não há mais o que sincronizar com a origem.

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
| `elem.dart` | `Elem<T>` (sizeof/ponteiros/zero de um tipo; `const`, um por tipo; num grafo reflexivo, `type` aponta o `RType` e `$with` dá o T reificado ao `reflect`) |
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

### `internal/poll` (devolver à origem)

Sem oráculo Go (são sockets reais); cobertas por `test/internal_poll_fd_test.dart`
e pelos cenários de `test/net_sys_test.dart`:

11. **Leitura por borda** (`PollDesc`): o `dart:io` reemite
    `RawSocketEvent.read` numa microtask atrás da outra enquanto há dado não
    lido (`issueReadEvent`); com ninguém lendo, o laço de eventos travava e
    nem temporizador disparava. Agora o evento de leitura desliga
    `readEventsEnabled` até a próxima espera (`waitRead`) ou até o leitor
    esvaziar o socket (`drained`, que deixa o `readClosed` chegar).
12. **Espera depois do despejo**: `waitRead`/`waitWrite` com o descritor já
    despejado (erro assíncrono, `closed` do par) esperavam para sempre — uma
    escrita que encontrava o buffer cheio depois de um `EPIPE` assíncrono
    travava. Agora voltam na hora e quem chamou relança o erro.
13. **Prazos** (`setReadDeadline`/`setWriteDeadline`/`setDeadline` no `Fd` e
    no `PollDesc`, como o `pollDesc` do runtime Go): vencido, `read`/`write`
    lançam `DeadlineExceededException` antes de tocar no socket ou ao acordar;
    mudar o prazo vale para a espera pendente.
14. **`Fd.read` checa o fechamento local antes do EOF**, e **`Fd.write`
    informa o progresso** (`progress:`, o `n` que o Go devolve junto com o
    erro numa escrita interrompida).
15. **`PollDesc.datagram`**: a mesma prontidão sobre `RawDatagramSocket`.

Chaves de map `Float64` (NaN nunca encontrado, +0 ≡ −0) foram auditadas e já
batiam com o Go.

## Verificação

```bash
dart pub get && dart analyze && dart test   # exige `go` no PATH (oráculos)
dart test -p node $(grep -L "dart:io" test/*_test.dart)   # mesmos testes no JS
```

## Lacunas conhecidas

- A matriz de conversões não cobre todos os pares de tipos.
- Motor de rede (`src/net/sys/`), ⚠️ por plataforma:
  - VM: o `dart:io` dá como IP local de uma conexão o do listener (aceitas)
    ou o do par (discadas); o IP local vem de `/proc/net/tcp{,6}` no linux
    (exato) e, fora dele, é o loopback quando o par é loopback e "não
    especificado" no resto. Interfaces fora do linux: sem MTU, MAC e flags
    reais. UDP: `v6Only` ignorado (o `dart:io` não expõe `IPV6_V6ONLY` em
    UDP) e datagrama vazio não é enviado (`send` devolve 0 igual a buffer
    cheio). DNS TXT: cliente próprio só com `/etc/resolv.conf` (Windows cai no
    padrão `127.0.0.1:53`); TXT com UTF-8 inválido vira U+FFFD (também no
    Node).
  - Node: escrita interrompida por prazo/close só conta pedaços de 64 KiB
    confirmados, e o pedaço em voo ainda pode sair; `closeRead` é local
    (descarta o que chega); UDP recebido sem leitor fica numa fila de até
    4096 datagramas (o resto se perde); listener sem contrapressão de
    `accept` (as conexões ficam pausadas até serem aceitas); fora do linux,
    interfaces com índice pela ordem e sem MTU/flags.
  - Navegador: sem rede (`EOPNOTSUPP` em toda operação), por decisão (D4).
- JS/Wasm: validados pelo e2e dos fixtures (Node) e pelos testes sem
  `dart:io`; os oráculos Go rodam só na VM (usam `Process`). Navegador: a
  saída cai no `print` por linha (bytes inválidos viram U+FFFD).
