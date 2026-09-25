# Mapping spec Go → Dart

Correspondência semântica implementada pelo `g2d` (fontes: `g2d/mapping.py`,
`g2d/emit.py`, runtime em `golib_dart/`). Toda construção fora destas tabelas
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
| inteiros de largura fixa, `int`/`int64` | `Golang.Int8` … `Golang.Int64`, `Golang.Uint*` (`fixed_types`) | M2 | ✅ |
| `float32`/`float64`, `complex*` | `Golang.Float32/64`, `Golang.Complex64/128` | M2 | ✅ |
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
| tipos nomeados sobre básicos | classe gerada sobre `Golang.IntBase/FloatBase/StringBase<S>` | M3 | ✅ |
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

## Unidade de compilação

| Go | Dart | |
|---|---|---|
| pacote (todos os arquivos) | uma library `lib/<import path>.dart` | ✅ |
| `import "fmt"` | `import 'package:golib_dart/fmt.dart' as fmt;` (só se usado no Dart) | ✅ |
| universo e runtime | `import 'package:golib_dart/builtin.dart' as go;` | ✅ |
| tipos básicos | `import 'package:golib_dart/fixed_types/golang.dart' as Golang;` | ✅ |
| `func main` | `void main() { go.runMain(() { ... }); }`: panic não recuperado vai para o stderr com exit 2 | ✅ |
| import de pacote não-stdlib | — | ❌ (M2: grafo) |
| import `_` / `.` | — | ❌ |

## Identificadores

| Go | Dart | Limite |
|---|---|---|
| tipo exportado `Greeter` | `Greeter` (tipo `Golang` → `Golang$`) | |
| tipo não exportado `point` | `_point` | |
| func/var/const/campo/método exportado `HTTPServer` | `httpServer` (lowerCamel ciente de siglas) | ⚠️ `FOO` e `Foo` no mesmo escopo colidem |
| idem não exportado `add` | `_add` (privado da library = do pacote) | |
| local/parâmetro | nome Go; se repetido na função ou igual a um nome de library → `x$1` | |
| palavra reservada Dart (`new`, `in`, ...) | sufixo `$` (`new$`) | |
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
| nomeado sobre slice/map/func/bool/complex, chans, interface anônima com métodos | — ❌ | |

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
- Campos em branco (`_`) ficam fora do construtor e da igualdade. Embedding é
  tratado como campo comum; a promoção é ❌.

## Slices (`go.Slice`)

| Go | Dart |
|---|---|
| `[]T{a, b}` | `go.Slice<T>.of([a, b], _$eN)` |
| `make([]T, n, c)` | `go.Slice<T>.make(n, c, _$eN)` |
| `s[i]`, `s[i] = v` | `s[i]`, `s[i] = v` (bounds → `runtime error: index out of range`) |
| `s[a:b]`, `s[a:b:c]` | `s.slice(a, b)`, `s.slice(a, b, c)` (compartilha o array) |
| `append(s, x, y)` / `append(s, t...)` | `s.append([x, y])` / `s.appendSlice(t)` |
| `len`, `cap`, `copy(d, s)` | `Golang.Int(s.length)`, `Golang.Int(s.capacity)`, `Golang.Int(d.copyFrom(s))` |
| `s == nil`, variádico vazio `f()` | `s.isNil`; `f` recebe um slice nil |
| `&s[i]` (não-struct) | `s.addr(i)` (`go.ElemPtr`) |

O `append` escreve no array compartilhado quando cabe e realoca com o
`growslice` do runtime Go 1.25: `nextslicecap` mais as size classes do
alocador, incluindo o header de malloc acima de 512 bytes em tipos com
ponteiros. O tamanho vem de `go.Elem` (sizeof do amd64, calculado pelo
`layout` do g2d). Testado contra oráculo para 10 tipos de elemento.

⚠️ **Buffer de stack do Go 1.25.** Um slice que *não escapa* ganha um buffer
de 32 bytes no stack no primeiro `append` (otimização do compilador, que
depende da análise de escape do gc). O runtime modela o caminho de heap. O
`cap` pode então diferir num slice local que nunca escapa. A spec não define
o crescimento de `cap`, e ele muda entre versões do Go.

## Maps (`go.GoMap`)

| Go | Dart |
|---|---|
| `map[K]V{k: v}` / `make(map[K]V)` | `go.GoMap<K, V>.of({k: v}, _$eN)` / `go.GoMap<K, V>(_$eN)` |
| `m[k]` | `m[k]` (zero value se ausente; também em map nil) |
| `v, ok := m[k]` | `var (v, ok) = m.lookup(k);` |
| `m[k] = v` em map nil | `panic: assignment to entry in nil map` |
| `delete(m, k)`, `len(m)`, `m == nil` | `m.delete(k)`, `Golang.Int(m.length)`, `m.isNil` |
| `for k, v := range m` | `for (k in m.keysSnapshot()) { if (!m.containsKey(k)) continue; ... }` |

As chaves usam a igualdade das classes intermediárias: NaN nunca é
encontrado, +0 ≡ −0, structs comparadas campo a campo. Chave
ponteiro-para-struct é ❌.

## Ponteiros para não-struct (`go.Ptr`)

- Um pré-passo (`find_boxed`) acha as variáveis cujo endereço é tomado. Elas
  passam a morar numa `go.Box<T>` (`final go.Box<T> x = go.Box<T>(init);`, e
  os usos viram `x.value`). Vale para locais, parâmetros, resultados nomeados
  e variáveis de pacote.
- `&x` → a caixa. `&s[i]` → `s.addr(i)`. `&o.f` →
  `go.FieldPtr<O, T>(o, 'f', get, set)`. `new(T)` → `go.Box<T>(zero)`.
- `*p` → `p!.value`. `p == q` usa o `==` de `go.Ptr`, que compara endereços.

## Valores e expressões

| Go | Dart |
|---|---|
| expressão constante (incl. `iota` e constantes importadas) | literal do valor exato calculado pelo `go/types` |
| literal string | `Golang.String.fromDart('...')`; UTF-8 inválido → `go.stringOfBytes(const [...])` |
| `a / b`, `a % b` inteiros | `a ~/ b`, `a % b` (as classes implementam o truncamento do Go) |
| `a &^ b`, `^x` | `a.andNot(b)`, `~x` |
| shift | a contagem vira `int` por `go.shiftCount` (negativa → panic) |
| `x++`, `x op= y` | `x += Golang.T(1)`, `x op= y` (`/=` → `~/=`; `&^=` → `x = x.andNot(y)`) |
| conversões numéricas | construtores das classes; float → inteiro pelas regras do gc/amd64 (`toInteger`) |
| `len(s)`, `s[i]`, `s[a:b]` em string | `Golang.Int(s.length)`, `Golang.Uint8(s[i])`, `s.slice(a, b)` (bytes) |
| `p.f` com `p *T` | `p!.f` (nil → `runtime error: invalid memory address or nil pointer dereference`) |
| `f(x)` com `f` variável de função | `f!(x)` |
| `panic(v)` / `recover()` | `throw go.Panic(v)` / `go.recover()` |
| precedência | parênteses onde a precedência Dart difere da Go |

## Statements

| Go | Dart |
|---|---|
| `x := e` / `var x T = e` / `var x T` | `T x = e;` (tipo sempre explícito) / `T x = <zero>;` |
| `a, b := f()` (todas novas) / `a, b = b, a` | `var (a, b) = f();` / `(a, b) = (b, a);` |
| declaração mista, alvos não-identificador, struct existente, variável em caixa | `final $t = ...; a = $t.$1; ...` (com `$set` para structs) |
| resultados nomeados + `return` nu | locais inicializados no zero + `return (q, r);` |
| `if init; cond`, `for`, `for cond`, `for {}` | `{ init; if }`, `for (...)`, `while (cond)`, `while (true)` |
| `range` sobre slice / map / int | índice sobre a referência; `keysSnapshot` + `containsKey`; contador |
| `switch` / `switch {}` | cadeia `if/else`; `break`/`fallthrough` ❌ |
| rótulos, `break L`, `continue L` | rótulo no laço Dart |
| `defer f(a)` | `{ final $t = a; $d.defer(() { f($t); }); }`, com o corpo em `try`/`catch`/`finally` de `go.Defers` |
| `go`, `select`, `goto`, range sobre string/chan/func | ❌ |

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
| `fmt.Sprint` | `fmt.sprint(go.Slice<Object?>)` → `Golang.String` |
| `%v` | `<nil>`; wrappers pelo `toString` (floats = `FormatFloat 'g'`); structs `{a b}`; `&{...}`; slices `[a b]`; maps `map[k:v]` com chaves ordenadas; ponteiros aninhados como endereço |
| `math.NaN`, `math.Copysign` | `math.naN()`, `math.copysign(f, s)`; as constantes de `math` são dobradas |

## Tipos nomeados, interfaces, embedding, genéricos (M3)

**Tipos nomeados sobre básicos.** Uma classe gerada estende a base de
`fixed_types` (`IntBase`/`FloatBase`/`StringBase<S>`). Os operadores herdados
devolvem o próprio tipo (`c*9/5` continua `Celsius`), e os métodos Go viram
métodos da classe. As conversões usam os construtores:
`Celsius(x.toDouble())`, `ID.fromBigInt(x.toBigInt())`, `Name(s.$str)`.

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
  interface com métodos → a interface; `any`/`comparable` → nenhum.
- `/` sobre `T` → `$quo` (truncado nos inteiros, IEEE nos floats).
- A chamada instancia explicitamente, `f<Golang.Int>(_$e0, ...)`, com os
  argumentos de tipo vindos do goast (`$inst`).
- Structs genéricas: `class Stack<T> extends go.GoStruct<Stack<T>>`, com os
  dicionários como primeiros parâmetros do construtor.

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
