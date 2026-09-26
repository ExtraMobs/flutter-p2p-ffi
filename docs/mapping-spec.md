# Mapping spec Go → Dart

Correspondência semântica implementada pelo `g2d`. As regras moram nos
comportamentos (`g2d/behaviors/`: uma classe por nó Go, builtin e conversão)
e nos serviços (`g2d/services/`: tipos, nomes, semântica de valor,
descritores...). O runtime fica em `golib_dart/`. Toda construção fora destas tabelas
levanta `Unsupported` com a posição no código Go. O transpilador nunca emite
código aproximado em silêncio.

Legenda: ✅ fiel · ⚠️ fiel no caso comum, com limite conhecido · ❌ não suportado ainda.

## Princípios

1. **Todas as plataformas Dart.** O código gerado roda igual em VM, AOT, Wasm
   e JS (dart2js). O e2e compara a saída do `go run`, byte a byte, com a da
   VM, do JS (Node) e do Wasm (Node).
2. **Classe intermediária para toda adaptação.** Cada semântica Go que o Dart
   não tem nativamente vive em uma classe de `golib_dart`. O emissor só a
   instancia e chama. Se a classe diverge do Go, a correção vai **na classe**,
   com um teste contra oráculo Go, e nunca num truque do emissor.
3. **Nativo só se idêntico.** Um tipo nativo do Dart só é usado quando se
   comporta exatamente como o tipo Go em todas as plataformas. Hoje isso vale
   só para `bool`.
4. **Desempenho se resolve dentro das classes** (por exemplo, com
   implementação específica por plataforma via import condicional), nunca
   afrouxando o mapeamento.

## Classes intermediárias

| Adaptação Go | Classe (golib_dart) | Milestone | Status |
|---|---|---|---|
| inteiros de largura fixa, `int`/`int64` | `Golang.Int8` … `Golang.Int64`, `Golang.Uint*` (`fixed_types`; até 32 bits um `int` normalizado, 64 bits duas palavras de 32; sem `BigInt` no caminho comum) | M2 | ✅ |
| `float32`/`float64`, `complex*` | `Golang.Float32/64`, `Golang.Complex64/128`; `real(z)`/`imag(z)` → `z.real`/`z.imag`, `complex(r, i)` → `Golang.Complex128.fromDoubles(...)` | M2 | ✅ |
| `string` (bytes, UTF-8 inválido) | `Golang.String` | M2 | ✅ |
| struct (valor, cópia, `==`) | `go.GoStruct<T>` (classe base) | M3 | ✅ |
| ponteiro como valor (identidade, `*T` nil em interface) | `go.Addr` | M3 | ✅ |
| ponteiro para não-struct (`&x`, `&s[i]`, `&o.f`, `new`) | `go.Ptr<T>`: `go.Box`, `go.ElemPtr`, `go.FieldPtr` | M3 | ✅ |
| slice (aliasing, cap, `append`, nil) | `go.Slice<T>` | M3 | ✅ |
| map (nil, zero value, comma-ok, delete no range) | `go.GoMap<K, V>` | M3 | ✅ |
| descritor de tipo (tamanho, ponteiros, zero) | `go.Elem<T>` (`const`, um por tipo) | M3/M5 | ✅ (base da reflexão) |
| `defer` / `recover` / `panic` / erros de runtime | `go.Defers`, `go.Panic`, `go.RuntimeError`, `go.runMain` | M3 | ✅ |
| saída padrão em bytes | `writeStdout` (import condicional io/web) | M2 | ✅ |
| identidade de tipo em runtime (`int` × `int64` × nomeado) | uma classe Dart por tipo Go (`Golang.Int` ≠ `Golang.Int64`) + `GoTyped` (`$goType`, `$methods`) | M3 | ✅ |
| tipos nomeados sobre básicos | classe gerada sobre `Golang.<Largura>Base/FloatBase/StringBase<S>` | M3 | ✅ |
| interfaces, type assertion, type switch | `abstract mixin class` + `implements` (go/types) + `go.assertType/assertIface/tryType/isType` | M3 | ✅ |
| embedding (promoção) | caminho `$sel.index` + `mixin E$Promote` (forwarders) | M3 | ✅ |
| genéricos | parâmetros de tipo Dart + dicionário `go.Elem<T>` (`$T`) + bounds `IntBase/GoReal/GoOrdered/StringBase` | M3 | ✅ |
| arrays `[N]T` (valor) | `go.GoArray<T>` (base `go.GoValue`, como `GoStruct`) | M3 | ✅ |
| goroutines, canais, `select` | `Chan<T>` + scheduler (async/Streams) | M4 | ❌ |
| reflexão | descritores estáticos (evolução de `go.Elem`) | M5 | ❌ |

## Plataformas: ponteiros e `Type` (verificado)

- **`dart:ffi` não serve para ponteiros Go.** O dart2js e o dart2wasm recusam
  o import (`Dart library 'dart:ffi' is not available on this platform`). E,
  mesmo na VM, `Pointer<T>` só aponta para memória nativa de tipos FFI, nunca
  para objetos, variáveis ou campos Dart. O Dart não tem `ref`/`out` nem
  endereço de variável. Por isso os ponteiros são as classes `go.Ptr`
  (`Box`/`ElemPtr`/`FieldPtr`), e structs e arrays são o próprio endereço.
- **`Type` como objeto de primeira classe.** Nas três plataformas:
  - a identidade por classe funciona (`runtimeType == Celsius`, `is T`
    reificado, `Type` como chave de map);
  - `typedef` **não** cria identidade (alias).

  Por isso cada tipo Go distinto é uma classe Dart distinta, inclusive
  `int` × `int64` e os tipos nomeados. ⚠️ O `runtimeType` de coleções do
  core **difere no JS** (`<T>[].runtimeType != List<T>`), então os testes de
  tipo usam sempre `is T`, nunca `runtimeType` de tipos do core.
- **`unsafe`.** Sem memória crua (nem `dart:ffi`, que não existe no JS/Wasm),
  `unsafe.Pointer` e os builtins de memória recusam com o nome real:
  `unsafe:Pointer`, `unsafe:Slice`, `unsafe:String`, `unsafe:StringData`,
  `unsafe:SliceData`, `unsafe:Add`. Decisão:
  - `unsafe.Sizeof`/`Alignof`/`Offsetof` são constantes do `go/types`
    (layout amd64), já dobradas;
  - traduzível com equivalente seguro (a fazer): `unsafe.String(&b[0], n)` /
    `unsafe.String(unsafe.SliceData(b), n)` → `string(b[:n])`, e
    `unsafe.Slice(unsafe.StringData(s), len(s))` → os bytes de `s` (cópia; o
    Go só permite ler);
  - o resto (aritmética de ponteiro, reinterpretar memória entre tipos,
    `(*[N]T)(unsafe.Pointer(p))`) marca o pacote para **substituição** manual,
    como assembly.

## Unidade de compilação

| Go | Dart | |
|---|---|---|
| pacote (todos os arquivos) | uma library `lib/<import path>.dart` | ✅ |
| `import "fmt"` | `import 'package:golib_dart/fmt.dart' as fmt;` (só se usado no Dart) | ✅ |
| prefixo igual a um nome Dart da library (campo/método `Time` → `time`, função `Fmt`) | o prefixo ganha `_` (`as time_;`): um membro `time` sombrearia o prefixo no corpo e no construtor da classe. Dois imports de arquivos diferentes com o mesmo nome (`crypto/rand`, `math/rand`) também se distinguem | ✅ (fixture `importprefix`) |
| universo e runtime | `import 'package:golib_dart/builtin.dart' as go;` | ✅ |
| tipos básicos | `import 'package:golib_dart/fixed_types/golang.dart' as Golang;` | ✅ |
| `func main` | `void main() { go.runMain(() { $goInit(); ... }); }`: panic não recuperado (inclusive na inicialização) vai para o stderr com exit 2 | ✅ |
| variáveis de pacote | declaradas com o zero; o inicializador roda em `$goInit`, na ordem de `types.Info.InitOrder` (dependências primeiro, não a ordem de declaração) | ✅ |
| `func init` (várias, vários arquivos) | `void _init$N()`, chamadas por `$goInit` depois das variáveis, em ordem de arquivo/fonte | ✅ |
| import de pacote não-stdlib (do grafo) | `import 'package:out/<import path>.dart' as <nome>;` (o mono-repo gerado); tipos, funções, constantes, métodos, tipos nomeados sobre slice/map/func e interfaces de outro pacote em `implements` | ✅ (fixture `multipkg`) |
| var exportada de pacote importável | tipo não-valor mora sempre num `go.Box` (`a.x.value`; `&a.X` é a caixa): outro pacote pode tomar o endereço e o dono não sabe; ⚠️ custa uma indireção mesmo sem `&` | ✅ |
| `*N` de tipo nomeado exportado não-struct com métodos | `N$Ptr` sempre gerado pelo dono (o consumidor pode usar `*N`); ⚠️ classe a mais quando ninguém usa | ✅ |
| inicialização das dependências | o `$goInit` do `main` chama antes o `$goInit` de cada pacote do grafo, na ordem global do Go ≥ 1.21 (o menor import path cujos imports já inicializaram; `g2d.graph.topo_order`), não recursivamente por importador; main sem o grafo no dump → `Unsupported` (`init-grafo-incompleto`); shims da stdlib não têm init | ✅ (fixture `multiinit`) |
| import `.` | nenhum prefixo próprio: identificadores e tipos já trazem o pacote do objeto e saem qualificados pelo prefixo derivado do import path (`tok.Token`) | ✅ (fixture `dotimport`) |
| import `_` | nenhum import Dart: o pacote do grafo inicializa pela ordem global do `$goInit` do main; shim da stdlib não tem init. `_ "embed"` (só existe para `//go:embed`) → `Unsupported` `go:embed` | ✅ (fixture `blankimport`) |
| função sem corpo (assembly, `go:linkname`) | — (`Unsupported` `func-sem-corpo`: o pacote vai para substituição) | ❌ |

## Identificadores

| Go | Dart | Limite |
|---|---|---|
| tipo exportado `Greeter` | `Greeter` (tipo `Golang` → `Golang$`) | |
| tipo não exportado `point` | `_point$`: o `$` separa do membro não exportado `_point` (campo embutido, campo ou método com o nome do tipo sombreariam a classe; fixture `embedprivate`) | |
| func/var/const/campo/método exportado `HTTPServer` | `httpServer` (lowerCamel ciente de siglas) | ✅ |
| func/var/const de pacote exportados que só diferem por caixa (`BOOL`/`Bool`, `FOO`/`Foo`) | o goast marca `fold` nos dois (também quando usados de outro pacote); o que perde a caixa de mais de uma letra no lowerCamel mantém a grafia Go (`BOOL`), o outro segue a regra (`bool$`). Nomes assim nunca colidem entre si nem com um lowerCamel | ✅ (fixture `foldnames`). ⚠️ campos/métodos: sem ocorrência no grafo do kubo, colidiriam |
| idem não exportado `add` | `_add` (privado da library = do pacote) | |
| local/parâmetro | nome Go; se repetido na função ou igual a um nome de library → `x$1` | |
| palavra reservada Dart (`new`, `in`, ...) | sufixo `$` (`new$`) | |
| nome do `dart:core` usado pelo código gerado (`Object`, `Map`, `String`, `List`, `Function`, `BigInt`, `identical`, `int`, `bool`, ...: `DART_CORE_USED`) | sufixo `$` (`Object$`, `identical$`, local `int$`), para não sombrear o core na library | |
| método/campo exportado com o nome de um membro das bases estendidas (`Delete`, `Append`, `Value`, `Length`, `Call`, `ToString`, ...: `DART_BASE_MEMBERS`) | sufixo `$` (`delete$`, `value$`, `toString$`), em todo lugar, inclusive nas interfaces (o despacho continua casando) | |
| tipo declarado dentro de função | içado para a library como `_<função>$<Tipo>$` (`_first$pair$`; método: `_<Recv>_<Método>$<Tipo>$`; repetido na função: sufixo numérico) | em função genérica, a classe içada é genérica nos parâmetros da função (`_wrap$box$<T>`, dicionários no construtor; fixture `localgeneric`) |
| letra não-ASCII (`Δ`, `Ωmega`) | `$uXXXX` (BMP) ou `$UXXXXXXXX`, largura fixa como no C (`Δ` → `$u0394`, `Δ0` → `$u03940`); o Go decide exportado por `unicode.IsUpper` (`Δx` → `$u03b4x`, `δx` → `_$u03b4x`) | ✅ (fixture `mathshim`) |
| temporários e descritores | `$tN`, `_$eN`, `_$zN` (Go não permite `$`) | |

## Tipos

| Go | Dart | Zero |
|---|---|---|
| `bool` | `bool` | `false` |
| `int`, `int64`, `int8/16/32`, `rune` | `Golang.Int`, `Golang.Int64`, `Golang.Int8/16/32` | `Golang.Int()` |
| `uint`, `uintptr`, `uint8..64`, `byte` | `Golang.Uint`, `Golang.Uintptr`, `Golang.Uint8..64` | `Golang.Uint8()` |
| `float32`, `float64` | `Golang.Float32`, `Golang.Float64` | `Golang.Float64()` |
| `complex64`, `complex128` | `Golang.Complex64/128` | `Golang.Complex128()` |
| `string` | `Golang.String` | `Golang.String()` |
| `error` | `go.GoError?` (`error()` → `Golang.String`) | `null` |
| `any` / `interface{}` | `Object?` | `null` |
| struct nomeada | `class T extends go.GoStruct<T>` | `T()` |
| `*T`, T struct | `T?` (a struct é o próprio endereço) | `null` |
| `*T`, T não-struct | `go.Ptr<T>?` | `null` |
| `[]T` | `go.Slice<T>` | `go.Slice<T>.nil(_$eN)` |
| `map[K]V` | `go.GoMap<K, V>` | `go.GoMap<K, V>.nil(_$eN)` |
| `func(A) R` | `R Function(A)?` | `null` |
| múltiplos resultados | record `(A, B)` | |
| `[N]T` | `go.GoArray<T>` | `go.GoArray<T>.zero(N, _$eN)` |
| nomeado sobre básico (`type Celsius float64`) | `final class Celsius extends Golang.FloatBase<Celsius>` | `Celsius()` |
| interface nomeada | `abstract mixin class I` (anulável: `I?`) | `null` |
| parâmetro de tipo `T` | `T` (dicionário `go.Elem<T> $T`) | `$T.zero()` |
| nomeado sobre bool (`type Flag bool`) | `final class Flag extends go.GoBool` (`$b`, `==` com o tipo, `toString`); condições (`if`, `for`, `switch` sem tag, `&&`/`||`) usam `.$b`; `!f`, `f && g` com resultado Flag e comparações que fluem para Flag (o go/types dá o tipo do contexto a `a < b`) são embrulhados; `Flag(b)`/`bool(f)` por `$b`. Fixture `namedbool` | `Flag()` |
| nomeado sobre array (`type Hash [32]byte`) | `final class Hash extends go.GoArray<Golang.Uint8>` (`Hash(go.GoArray...)` via `alias`); array é valor como struct, então os métodos de receptor ponteiro também ficam na classe e `Hash.$nil` é a sentinela; `[32]byte(h)` → `go.GoArray<...>.alias(h)` (tipo dinâmico sem nome). Fixture `namedarray` | `Hash(go.GoArray<...>.zero(32, _$eN))` |
| nomeado sobre slice/map (`type IDs []string`) | `final class IDs extends go.Slice<Golang.String>` (idem `go.GoMap`); conversão/atribuição = `IDs(s)` via `Slice.alias` (mesmo array) | `IDs(go.Slice<...>.nil(_$eN))` |
| nomeado sobre func (`type Op func(int) int`) | `final class Op` chamável: `$f` (anulável), `call(...)`, `isNil`; `Op(fn)` / `op.$f` nas atribuições entre nomeado e não nomeado | `Op(null)` |
| `*N`, N nomeado não-struct com métodos e `*N` usado no pacote | `N$Ptr?`: `final class N$Ptr extends go.PtrView<N>` (vista sobre `go.Box`/`ElemPtr`/`FieldPtr`) com os métodos de receptor ponteiro, forwarders dos de valor e as interfaces de `*N` | `null` |
| struct anônima (`struct{ X int }`, tabelas de teste) | classe sintética `_anon$<índice da typeTable>$` (uma por tipo; `go.GoStruct`, igualdade e cópia como qualquer struct) | `_anon$N$()` |
| interface anônima com métodos (`interface{ Name() string }`) | `abstract mixin class _anonIface$<índice>$`; o goast põe no `implements` os literais `interface{...}` usados fora de declaração de tipo | `null` |
| nomeado sobre complex (`type Z complex128`) | `final class Z extends Golang.ComplexBase<Z, Golang.Complex128>`: guarda o valor em `$c` e delega `+ - * /`, `==`, `%v` a ele (`Complex64/128` implementam `Golang.ComplexOps`); conversões por `$c` (`Z(c)`, `complex128(z)` → `z.$c`); chaves de map ordenadas como complex no `%v`. Fixture `namedcomplex` | `Z()` |
| nomeado sobre chan | — ❌ | |

Constantes de tipo básico usam `final`, porque os construtores das classes não
são `const`. Literais inteiros fora de ±2⁵³ vêm por
`fromBigInt(BigInt.parse(...))`, para serem exatos também no JS.

## Structs (`go.GoStruct`)

```go
type Box struct { Name string; Min Point; Owner *Point }
```
```dart
class Box extends go.GoStruct<Box> {
  Box({Golang.String? name, Point? min, Point? owner})
      : name = name ?? Golang.String(), min = min ?? Point(), owner = owner;
  Golang.String name;
  Point min;
  Point? owner;
  @override Box $copy() => Box(name: name, min: min.$copy(), owner: owner);
  @override void $set(Box o) { name = o.name; min.$set(o.min); owner = o.owner; }
  @override List<Object?> get $fields => [name, min, go.Addr(owner)];
}
```

- **Cópia (`coerce`).** Todo valor que flui no Go (inicialização, atribuição,
  argumento, retorno, elemento de literal, `append`, variável de `range`,
  `defer`) passa por `coerce`. Uma struct "não fresca" (variável, campo,
  índice, `*p`) recebe `.$copy()`; literais e resultados de chamada já são
  valores novos.
- **Atribuição.** `x = y` sobre uma struct existente vira `x.$set(y)`
  (in-place), então ponteiros para `x`, `x.f` e `s[i]` continuam válidos.
  `*p = v` vira `p!.$set(v)`.
- **`&x`** de uma struct é o próprio objeto. Ponteiros para struct são
  comparados com `identical`, nunca com o `==` estrutural.
- **Igualdade** campo a campo, via `$fields` (campos ponteiro vêm em
  `go.Addr`, comparados por identidade). Isso serve para `==` e para chaves
  de map.
- **Receptores.** Um receptor valor que o método pode mutar vira uma cópia
  local (`final p = this.$copy();`); caso contrário, `this`. Um receptor
  ponteiro é `this`.
- **Interfaces.** Um ponteiro-para-struct que entra numa interface vira
  `go.Addr(p)`: `*T` nil numa interface não é nil, como no Go.
- Campos em branco (`_`) ficam fora do construtor e da igualdade; no
  `$fields`/`$fieldNames` entram como zero (`_`), para o `%v`/`%+v` do Go
  (fixture `blankfield`). Campo
  embutido é um campo com o nome do tipo; a promoção de campos e métodos está
  em **Embedding** (seção M3, fixture `embed`).

## Slices (`go.Slice`)

| Go | Dart |
|---|---|
| `[]T{a, b}` | `go.Slice<T>.of([a, b], _$eN)` |
| `make([]T, n, c)` | `go.Slice<T>.make(n, c, _$eN)` |
| `s[i]`, `s[i] = v` | `s[i.toInt()]`, `s[i.toInt()] = v` (`toInt()`: saída exata em ±2⁵³ de qualquer inteiro Go; bounds → `runtime error: index out of range`) |
| `s[a:b]`, `s[a:b:c]` | `s.slice(a, b)`, `s.slice(a, b, c)` (compartilha o array) |
| `append(s, x, y)` / `append(s, t...)` | `s.append([x, y])` / `s.appendSlice(t)` |
| `append(b, str...)`, `copy(b, str)` | `b.appendSlice(go.bytesOf(str, _$eN))` / `b.copyFrom(go.bytesOf(str, _$eN))` (os bytes de `[]byte(str)`; string nomeada via `.$str`). Fixture `stringbytes` |
| `len`, `cap`, `copy(d, s)` | `Golang.Int(s.length)`, `Golang.Int(s.capacity)`, `Golang.Int(d.copyFrom(s))` |
| `clear(s)` | `s.clear()`: zera os elementos da janela; struct/array in-place (`&s[i]` guardado vê o zero) |
| `s == nil`, variádico vazio `f()` | `s.isNil`; `f` recebe um slice nil |
| `&s[i]` (não-struct) | `s.addr(i)` (`go.ElemPtr`) |

O `append` escreve no array compartilhado quando cabe e realoca com o
`growslice` do runtime Go (1.25 e 1.26.5, verificado nos dois): `nextslicecap` mais as size classes do
alocador, incluindo o header de malloc acima de 512 bytes em tipos com
ponteiros. O tamanho vem de `go.Elem` (sizeof do amd64, calculado pelo
`layout` do g2d). Testado contra oráculo para 10 tipos de elemento.

⚠️ **Buffer de stack do Go (≥ 1.25).** Um slice que *não escapa* ganha um buffer
de 32 bytes no stack no primeiro `append` (otimização do compilador, que
depende da análise de escape do gc). O runtime modela o caminho de heap. O
`cap` pode então diferir num slice local que nunca escapa. A spec não define
o crescimento de `cap`, e ele muda entre versões do Go.

## Maps (`go.GoMap`)

| Go | Dart |
|---|---|
| `map[K]V{k: v}` / `make(map[K]V)` | `go.GoMap<K, V>.of({k: v}, _$eN)` / `go.GoMap<K, V>(_$eN)` |
| `m[k]` | `m[k]` (zero value se ausente; também em map nil) |
| `[]*P{{1, 2}}` (`&P` elidido em literal de slice/array/map) | o literal de `P` (struct/array é o próprio endereço); ponteiro para slice/map elidido continua `literal-composto:pointer`. Fixture `elidedptr` |
| `v, ok := m[k]` | `var (v, ok) = m.lookup(k);` (também em `var v, ok = m[k]` / `x.(T)` de pacote e locais, fixture `varcommaok`) |
| `m[k] = v` em map nil | `panic: assignment to entry in nil map` |
| `delete(m, k)`, `len(m)`, `m == nil` | `m.delete(k)`, `Golang.Int(m.length)`, `m.isNil` |
| `clear(m)` | `m.clear()` (map nil: nada) |
| `for k, v := range m` | `for (k in m.keysSnapshot()) { if (!m.containsKey(k)) continue; ... }` |

As chaves usam a igualdade das classes intermediárias: NaN nunca é
encontrado, +0 ≡ −0, structs comparadas campo a campo. Chave
ponteiro-para-struct (`map[*T]V`) é o próprio objeto da struct; o map é
criado com `identity: true` (`Map.identity()`), então compara endereços.

## Ponteiros para não-struct (`go.Ptr`)

- Um pré-passo (`find_boxed`) acha as variáveis cujo endereço é tomado. Elas
  passam a morar numa `go.Box<T>` (`final go.Box<T> x = go.Box<T>(init);`, e
  os usos viram `x.value`). Vale para locais, parâmetros, resultados nomeados
  e variáveis de pacote.
- `&x` → a caixa. `&s[i]` → `s.addr(i)`. `&o.f` →
  `go.FieldPtr<O, T>(o, 'f', get, set)`. `new(T)` → `go.Box<T>(zero)`.
- `*p` → `p!.value`. `p == q` usa o `==` de `go.Ptr`, que compara endereços.
- N nomeado não-struct com métodos: a caixa, `&s[i]`, `&o.f` e `new(N)` viram
  `N$Ptr(...)`. `x.M()` com M de receptor ponteiro põe x na caixa e chama
  `x.m()` sobre o `N$Ptr`. `(*N)(nil)` numa interface → `N$Ptr.$nil`.
  Num método de valor que toma o endereço do receptor (`c.inc()` com
  receptor ponteiro, `&c`), o receptor vira uma caixa local inicializada com
  `this` (a cópia do Go): `final N$Ptr c = N$Ptr(go.Box<N>(this));` (fixture
  `recvaddr`).

## Valores e expressões

| Go | Dart |
|---|---|
| `min(x, y, ...)`, `max(...)` | constantes: literal dobrado pelo `go/types`; inteiros e strings: `go.minOf<T>([..], (a, b) => a < b)` / `go.maxOf`; floats: `go.minFloat<T>([..], (v) => v.toDouble())` / `go.maxFloat` (qualquer NaN → NaN; `-0.0` < `+0.0`), devolvendo o próprio operando (tipo nomeado preservado) |
| expressão constante (incl. `iota`, constantes importadas e constantes locais de função) | literal do valor exato calculado pelo `go/types`; `const` local não gera declaração (cada uso já é o literal); constante de pacote sem tipo mantém o nome só onde o uso tem o tipo padrão dela, senão vira o literal no tipo do uso (`[...]uint32{IV0}`) |
| literal string | `Golang.String.fromDart('...')`; UTF-8 inválido → `go.stringOfBytes(const [...])` |
| `a / b`, `a % b` inteiros | `a ~/ b`, `a % b` (as classes implementam o truncamento do Go) |
| `a &^ b`, `^x` | `a.andNot(b)`, `~x` |
| shift | a contagem vira `int` por `go.shiftCount` (negativa → panic) |
| `x++`, `x op= y` | `x += Golang.T(1)`, `x op= y` (`/=` → `~/=`; `&^=` → `x = x.andNot(y)`) |
| `m[k] op= y`, `s[i] &^= y`, `x.f &^= y` (sem operador Dart equivalente) | leitura e escrita: `m[k] = m[k] << n`, `s[i] = s[i].andNot(y)`; só com alvo puro (identificadores, constantes, campos, índices), senão `Unsupported` `opassign-impuro` (o Go avalia o alvo uma vez). Fixture `opassign` |
| `any(x)`, `I(x)` (conversão explícita para interface) | o mesmo `coerce` da atribuição a interface |
| `T(f)`, `int64(x)`, `float64(x)` com parâmetro de tipo numérico | `$T.ofFloat!(f)` (descritores numéricos geram `ofFloat`, com as regras de FloatToInt/FloatToFloat); `Cls.from(go.realToInt(x, w, signed))`, `go.realToFloat(x, F.fromInt64, F.fromUint64, F.new)` (um arredondamento só). Fixture `typeparamconv` |
| `[N]T(s)` (Go 1.20) | `go.sliceToArray(s, N)`: cópia, pânico do Go se `len(s) < N` (fixture `slicetoarray`) |
| `B(a)` com structs de mesmos campos (tags não contam; nomeadas ou anônimas) | `switch (<cópia de a>) { final $t => B(x: $t._x, ...) }`. Fixture `structconv`. Conversão não suportada: `Unsupported` `conversao:<de>-<para>` (categoria básica ou kind do subjacente, `named-` se nomeado) |
| conversões numéricas | inteiro → inteiro `T.from(x)` (trunca os 64 bits `$hi`/`$lo`); inteiro → float `Float64.fromInt64(Int64.from(x))` (arredondamento único); float → inteiro `T.from(f.toInteger(w, signed: s))` pelas regras do gc/amd64 (`toInteger`) |
| `len(s)`, `s[i]`, `s[a:b]` em string | `Golang.Int(s.length)` (como índice ou contagem, só `s.length`: `Operands.dart_length`), `Golang.Uint8(s[i])`, `s.slice(a, b)` (bytes) |
| `p.f` com `p *T` | `p!.f` (nil → `runtime error: invalid memory address or nil pointer dereference`) |
| `f(x)` com `f` variável de função | `f!(x)` (função nomeada: `f(x)`, classe chamável) |
| `f(g())` com g de vários resultados | `(switch (g()) { (final $t1, final $t2) => f($t1, $t2) })` |
| method value `x.M` (receptor valor) | `x.$copy().m` (liga uma cópia feita agora, como o Go) |
| method expression `T.M` / `(*T).M` | `(T $0, A $1) => $0.m($1)` (seleção normal: sentinela nil, promoção) |
| literal indexado `[]T{2: x, y}`, `[...]T{5: z}` | elementos em ordem de índice, lacunas com o zero value |
| `[]byte(s)`, `[]rune(s)`, `string(b)`, `string(rs)` | `go.bytesOf`, `go.runesOf`, `go.stringOfByteSlice`, `go.stringOfRunes` (decodificação UTF-8 do Go: inválido → U+FFFD, largura 1; runa inválida → U+FFFD) |
| `T(nil)` | zero value de T |
| `panic(v)` / `recover()` | `throw go.Panic(v)` / `go.recover()` |
| precedência | parênteses onde a precedência Dart difere da Go |

## Statements

| Go | Dart |
|---|---|
| `x := e` / `var x T = e` / `var x T` | `T x = e;` (tipo sempre explícito) / `T x = <zero>;` |
| `a, b := f()` (todas novas) / `a, b = b, a` | `var (a, b) = f();` / `(a, b) = (b, a);` |
| declaração mista, alvos não-identificador, struct existente, variável em caixa | `final $t = ...; a = $t.$1; ...` (com `$set` para structs) |
| resultados nomeados + `return` nu | locais inicializados no zero + `return (q, r);`; resultado nomeado que o corpo nunca usa (sem `return` nu nem `defer`) não vira local (o Go aceita; o Dart acusaria local não usada) |
| `if init; cond`, `for`, `for cond`, `for {}` | `{ init; if }`, `for (...)`, `while (cond)`, `while (true)` |
| `range` sobre slice / map / int | índice sobre a referência; `keysSnapshot` + `containsKey`; contador |
| `range` sobre string | `for (var i = 0, w = 0; i < s.length; i += w)` com `s.decodeRune(i)` (runa, largura), igual ao `utf8.DecodeRune` |
| `switch` / `switch {}` / type switch | cadeia `if/else` num bloco; `break` sem rótulo que sai do switch → `break $tN;` (bloco rotulado; a pilha de alvos distingue switch de laço) |
| `fallthrough` | seleção do case (`$c`) seguida dos corpos em sequência (`if ($c == i)`); `fallthrough` → `$c = i + 1` na ordem do fonte, inclusive para o `default` no meio |
| rótulos, `break L`, `continue L` | rótulo no laço Dart |
| `for k, v := range seq` (seq func, Go 1.23) | `seq((K k, V v) { if ($done) go.rangeFuncContinued(); corpo; return true; })`: `continue` → `return true`; `break` → `$done = true; return false`; `return`, `break L`/`continue L` para fora da closure gravam um código em `$st` (valores em `$rv`) e são refeitos depois da chamada; rótulos declarados no corpo ficam nativos; func literal dentro do corpo isola (fixture `rangefunc`) |
| `defer f(a)` | `{ final $t = a; $d.defer(() { f($t); }); }`, com o corpo em `try`/`catch`/`finally` de `go.Defers` |
| `defer f()` com f de tipo func nomeado | o closure em `f.$f` (pode receber `$rd` e recuperar); assinatura do subjacente (fixture `defernamed`) |
| `defer delete(m, k)`, `defer panic(v)`, `defer clear(s)`... | mesmo caminho, com a chamada do builtin no closure (fixture `deferbuiltin`); `defer recover()` → `Unsupported` `defer-recover` (no Go não recupera) |
| `go`, `select`, range sobre chan/func | ❌ (M4) |
| `goto` | ❌ exigiria reescrever a função como máquina de estados. Medido no grafo do kubo (`docs/audit.md`, `branch:goto`): 54 ocorrências em 14 pacotes, 3 na fronteira (ex. gonum `mathext/internal/cephes`); decisão a rever se entrar no caminho |

`defer`: os argumentos (e o receptor) são avaliados no `defer`. As chamadas
rodam em ordem LIFO no `finally`, e um panic num defer substitui o anterior.
O `finally` devolve os resultados, que os defers podem ter alterado. Os
erros de runtime do Dart viram os `runtime.Error` do Go com as mesmas
mensagens (`go.panicValue`): divisão por zero, índice e fatia fora do
intervalo, nil pointer, escrita em map nil.

`recover()` só recupera quando chamado **diretamente** pela função adiada.

- Toda função, método ou func literal que chama `recover()` no próprio
  corpo ganha o parâmetro oculto opcional `{go.Defers? $rd}`, e o
  `recover()` ali vira `go.recover($rd)`.
- Só o `defer` repassa o frame: `f(args, $rd: $d)` quando o callee é
  conhecido. Para uma variável de função, o teste em runtime é
  `fv is R Function(A, {go.Defers? $rd})`.
- Um helper chamado pela função adiada, ou uma closure aninhada, não recebe
  o frame e devolve nil; o panic segue, como no Go.
- O `main` não recebe o parâmetro, porque nunca é adiado.

## Stdlib (shims em `golib_dart/`)

| Símbolo | Shim |
|---|---|
| `fmt.Println` | `fmt.println(go.Slice<Object?>)` → `(Golang.Int, GoError?)`, com os bytes exatos |
| `fmt.Print` | `fmt.print(go.Slice<Object?>)` → `(Golang.Int, GoError?)` (espaçamento do `Sprint`) |
| `fmt.Sprint` | `fmt.sprint(go.Slice<Object?>)` → `Golang.String` |
| `Error()`/`String()` no fmt | só se o método está no method set do valor impresso: struct por valor na interface (ou campo aninhado) usa os de receptor valor (`String()` de `*T` não vale para `T`; fixture `fmtmethodset`) |
| `fmt.Sprintln` | `fmt.sprintln(go.Slice<Object?>)` → `Golang.String` (mesmo formato do `Println`) |
| `fmt.Formatter`, `fmt.State` | interfaces de shim; o printer implementa `State` (`Write`, `Width`, `Precision`, `Flag`) e chama `format(state, verb)` antes de `Error`/`String`, para todo verbo menos `%T`/`%p`, com receptor nil e `%!v(PANIC=Format method: ...)` como o Go (fixture `fmtformatter`) |
| `%v` | `<nil>`; wrappers pelo `toString` (floats = `FormatFloat 'g'`); structs `{a b}`; `&{...}`; slices `[a b]`; maps `map[k:v]` com as chaves na ordem do `internal/fmtsort` (nil primeiro, números, strings, bool, complex, structs e arrays campo a campo); ⚠️ ponteiros ficam na ordem de inserção e chaves interface de tipos diferentes vão pelo nome do tipo, porque o Go ordena ambos por endereço de memória (para tipos, o layout de símbolos do linker, que muda com os pacotes linkados; medido no gc 1.25, não há regra reproduzível); ponteiros aninhados como endereço |
| `fmt.Printf`, `Sprintf` | `fmt.printf(format, go.Slice<Object?>)` / `fmt.sprintf(...)`: porte do `doPrintf`/`format.go` — verbos `v d b o O x X c q U e E f F g G s t T w %`, flags `+ - # 0 ␠`, largura/precisão (inclusive `*`), `%!verbo(tipo=valor)`, `(MISSING)`, `%!(EXTRA ...)`, `BADWIDTH`/`BADPREC`/`NOVERB`; o verbo se aplica a cada elemento de slice/array/map/struct; `Error()`/`String()` para `v s q x X`. Floats com precisão: dígitos do binário exato, meio-para-par. `%q`/`%+q`/`%#U` usam o `unicode.IsPrint` exato do Go (tabela gerada em `golib_dart/lib/src/unicode/isprint.dart` por `tool/gen_isprint.go`, conferida pelo teste). `%+v` escreve os nomes dos campos (`$fieldNames` gerado em toda struct; embutido = nome do tipo), inclusive aninhados; índice explícito `[n]` como o `argNumber` do Go (`BADINDEX`, sem `EXTRA` quando reordenado, `%w` ordenados no `Errorf`). Endereços (`%p`, `%#p`, `%v` de `*T` não-struct, func e ponteiro aninhado): `0xc0` + 8 hex, ⚠️ estável por objeto (`Box` por identidade, `&s[i]`/`&o.f` por dono + posição, slice = `&s[0]`), não o endereço do Go (que nem o Go reproduz; fixture `fmtaddr` compara a forma). ❌ `%#v`, `%b`/`%x` e `#` em float, verbo ≠ `v` em complex, `%#q` de runa, `%T`/`%!(EXTRA)` de slice/array/map/func/chan/ponteiro não-struct: com formato constante e tipo estático conhecido o g2d recusa na transpilação (`fmt-verbo:<caso>`, `g2d/behaviors/fmtcheck.py`); ⚠️ operando interface, `args...` ou formato não constante só se descobrem em runtime, onde o shim lança `UnimplementedError` (nunca formata diferente) |
| `fmt.Errorf` | `fmt.errorf(...)` → `go.ErrorString` (`*errors.errorString`) sem `%w`; `go.WrapError` (`*fmt.wrapError`, `unwrap()`) com um; `go.WrapErrors` com vários (`src/runtime/errors.dart`, reusado pelo futuro shim `errors`) |
| símbolo que o shim não tem | `Unsupported` `shim-simbolo:<pkg>.<nome Dart>` (lista em `g2d/shim_symbols.json`, gerada do dartast por `python -m g2d shims`; o teste de golden confere se está em dia) |
| `math` | `naN()` com os bits do Go (`0x7ff8000000000001`); `sqrt`, `floor`, `ceil`, `trunc`, `abs`, `max`, `min`, `inf`, `isInf`, `isNaN`, `signbit`, `copysign`, `float32bits`/`float64bits`/`...frombits`, com oráculo bit a bit; as constantes são dobradas. ⚠️ payload de NaN não é portável (o JS canoniza). ❌ transcendentais (`Exp`, `Log`, `Pow`...): o `go run` amd64 usa assembly com outro algoritmo (`TODO/P1-shim-math-transcendentais.md`) |
| `math/bits` | todas as funções usadas pelo grafo, sobre as metades de 32 bits dos fixed_types (`Add/Sub/Mul/Div(64)` em records; `Div64` com os pânicos do Go) |
| `errors` | `new$` → `go.ErrorString` (identidade); `is$`, `as`, `unwrap`, `join` (`go.JoinError`), `asType` (Go 1.26), `errUnsupported`: porta de `wrap.go`/`join.go`. A cadeia é percorrida por interfaces do runtime que o g2d declara em todo tipo cujo method set tem a assinatura exata (`Unwrap() error` → `go.Unwrapper`, `Unwrap() []error` → `go.MultiUnwrapper`, `Is(error) bool` → `go.ErrorIs`, `As(any) bool` → `go.ErrorAs`), respeitando o method set do valor (`go.goHasMethod`); `Is` só compara com `==` alvo comparável (`go.goComparable`). `As` escreve no alvo com `Ptr.$assignIfIs` (genéricos reificados: `v is T`; struct por valor não serve a `*S`), ou `$set` quando o alvo é a própria struct; pânicos do Go para alvo nil/não ponteiro/não error. Fixture `errorschain` |
| `encoding/binary` | `littleEndian`/`bigEndian` (`ByteOrder`): `uint16/32/64`, `putUint16/32/64`, acessando o último índice primeiro (mesmo pânico de bounds do Go) |
| `crypto/subtle` | `xorBytes` (pânicos `dst too short` / `invalid overlap`, via `go.inexactOverlap`), `constantTimeCompare` |
| `bytes` | `equal`, `compare`, `indexByte`, `index`, `count`, `hasPrefix`, `hasSuffix`, `lastIndexByte`, `split` (pedaços com cap limitado, `s[:m:m]`), `trimLeft` (vazio → nil), `trimRight` (vazio continua vazio) |
| `strings` | `contains`, `containsRune`, `index`, `indexByte`, `lastIndex`, `count`, `hasPrefix`/`hasSuffix`, `trimPrefix`/`trimSuffix`, `trimFunc`/`trimLeftFunc`/`trimRightFunc`, `join`, `split`/`splitN` (cap do resultado igual ao Go); UTF-8 inválido decodifica como o Go. ❌ `Builder`, `Reader` (`TODO/P1-design-structs-de-shim.md`) |
| `strconv` | inteiros: `itoa`, `formatInt`, `formatUint`, `parseInt`, `parseUint`, `atoi` (porta de `internal/strconv`, `(valor, GoError?)`), erros `*strconv.NumError` (classe privada: `Error()` com `%q` do `fmt`, `Unwrap()`), `errRange`/`errSyntax`; oráculo com ~2500 casos. ❌ floats, `Quote`/`Unquote`, `Append*` |
| tipo struct de shim (`strings.Builder`, `bytes.Buffer`) | classe do shim `extends go.GoStruct<T>`, com `$copy`/`$set`/`$fields`/`$valueMethods`/`$ptrMethods`: o g2d a trata como struct de outro pacote (zero `strings.Builder()`, cópia, métodos no próprio objeto, `go.Elem` com `.new`) sem olhar os campos não exportados do dump. Porta do Go com o mesmo crescimento (`Cap`) e checagens (cópia de Builder, `Truncate`...). Fixtures `stringsbuilder`, `bytesbuffer` |
| `io` | parcial: `eof`, `errUnexpectedEOF`, `errShortWrite`...; `Reader`, `Writer`, `ByteReader`, `ByteWriter`, `StringWriter` como interfaces de shim (`SHIM_INTERFACES`: tipo gerado com `Write([]byte) (int, error)` declara `implements io.Writer`). Var de shim é `final` Dart (sem caixa) |
| `time` | parcial: `Duration` (classe sobre `Int64Base`, a mesma forma de `type N int64` gerado; `String()` portado do Go, `Seconds`/`Minutes`/`Hours`/`Round`/`Truncate`/`Abs`/...); as constantes (`time.Second`) dobradas em `time.Duration(n)`. ❌ `Time`, `Now`, timers (`TODO/P0-shim-time.md`). Fixture `timeduration` |
| `sync` | `Mutex`, `RWMutex`, `Once`, `WaitGroup`, `Pool` (campo `New` → `new$`), `Map$` (`sync.Map`; chave com igualdade de interface), `Cond`/`NewCond`, `Locker` (interface de shim), `OnceFunc`/`OnceValue`/`OnceValues`, como structs de shim. Sem goroutines (M4) a semântica é determinística: esperar o que só outra goroutine faria (Lock travado, `Wait` com contador > 0, `Cond.Wait`) é o deadlock do Go (`go.fatal`, sem recover); unlock de destravado é o fatal error do Go. ⚠️ `Map.Range` em ordem de inserção; `Pool` nunca é esvaziado pelo GC; `%v` de `Map`/`Pool`/`Cond` lança. ❌ `WaitGroup.Go` (M4). Fixture `syncshim` |
| `sync/atomic` | `Int32`/`Int64`/`Uint32`/`Uint64`/`Uintptr`/`Bool`/`Value`/`Pointer[T]` (T struct) como structs de shim (`%v` como o Go: `{{} {} 5}`); `Add*`/`Load*`/`Store*`/`Swap*`/`CompareAndSwap*` sobre `go.Ptr`. Num isolate só são leituras/escritas simples (M4 decide com goroutines). Variantes `*Pointer` (unsafe) → `unsafe:Pointer`. Fixture `syncatomic` |
| `fmt.Fprint`, `Fprintln`, `Fprintf` | `fmt.fprint(w, args)`: a mesma formatação, num só `w.write(bytes)` |
| `sort` | `Interface` (interface de shim: tipo gerado que a satisfaz declara `implements sort.Interface`), `sort`, `stable`, `isSorted`, `slice$`, `sliceStable`, `search`, `ints`, `strings`, `float64s`: porta exata do pdqsort/stable do Go (mesmas chamadas a `Less`/`Swap`, mesmo resultado para iguais); swap de slice via `go.swapElems` (copia struct/array antes) |

## Tipos nomeados, interfaces, embedding, genéricos (M3)

**Tipos nomeados sobre básicos.** Uma classe gerada estende a base de
`fixed_types`: a base da largura para inteiros (`Int32Base<S>`,
`Uint64Base<S>`...; o mesmo caminho rápido do subjacente), `FloatBase<S>` ou
`StringBase<S>`. Os operadores herdados
devolvem o próprio tipo (`c*9/5` continua `Celsius`), e os métodos Go viram
métodos da classe. As conversões usam os construtores:
`Celsius(x.toDouble())`, `ID.from(x)`, `Name(s.$str)`.

**Interfaces.**
- Uma interface Go vira `abstract mixin class I { R m(A); }` (embutidas em
  `implements`). Interfaces de restrição (uniões) não geram classe; viram
  bound de genérico.
- A satisfação é estrutural no Go e nominal no Dart. O goast calcula
  `implements` com `types.Implements`, e a classe gerada declara
  `implements I, go.GoError, fmt.Stringer`.
- Uma struct **por valor** em interface é uma cópia marcada (`$isValue`); um
  **ponteiro** é o próprio objeto. Os métodos podem ser chamados direto
  (`s!.area()`, com nil → panic).
- `x.(T)` → `go.assertType<T>(x, iface, 'main.T', struct: true|false)`;
  `x.(I)` → `go.assertIface<I>(x, 'main.I', const [métodos])`. As mensagens
  de falha são as do Go (`interface conversion: main.Point is not main.Shape:
  missing method Area`).
- Comma-ok → `go.tryType`/`go.tryIface`. Type switch → cadeia de
  `go.isType`/`is`, com a variável ligada por case.
- `==` entre interfaces → `go.ifaceEq` (identidade para ponteiros).
- `fmt` usa `error` e depois `Stringer` antes da forma estrutural.
- **Ponteiro nil tipado.** Cada struct tem a sentinela
  `static final T $nil` (`$nilPtr = true`), que representa `(*T)(nil)`.
  - Na conversão para interface: `p ?? T.$nil` (para `*int` etc.,
    `const go.NilPtr<E>()`). Assim `i != nil`, e `i == p` compara via
    `go.ifaceEq`.
  - Métodos com receptor ponteiro ligam o receptor a
    `final T? c = $nilPtr ? null : this;`: rodam com receptor nil, e
    `c.x` dá o panic de nil.
  - Métodos com receptor valor começam com `if ($nilPtr) go.nilDeref();`.
  - A chamada direta `p.M()` com receptor ponteiro vira `(p ?? T.$nil).m()`,
    válida com `p` nil, como no Go.
  - `x.(*T)`, comma-ok e type switch devolvem `null` para a sentinela; o fmt
    imprime `<nil>` (ou chama `String()`/`Error()`, e em caso de panic
    imprime `<nil>`, como o `handleMethods`).

**Embedding.**
- O campo embutido é um campo comum.
- Seleções promovidas seguem o caminho do go/types (`d.base.id`,
  `d.logger!.prefix`, nil → panic).
- Para satisfazer interfaces, o method set promovido de um tipo embutido `E`
  vira um **`mixin E$Promote`** (ou `E$PromotePtr`), gerado uma vez por
  tipo: forwarders `m() => $E.m()` que mantêm o valor embutido como
  receptor. A struct usa `with E$Promote` quando todo o method set de `E` é
  promovido. Com sombreamento ou ambiguidade, os forwarders vão inline.

**Genéricos (dicionários).**
- `func F[T C](x T)` → `T f<T extends B>(go.Elem<T> $T, T x)`. O dicionário
  `go.Elem<T>` dá o zero value, `make([]T)`, o `sizeof` do `growslice` e
  `T(n)` (`ofInt`).
- Bounds: união só de inteiros → `IntBase<T>`; inteiros|floats →
  `GoReal<T>`; `cmp.Ordered` → `GoOrdered<T>`; strings → `StringBase<T>`;
  interface com métodos → a interface (com `comparable` embutido também:
  o goast lista essas interfaces no `implements`, fixture `comparablekey`);
  `any`/`comparable` → nenhum. Interfaces de constraint embutidas são
  expandidas (`constraints.Integer` = `Signed | Unsigned`).
- Core type composto (`S ~[]E`, `M ~map[K]V`): o subjacente de S é `[]E`
  (índice, `len`, `range`, `append` e fatiamento direto) e o bound é
  `go.Slice<E>`; o que produz um valor de S (`append(s, x)`, `s[a:b]`) passa
  por `$S.rewrapOf(v)`, que reembrulha no slice nomeado (descritores de
  composto nomeado geram `rewrap`). Constante num contexto de T vira
  `$T.ofInt!(...)`/`$T.ofFloat!(...)`. Fixture `constraintcore`. Sem bound
  comum (união mista, ponteiro no core, união de funcs) → `constraint:<forma>`
  (`TODO/P1-construcao-constraint-sem-bound.md`).
- `/` sobre `T` → `$quo` (truncado nos inteiros, IEEE nos floats).
- A chamada instancia explicitamente, `f<Golang.Int>(_$e0, ...)`, com os
  argumentos de tipo vindos do goast (`$inst`), inclusive `f[int](x)` e
  `pkg.New[K, V](...)` escritos no Go. `f[int]` como valor (sem chamada) vira
  `((Golang.Int p0) => f<Golang.Int>(_$e0, p0))` (fixture `explicitinst`).
- Structs genéricas: `class Stack<T> extends go.GoStruct<Stack<T>>`, com os
  dicionários como primeiros parâmetros do construtor.
- Genéricos sobre slice/map/func: `final class Set<T> extends go.GoMap<T, ...>`
  (`List<T> extends go.Slice<T>`, `Mapper<T>` chamável), construtor
  `Set($T, v)`; `*Set[T]` com métodos → `Set$Ptr<T>`, que lê os dicionários do
  valor apontado e cria a sentinela nil no uso (estático não vê `T`). Fixture
  `genericnamed`. Genérico sobre básico/array → `generico:<kind>`.
- Interfaces genéricas: `abstract mixin class Key<K>`; como constraint,
  bound F-limitado (`K extends Key<K>`, `N extends NodeID<K>`). Quem
  implementa declara a instância (`implements Key<k8>`), que o goast deduz
  casando os métodos da interface com os do tipo (o parâmetro na assinatura
  de `Xor(K) K` liga ao tipo na mesma posição de `Xor(k8) k8`) entre as
  interfaces genéricas do pacote e dos imports diretos. Tipo genérico
  implementa com os próprios parâmetros (`List<K> implements sort.Interface`,
  `_lru$<K, V> implements Cache<K, V>`). Fixture `genericiface`.

**Arrays.** `go.GoArray<T>` estende `go.GoValue`, como `GoStruct`: cópia em
atribuição, argumento e range; `$set` in-place; `==`/hash elemento a elemento
(serve de chave de map); `a[i:j]` compartilha o armazenamento; `&a[i]` →
`ElemPtr`; `*[N]T` é o próprio objeto.

## Interfaces e reflexão (restrição de projeto)

Resolvido pela regra "um tipo Go = uma classe Dart". `Golang.Int` e
`Golang.Int64` são classes distintas, e os tipos nomeados têm a sua própria.
`byte`/`uint8` e `rune`/`int32` são aliases no próprio Go e continuam
`typedef`. Os testes de tipo usam `is T` (reificado). Para o M5, a reflexão
pode indexar descritores por `runtimeType` das classes geradas (confiável nas
três plataformas).

## Código gerado

- Cabeçalho `// Code generated by g2d ... DO NOT EDIT.` e
  `ignore_for_file: unused_element, unused_field, dead_code, unnecessary_non_null_assertion`.
  O Go aceita esses casos; o Dart só avisaria.
- Os descritores `const _$eN = go.Elem<T>(...)` ficam no fim da library.
- A saída é canonicalizada por `dart format` e precisa passar em
  `dart analyze --fatal-infos`.
