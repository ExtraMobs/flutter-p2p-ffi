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
| descritor de tipo (tamanho, ponteiros, zero, por valor) | `go.Elem<T>` (`const`, um por tipo; `value: true` em struct/array por valor: só esses o `copyOf` copia e o `storeAt` sobrescreve in-place, ponteiro e interface copiam a referência; fixture `ptrelems`) | M3/M5 | ✅ (base da reflexão) |
| `defer` / `recover` / `panic` / erros de runtime | `go.Defers`, `go.Panic`, `go.RuntimeError`, `go.runMain` | M3 | ✅ |
| saída padrão em bytes | `writeStdout` (import condicional io/web) | M2 | ✅ |
| identidade de tipo em runtime (`int` × `int64` × nomeado) | uma classe Dart por tipo Go (`Golang.Int` ≠ `Golang.Int64`) + `GoTyped` (`$goType`, `$methods`) | M3 | ✅ |
| tipos nomeados sobre básicos | classe gerada sobre `Golang.<Largura>Base/FloatBase/StringBase<S>` | M3 | ✅ |
| interfaces, type assertion, type switch | `abstract mixin class` + `implements` (go/types; entre pacotes, ver "Interfaces entre pacotes (D8)") + `go.assertType/assertIface/tryType/isType`; `x.(func(...))` comma-ok com o tipo anulável (o zero é nil). Tipo func sem nome (`x.(func(...))`/`case func(...):`) usa `go.Func` (linha abaixo): identidade exata pelo nome Go do tipo, não `is` (o Dart testa subtipo entre funcs: retorno covariante com `void` no topo, parâmetros contravariantes). Tipo func nomeado (`type Op func(...)`) já é nominal pela classe gerada, sem passar por `go.Func` | M3 | ✅ |
| tipo func sem nome guardado numa interface | `go.Func` embrulha a closure com o nome Go do tipo (o de `%T`); `isFuncType`/`assertFunc`/`tryFunc`/`unwrapFunc` comparam o nome em vez de `is`. ⚠️ parâmetro de tipo com union de funcs (`~func() \| ~func() error`, ex. go.uber.org/fx.Callable) só sabe o nome Go concreto em cada instanciação, não dentro do corpo genérico: `any(x)` de um `T` assim continua sem embrulho e cai no teste de subtipo do Dart (fixture `constraintloose`, função `wrap`) | M3 | ✅ |
| embedding (promoção) | caminho `$sel.index` + `mixin E$Promote` (forwarders), sempre na library de `E`, mesmo pra quem embute `E` de outro pacote | M3 | ✅ |
| genéricos | parâmetros de tipo Dart + dicionário `go.Elem<T>` (`$T`) + bounds `IntBase/GoReal/GoOrdered/StringBase` | M3 | ✅ |
| arrays `[N]T` (valor) | `go.GoArray<T>` (base `go.GoValue`, como `GoStruct`) | M3 | ✅ |
| goroutines, canais, `select` | `go.Chan<T>`, `go.select`/`go.selectNow`, `go.spawn` + escalonador; `async`/`await` pela cor transitiva (ver "Concorrência (M4) — runtime" e "Cor transitiva" abaixo) | M4 | ⚠️ runtime, emissão, timers, `context`, valor func `async`, `$goInit` que suspende, I/O que suspende (versão dupla, D2) e `CancelFunc` com cor própria (D7) prontos; faltam as classes de func de formato fixo da stdlib (`sort.Slice`...: "Cor transitiva" abaixo) |
| reflexão | `go.RType<T>` (descritor estático gerado pelo g2d, um por tipo; genéricos por fábrica `$rtOf`) + shim `reflect` que só lê o descritor (§ "Reflexão (M5, D1)") | M5 | ✅ `Type`/`Value` sem chamar funções; ⚠️ tipos de shim opacos |

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
    como assembly. ⚠️ O mecanismo de substituição ainda não existe
    (`TODO/P0-design-substituicao.md`).

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
| tipo não exportado `point` | `$_point` — **público** (`$` não é `_`: no Dart privacidade é só por `_` inicial, caixa não importa). Outro pacote não pode nomear `point` no Go, mas pode recebê-lo por inferência (`x := a.New()` com `New() *point`), e o g2d declara locais com tipo explícito e descritores `go.Elem<T>` que citam `a.$_point`; a privacidade Go já garante que ninguém escreve esse nome à mão. `$_` nunca colide: não é produzido por `ascii_name` (só `$u`/`$U`), nem por um tipo exportado (maiúscula ASCII, ou `$u`/`$U` no raro caso de maiúscula Unicode fora do ASCII), nem pelo membro não exportado do mesmo nome (`_point`, um só `_`), nem pelo membro exportado em lowerCamel de um nome parecido (`type foo` → tipo `$_foo`; `func Foo` → membro `foo`). Fixtures `embedprivate`, `unexportedcross` (multi-pacote) | ✅ |
| func/var/const/campo/método exportado `HTTPServer` | `httpServer` (lowerCamel ciente de siglas) | ✅ |
| func/var/const de pacote exportados que só diferem por caixa (`BOOL`/`Bool`, `FOO`/`Foo`) | o goast marca `fold` nos dois (também quando usados de outro pacote); o que perde a caixa de mais de uma letra no lowerCamel mantém a grafia Go (`BOOL`), o outro segue a regra (`bool$`). Nomes assim nunca colidem entre si nem com um lowerCamel | ✅ (fixture `foldnames`). ⚠️ campos/métodos: sem ocorrência no grafo do kubo, colidiriam |
| idem não exportado `add` | `_add` (privado da library = do pacote) | |
| func/var/const de pacote com o nome Dart de um membro de classe da library (`const sub` e o método `sub` → `_sub`; `func Name` e o método `Name` → `name`) | no corpo da classe o membro sombrearia o top-level. Não exportado: o top-level ganha `$` em toda a library (`_sub$`; nome privado não sai dela; `$` final nunca vem de nome Go). Exportado (outros pacotes citam o nome): dentro de método da classe com o membro, a referência sai pelo import da própria library, `import '' as $self;` (URI vazia = a própria library) → `$self.name` | ✅ (fixture `methodshadow`) |
| local/parâmetro | nome Go; se repetido na função ou igual a um nome de library → `x$1` | |
| palavra reservada Dart (`new`, `in`, ...) | sufixo `$` (`new$`) | |
| nome do `dart:core` usado pelo código gerado (`Object`, `Map`, `String`, `List`, `Function`, `BigInt`, `identical`, `int`, `bool`, ...: `DART_CORE_USED`) | sufixo `$` (`Object$`, `identical$`, local `int$`), para não sombrear o core na library | |
| método/campo exportado com o nome de um membro das bases estendidas (`Delete`, `Append`, `Value`, `Length`, `Call`, `ToString`, `ToBytes`, `ToDouble`, `ToInteger`, ...: `DART_BASE_MEMBERS`) | sufixo `$` (`delete$`, `value$`, `toString$`), em todo lugar, inclusive nas interfaces (o despacho continua casando) | ✅ (fixture `basemembers`) |
| tipo declarado dentro de função | içado para a library como `<função>$<Tipo>` (nome sintético sempre minúsculo no início, então sempre pela regra de tipo não exportado acima: `$_first$pair`; método: `$_<Recv>_<Método>$<Tipo>`; repetido na função: sufixo numérico). Nunca colide com um tipo de pacote de verdade: o nome sintético sempre tem um `$` literal no meio, que um identificador Go não pode ter | em função genérica, a classe içada é genérica nos parâmetros da função (`$_wrap$box$<T>`, dicionários no construtor; fixture `localgeneric`) |
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
| nomeado sobre array (`type Hash [32]byte`) | `final class Hash extends go.GoArray<Golang.Uint8>` (`Hash(go.GoArray...)` via `alias`); array é valor como struct, então os métodos de receptor ponteiro também ficam na classe e `Hash.$nil` é a sentinela; `[32]byte(h)` → `go.GoArray<...>.alias(h)` (tipo dinâmico sem nome); `$copy` e `$ifaceCopy` devolvem `Hash` (entra em interface; fixture `arraynomeadoiface`). Fixture `namedarray` | `Hash(go.GoArray<...>.zero(32, _$eN))` |
| nomeado sobre slice/map (`type IDs []string`) | `final class IDs extends go.Slice<Golang.String>` (idem `go.GoMap`); conversão/atribuição = `IDs(s)` via `Slice.alias` (mesmo array) | `IDs(go.Slice<...>.nil(_$eN))` |
| nomeado sobre func (`type Op func(int) int`) | `final class Op` chamável: `$f` (anulável), `call(...)`, `isNil`; `Op(fn)` / `op.$f` nas atribuições entre nomeado e não nomeado | `Op(null)` |
| `*N`, N nomeado não-struct com métodos e `*N` usado no pacote | `N$Ptr?`: `final class N$Ptr extends go.PtrView<N>` (vista sobre `go.Box`/`ElemPtr`/`FieldPtr`) com os métodos de receptor ponteiro, forwarders dos de valor e as interfaces de `*N` | `null` |
| struct anônima só com nomes exportados (`struct{ X int }`), sem parâmetro de tipo nem interface anônima com métodos na estrutura (`struct{}` é `go.EmptyStruct`) | classe canônica `Struct$<hash>` numa library própria, `out/lib/_anon/<hash>.dart` (importada sem prefixo): o hash (sha256, 12 hex) vem da estrutura — nomes, tags e tipos dos campos, com o import path dos nomeados — então todo pacote escreve o mesmo arquivo e a mesma classe (atribuição, `==` e type assertion entre pacotes, como no Go). O `main` que só importa a stdlib (programa de um pacote) fica com as classes locais: nenhuma outra library vê os tipos dele. Fixture multi-pacote `anoncross` | `Struct$<hash>()` |
| struct anônima com campo não exportado (tabelas de teste `[]struct{ in string }`), parâmetro de tipo ou interface anônima com métodos | classe local `$_anon$<índice da typeTable>` na library do pacote (uma por tipo; `go.GoStruct`, igualdade e cópia como qualquer struct). O pacote do campo não exportado entra na identidade (goast v9: `pkg` no campo), então só o dono a escreve; vinda de outro pacote (campo, método ou tipo nomeado não exportado de lá) → `Unsupported` `anonima:nao-exportada-de-outro-pacote`. ⚠️ a com parâmetro de tipo ou interface anônima com métodos continua uma por library | `$_anon$N()` |
| interface anônima com métodos (`interface{ Name() string }`) | só métodos exportados e sem interface embutida: classe canônica `Iface$<hash>` em `out/lib/_anon/<hash>.dart`, como a struct canônica (a mesma em todo pacote, D8). Um método só com a assinatura de uma interface do runtime vira ela: `Unwrap() error` → `go.Unwrapper`, `Unwrap() []error` → `go.MultiUnwrapper`, `Is(error) bool` → `go.ErrorIs`, `As(any) bool` → `go.ErrorAs`, `Timeout() bool` → `go.Timeouter`, `Temporary() bool` → `go.Temporary` (os shims e os tipos gerados as declaram: `err.(interface{ Timeout() bool })` acha o `context.DeadlineExceeded`; fixture `ifaceshim`). As outras (com embutida ou método não exportado) e as do `main` que só importa a stdlib: `abstract mixin class $_anonIface$<índice>` local; o goast põe no `implements` os literais `interface{...}` usados fora de declaração de tipo. Com método não exportado de outro pacote → `Unsupported` `anonima:nao-exportada-de-outro-pacote` | `null` |
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
  valores novos. Valor de parâmetro de tipo cuja constraint admite
  struct/array (`any`, só métodos, `comparable`) copia pelo dicionário,
  `$T.copyOf(v)`, e entra em interface por `$T.ifaceOf(v)` (fixture
  `genericcopy`).
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
| `make([]T, n, c)` | `go.Slice<T>.make(n, c, _$eN)`, com as checagens do `makeslice` (acima de `maxAlloc` = 2⁴⁸ bytes: `len out of range` se o len já estoura, senão `cap`). ⚠️ `len > cap` com cap constante e slice que não escapa dá `cap out of range` no gc (checagem inline do compilador); aqui dá `len` se o len estoura o `maxAlloc` |
| `s[i]`, `s[i] = v` | `s[i.toIndex()]`, `s[i.toIndex()] = v` (`toIndex()`: exato em ±2⁵³; fora disso, um sentinela ±2⁵⁴, sempre fora do intervalo, que guarda o texto exato do valor para a mensagem: `index out of range [9223372036854775808] with length 1` em VM, JS e Wasm; negativo sem o `with length`, como o `boundsNegErrorFmt` do Go). Fixture `bigindex` |
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
Chave struct/array é copiada ao ser guardada (`m[k] = v`, `m[k]++`), a
chave interface passa por `$ifaceCopy` também na leitura, e a variável de
chave do `range` é uma cópia (fixture `mapkeycopy`).

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

## Concorrência (M4) — runtime

Goroutines viram código `async` do Dart sobre o único event loop: cooperativo,
nunca paralelo de verdade (nem em AOT: uma só thread Dart roda o programa
inteiro). Uma função Go que pode suspender (operação de canal, `select` sem
`default`, `Lock` contendido, `WaitGroup.Wait`, `Cond.Wait`, `Sleep`, I/O) é
emitida `async`, e quem a chama usa `await`. Esta seção documenta o runtime,
em `golib_dart/lib/src/runtime/{chan,select,sched}.dart` e
`golib_dart/lib/src/sync/*.dart`, exportado por `builtin.dart` (prefixo `go`).

### Emissão do g2d (M4b)

`chan T`/`<-chan T`/`chan<- T` → `go.Chan<T>?` (nil = null; zero value nulo;
`Concurrency.direct_suspend`/`g2d/services/concurrency.py` decide, por
função/método/func literal, se ele suspende **diretamente**):

| Go | Dart |
|---|---|
| `make(chan T[, n])` | `go.Chan<T>(n, <zero de T>)` |
| `ch <- v` | `await go.chanSend(ch, v)` (valor copiado se struct, como em qualquer atribuição) |
| `<-ch` | `await go.chanRecv(ch)` |
| `v, ok := <-ch` | `await go.chanRecv2(ch)` (record `(T, bool)`) |
| `close(ch)`, `len(ch)`, `cap(ch)` | `go.chanClose/chanLen/chanCap(ch)` |
| `for v := range ch` | `while (true) { final $t = await go.chanRecv2(ch); if (!$t.$2) break; ... }` |
| `select` com `default` | `go.selectNow([...])` (nunca suspende) |
| `select` sem `default` | `await go.select([...])` (bloqueia) |
| `select`, geral | canais/valores de envio na lista literal do Dart (avaliados uma vez, em ordem, como o Go); `switch` no índice do resultado (`if/else` encadeado, como o `switch` comum); `case v, ok := <-ch:` e `case ch <- f():` funcionam; `break` sem rótulo sai do select (reusa `ControlFlow.switch_label`) |
| `go f(x)` / `go func(){...}()` / `go obj.m(x)` | função e argumentos avaliados na hora (mesma regra do `defer`); `go.spawn(() => f(a))` — nunca precisa saber se `f` é `async` (`Future<T> Function()` já serve de `FutureOr<void> Function()`) |

### Cor transitiva (`g2d/analysis/color.py`)

Decisão do dono (2026-10): só vira `async` quem pode suspender, e isso é
calculado pelo g2d sobre o grafo inteiro (nada de "tudo async", nem
isolates). Uma função/método/func literal é `async`/`Future<R>` se:

- **suspende no próprio corpo** (sem contar func literals aninhadas): uma
  das operações de canal acima fora dos cases de um `select` com `default`,
  `select` sem `default`, `range` sobre chan, `WaitGroup.Wait`,
  `Cond.Wait` (emitidos `await wg.wait$async()`...), ou `Mutex.Lock`,
  `RWMutex.Lock`/`RLock` de um **Mutex disputável** (`await
  x.lock$async()`, ver abaixo);
- **ou espera quem é `async`**: chamada direta de função, método (inclusive
  promovido por embedding, resolvido até o tipo que o declara), método de
  interface ou da restrição de um genérico, func literal chamada na hora,
  `defer` (a closure adiada vira `() async`, e a função roda
  `await $d.runAsync()`) e `Once.Do(f)` com `f` async (`await
  once.do$async(f)`). Recursão/ciclos não atrapalham (é um ponto fixo).

Mutex disputável: no event loop cooperativo, um `Lock` só encontra o Mutex
travado se quem o trava suspende antes de destravar. O g2d identifica o
Mutex estaticamente (campo de struct nomeada, var de pacote ou local) e
olha cada seção crítica: do `Lock` até o `Unlock` correspondente no mesmo
bloco, ou até o fim da função com `defer Unlock`. Se alguma seção suspende
(direto, chamando quem é `async` ou travando outro Mutex disputável), não
destrava no mesmo bloco, ou o Mutex não tem identidade estática (ponteiro
passado adiante), ele é disputável e todos os `Lock` dele suspendem; senão
ficam `lock()` síncrono e não colorem ninguém (ponto fixo junto com a cor).
⚠️ Um alias que o g2d não liga ao mesmo Mutex (ex. `m := &s.mu` travado
segurando um canal, e `s.mu.Lock()` em outro lugar) cai no `fatal` `g2d:
...` do `lock()` síncrono em runtime, nunca num resultado errado.

`go f()` e `WaitGroup.Go(f)` não colorem quem chama: `go.spawn` aceita
qualquer cor (o `go` emite a chamada sem `await`).

Ligações que o Dart exige (união-busca): um método de interface e todas as
implementações dele têm a mesma assinatura, logo a mesma cor (o
`implements` do goast), assim como uma interface e as interfaces que ela
embute; os forwarders de embedding (`E$Promote`, inline) e de `N$Ptr`
devolvem `Future<R>` quando o método de destino é `async`. A cor atravessa
pacotes nos dois sentidos (uma implementação com canal em `b` colore a
interface de `a`, emitido antes): `pipeline.color_table` resume todos os
pacotes carregados juntos antes de emitir, e o `audit` faz o mesmo passo
sobre o grafo do kubo (resumos em cache ao lado dos dumps). Fixtures
`asynccolor` (interfaces, embedding, tipo nomeado, genérico, recursão,
`defer`, `Once`, `WaitGroup.Go`, multi-valor, `Mutex` disputado de verdade
entre goroutines e um que nunca é disputado) e `asynccross` (interface em um pacote, implementação com
goroutine servidora em outro).

Contextos que precisam ficar síncronos (o shim chama de forma síncrona):
métodos `String`, `Error`, `GoString`, `Format`, e todo método no grupo de
uma interface da stdlib sem versão dupla (`sort.Interface`, `fmt.State`...;
as de I/O seguem a seção abaixo). Lá dentro o `Lock` fica
`lock()` síncrono (⚠️ `fatal` `g2d: ...` em runtime se estiver disputado);
qualquer outra espera é recusada: `async:contexto-sincrono`.

### I/O que suspende (`g2d/services/dualio.py`)

Decisão do dono (D2, 2026-10): **versão dupla**. Cada método das interfaces
de I/O do shim (`io.Reader.Read`, `Writer.Write`, `Closer.Close`,
`ByteReader.ReadByte`, `ByteWriter.WriteByte`, `StringWriter.WriteString`,
`ReaderAt.ReadAt`, `WriterAt.WriteAt` e as compostas) existe no Dart como
`read` (síncrono) e `read$async` (`Future`), e cada função do shim que os
chama também (`io.readAll`/`io.readAll$async`). Quem escolhe é a cor:

- o grupo de cor do método de interface junta as implementações do grafo
  (união do `implements`, como qualquer interface) e é `async` quando alguma
  delas suspende; `io.PipeReader.Read`/`PipeWriter.Write` suspendem sempre
  e entram no grupo de `io.Reader`/`io.Writer` do pacote que cita o tipo;
- todo membro de um grupo dual declara as duas formas: o corpo fica na forma
  da cor do grupo; a outra é derivada (`read$async(p) async => read(p)`, ou
  o síncrono `go.syncOfAsync('T.Read')`, um `fatal` `g2d:` que o g2d nunca
  chama). Interfaces geradas, forwarders de embedding e de `N$Ptr` têm as
  duas;
- chamada pelo grupo `async`: `await r!.read$async(p)`; `go r.Read(p)`,
  method value (`r.Read` vira o tear-off `read$async`) e method expression
  idem;
- tipo concreto do shim (`bytes.Buffer`, `strings.Reader`, `os.File`...)
  nunca suspende: a chamada direta é síncrona em qualquer grupo, e ele tem o
  `$async` pelos mixins `io.ReaderSync`, `io.WriterSync`...; o mesmo vale
  para `fmt.State.Write` (o valor é sempre o impressor do `fmt`), que por
  isso não força o grupo de `io.Writer`;
- função do shim com versão dupla (`io.ReadAll`/`ReadFull`/`ReadAtLeast`/
  `WriteString`/`Copy`/`CopyN`/`CopyBuffer`, `fmt.Fprint*`, `binary.Read`/`Write`/`ReadUvarint`/
  `ReadVarint`, `Buffer.ReadFrom`/`WriteTo`, `Reader.WriteTo`,
  `Replacer.WriteString`; tabela `DUAL_SHIM_CALLS`) espera quando o método
  que o shim chama é `async` **para o tipo estático do argumento**:
  `fmt.Fprintf(&sb, ...)` com `*strings.Builder` fica síncrono (inclusive
  dentro de `String()`), mesmo com `io.Writer.Write` async no grafo;
- função do shim sem versão dupla que recebe uma interface de I/O cujo
  método suspende para o argumento: `async:shim-sincrono`. Exceção: os
  construtores de embrulho (`io.LimitReader`, `MultiReader`, `MultiWriter`,
  `TeeReader`, `NopCloser`, `NewSectionReader`, `NewOffsetWriter`;
  `WRAPPING_SHIM_CALLS`) só guardam o valor, e o embrulho tem as duas formas
  reais (o `read$async` dele espera o `read$async` de baixo). ⚠️ O método do
  embrulho chamado direto pelo tipo concreto (`lr.Read(p)` com
  `lr *io.LimitedReader`) é síncrono, como todo tipo do shim: sobre um
  leitor que suspende, cai no `fatal` `g2d:` do `syncOfAsync`;
- `io.ReaderFrom.ReadFrom` e `io.WriterTo.WriteTo` também têm as duas formas
  (o `Copy` os prefere, como o Go); `io.RuneReader`/`RuneScanner`, como
  `io.Seeker`, só a síncrona;
- **contexto síncrono** (`Error()`, `String()`, `Format`, classe de func
  forçada): uma chamada que só espera I/O dual usa a forma síncrona (o
  método, a função do shim). Uma função gerada que é `async` só por esperar
  I/O dual (*branda*: a cor sem os grupos duais não a alcança) ganha a
  **gêmea síncrona** `f$sync`, emitida quando algum contexto síncrono a
  alcança, com as formas síncronas lá dentro: o `Error()` do `multierr`
  escreve num `*bytes.Buffer` por um helper `writeSingleline(w io.Writer)`.
  Method value de I/O dual numa classe de func síncrona é o tear-off
  síncrono. Um `Writer` que suspende de fato atrás dessa chamada cai no
  `fatal` `g2d:` do `syncOfAsync` em runtime (nunca num resultado errado);
  uma declaração concreta que suspende por si (`*chanReader` chamado
  direto, `io.PipeReader`) segue recusada (`async:contexto-sincrono`).

A granularidade é o grupo: uma implementação que suspende colore todas as
chamadas por aquela interface no grafo inteiro (no kubo, `io.Reader.Read`,
`io.Closer.Close` e `io.StringWriter.WriteString` ficam `async`; ver o
ranking do `docs/audit.md`). ⚠️ `io.WriteString` (e `Reader.WriteTo`,
`Replacer.WriteString`) testam `WriteString` no valor dinâmico; só o `Write`
do tipo estático decide a forma, então um `WriteString` que suspende atrás
de um `io.Writer` síncrono cai no `fatal` `g2d:` do `syncOfAsync`. ⚠️ Valor de I/O guardado
dentro de um shim (campo de struct do shim, `bufio.NewReader(r)`) só é
checado na chamada que o entrega; shim novo que guarde Reader/Writer precisa
de versão dupla. `net.Conn` entra quando o shim `net` tiver rede (D4).
Fixture `ioasync` (o repro do D2, `io.Pipe` com `fmt.Fprintf`, Writer
gerado que suspende, shim concreto síncrono, embedding de `io.Reader`,
method value, `ReadFull`/`ReadFrom`/`binary.Read`, `io.Closer` que espera um
`WaitGroup`, gêmea síncrona no `Error()`, `Close` guardado em `func() error`)
e `iowrapasync` (embrulhos do `io` e `Copy`/`CopyN` sobre `io.Pipe`,
`SectionReader` sobre um `ReaderAt` gerado que espera canal).

Valores de função (closure guardada, `f` sem chamar, method value `x.M`,
`T.M`, campo/slice/map de funcs, tipo nomeado sobre func): a cor é por
**classe de assinatura**, a assinatura subjacente canônica (identidade de
tipo do Go, igual em todo pacote; `type H func(string) string` e
`func(string) string` são a mesma classe). Todo valor de uma classe tem o
mesmo tipo Dart: `Future<R> Function(...)` se alguma função `async` vira
valor dela (nó `("sig", texto)` na `ColorTable`, com aresta classe → função),
e aí toda chamada por valor da classe espera (`await f!(x)`, `await
h(x)` no tipo nomeado, `defer f()` com closure adiada `async`, `Once.Do(f)`
com `do$async`). Uma função síncrona que vira valor de uma classe `async` é
embrulhada (`go.async1(upper)`, `go.async0`..`go.async8`; um literal vira
`() async {...}`). Fixture `asyncfunc` (errgroup, pipeline de callbacks,
method value, tipo nomeado, composição, `any` + type assertion, `Once.Do`,
`defer`).

Classes de **formato fixo** ficam síncronas (`ColorSummary.forced`):
assinaturas de funções e métodos da stdlib usados no grafo (o shim recebe
e devolve funções síncronas: `sort.Slice`, `http.HandlerFunc`...), exceto
o parâmetro de quem roda a função numa goroutine ou com `do$async`
(`time.AfterFunc`, `context.AfterFunc`, `WaitGroup.Go`, `Once.Do`: o shim
aceita `FutureOr<void> Function()?`), o `sync.OnceFunc` (genérico no Dart,
`R Function() onceFunc<R>(R Function()?)`: serve às duas cores) e pacotes
sem shim (o pacote cai na emissão de qualquer jeito); e formatos derivados
de genéricos: assinaturas com parâmetro de tipo (lá dentro o Dart vê `U
Function(T)`) e, nas instâncias (chamada genérica, campos e métodos de
tipos genéricos), só as classes que citam um argumento de tipo
(`queue[int]` prende `func(int)`, não a `func()` de um campo ou o tipo
de um método `Clear()`; `StartStopHook[func()]` também não prende a
`func()`, que lá dentro é um `T` opaco).

**Tipo de função nomeado da stdlib** (`context.CancelFunc`,
`CancelCauseFunc`...) é classe própria, `("sig", "context.CancelFunc")`,
sempre síncrona (o `typedef` do shim), separada da assinatura comum. Assim
a `func()` segue a cor dela no grafo (fixture `asynccancel`). Na passagem
de uma classe para a outra (`ValueSemantics.coerce`, e `coerce_multi`
para `ctx, cancel = context.WithCancel(ctx)` e `return
context.WithCancel(ctx)`, refeitos num switch expression):

- `CancelFunc` → `func()` `async`: `go.asyncOrNil0(cancel)` (nil continua
  nil);
- literal ou função síncrona citada direto → `CancelFunc`: emitida sem o
  embrulho da classe dela;
- valor `async` → `CancelFunc`: `async:valor-func`.

**Campo com classe própria** (`color.field_classes`): campo não exportado
de tipo `func` sem nome, numa struct nomeada não genérica, que só é chamado,
comparado com nil ou escrito, e só recebe nil, função citada direto ou um
tipo de função nomeado da stdlib, tem a classe `("field", pacote,
declaração)`: é `async` só se recebe uma função `async`. Um `cancelInner
func()` que guarda o `CancelFunc` de `context.WithCancel` fica síncrono, e a
closure que o chama ainda pode ser devolvida como `CancelFunc`
(`go.uber.org/fx/internal/fxclock`). O tipo do campo na struct e nos
seletores vira uma cópia do tipo func com `$class`. ⚠️ Campo lido sem ser
chamado (`f := x.cancel`, `&x.cancel`) ou que recebe um valor `func()`
qualquer fica na classe da assinatura.

`$goInit`: vira `Future<void> $goInit() async` se um inicializador de
variável de pacote, uma função `init` ou (no main) o `$goInit` de uma
dependência suspende; o `main` e o `$goInit` do main esperam com `await`
(fixture `asyncinit`).

Recusas (`Unsupported`, nunca Dart aproximado):

- `async:valor-func`: função `async` usada como valor de uma classe de
  formato fixo (acima);
- `async:contexto-sincrono`: ver acima.

`struct{}` é `go.EmptyStruct` (uma classe no runtime, não uma por library):
`chan struct{}` atravessa pacotes e shims (`context.Context.Done()`).
Métodos Go chamados `Go` viram `go$` (o membro `go` sombrearia o prefixo do
runtime): `WaitGroup.Go` → `wg.go$(f)`.

Uma interface se liga às implementações que o `implements` do goast conhece
(tipos do próprio pacote × interfaces da typeTable dele) e às que outros
pacotes exigem (`IfaceTable.unions`, "Interfaces entre pacotes (D8)").
⚠️ Ordem de avaliação: `a + await f()` lê `a` antes de suspender; o gc
pode ler depois da chamada (`TODO/P1-construcao-ordem-avaliacao.md`).

### `Chan<T>` (`src/runtime/chan.dart`)

| Membro | Semântica |
|---|---|
| `Chan(int cap, T zero)` | `make(chan T, cap)`; `cap` negativo ou absurdamente grande → `panic: makechan: size out of range` (não dá pra calcular o limite real do Go — que é por bytes do elemento — sem um layout Go; o limite aqui é só uma trava de sanidade) |
| `int get len`, `int get cap` | `len(ch)`/`cap(ch)` |
| `Future<void> send(T v)` | `ch <- v`: sem buffer, só volta quando um `recv` pegou o valor (entrega direta); com buffer, enfileira e só bloqueia com o buffer cheio |
| `Future<T> recv()`, `Future<(T, bool)> recv2()` | `<-ch` / `v, ok := <-ch`; FIFO de receptores |
| `void close()` | `close(ch)`: acorda todo mundo esperando recv com `(zero, false)`; quem estava esperando send panica (`send on closed channel`) — o valor não é entregue |
| `==`/`hashCode` | identidade (herdados de `Object`, sem override) — é a igualdade de canal do Go |
| `chanSend`/`chanRecv`/`chanRecv2`/`chanClose`/`chanLen`/`chanCap` (funções livres, `Chan<T>?`) | canal nil: `send`/`recv` bloqueiam pra sempre (conta como bloqueada pro detector de deadlock); `close` → `panic: close of nil channel`; `len`/`cap` → 0 |
| `Chan.$timer(T zero)`, `$drain()`, `$timerPoll`, `$hasRecvWaiter()` | canal de timer do shim `time` (Go ≥ 1.23): buffer interno de 1, mas `len`/`cap` 0; `$drain` descarta o valor velho (`Stop`/`Reset`); `$timerPoll` dispara o timer vencido quando um `recv`/`select` olha o canal; `$hasRecvWaiter` diz ao detector de deadlock se alguém espera nele |

Panics de canal (mensagens conferidas com `go run`, ver `chan_test.dart`):
`send on closed channel`, `close of closed channel`, `close of nil channel`,
`makechan: size out of range` — sempre `go.Panic(go.RuntimeError(...))`
(recover devolve um `runtime.Error` cujo `Error()` é a mensagem, igual ao Go).

### `select` (`src/runtime/select.dart`)

`sealed class SelectCase`, com `SendCase<T>(ch, value)` e `RecvCase<T>(ch)`.
`(int, Object?, bool) selectNow(cases)` nunca suspende (`select` com
`default`): `-1` se nada está pronto. `Future<(int, Object?, bool)>
select(cases)` bloqueia até algum caso ficar pronto. Em ambos, mais de um
caso pronto ao mesmo tempo é decidido por escolha uniforme pseudoaleatória,
como o Go; um `case` com canal nil nunca fica pronto (`select {}`, ou só com
canais nil, bloqueia pra sempre); um `send` escolhido cujo canal está (ou
fica, enquanto o `select` esperava) fechado panica igual a um `send` direto.

### Escalonador (`src/runtime/sched.dart`)

- `void spawn(FutureOr<void> Function() body)`: `go f()`. Nunca roda `body`
  na hora — sempre agenda (`scheduleMicrotask`), como o `go` do Go devolve
  antes da goroutine nova começar. Panic não recuperado dentro de `body`
  imprime `panic: <valor>\n\ngoroutine N [running]:\n<stack>` no stderr e
  encerra o processo com código 2 — mesmo com outras goroutines (inclusive a
  `main`) ainda vivas, como o Go.
- Detecção de deadlock: contadores globais de goroutines vivas (`main`
  conta como uma goroutine "ambiente" implícita, nunca decrementada; `spawn`
  soma/some uma unidade real por goroutine) e bloqueadas (canal, `select`,
  mutex, `WaitGroup`, `Cond`), mais `holdEvents()`/`releaseEvents()` (fontes
  de evento externo pendentes — timers, I/O — que outros shims chamam ao
  agendar/resolver). Quando bloqueadas ≥ vivas e nada pendente, depois que
  as microtasks assentarem (`Timer.run`, pra não falso-positivar com uma
  goroutine recém-`spawn`ada que ainda não rodou): `fatal(...)` →
  `fatal error: all goroutines are asleep - deadlock!`, código 2 — mensagem
  e código conferidos com `go run` (fixture `deadlock_recv.dart`).
  Fontes condicionais (`addEventSource(f)`/`removeEventSource(f)`): `f()`
  diz, na hora da checagem, se ainda pode acordar alguém — é o timer de
  canal do Go ≥ 1.23, que só conta enquanto alguma goroutine espera no
  canal dele (`Chan.$hasRecvWaiter()`). Timers do shim `time` usam as duas
  formas (fixtures `timers`/`timer_forgotten` em
  `test/timer_context_oracle_test.dart`).
- `Future<void> runMain(FutureOr<void> Function() main)`: ponto de entrada
  (aceita `main` síncrono ou assíncrono — compatível com o código já
  gerado). Ao terminar — sucesso ou panic —, descarrega stdout/stderr
  (`flushOutput()`; `exit()` do `dart:io`/Node não espera I/O assíncrono
  pendente por padrão e pode truncar saída) e encerra o processo NA HORA
  (código 0 ou 2), mesmo com goroutines ou timers ainda vivos, como o Go faz
  ao retornar de `main` (fixture `immediate_exit.dart`).

`dart2js` só sabe agendar microtasks/timers olhando globais de browser/worker
(`self.scheduleImmediate`...), que o Node não define; sem isso, o primeiro
`await` de QUALQUER programa gerado (nem precisa de goroutine — `runMain`
sempre tem pelo menos o `await flushOutput()` final) quebrava calado em
`dart compile js` + `node`. `output_web.dart` poliifla (`self =
globalThis`, só em Node) antes do primeiro ponto que pode precisar agendar;
`dart compile wasm` não passa por isto (import condicional em
`src/runtime/output*.dart`).

⚠️ **Sem preempção.** O event loop é cooperativo: um laço que nunca
suspende (ex. esperar um `atomic` mudar) trava o programa inteiro, enquanto o
Go o interromperia.

### `defer`/`recover` com goroutines (`src/runtime/defer.dart`)

`Defers.runAsync()` é como `run()`, mas aguarda cada `defer` que devolve
`Future` (função `async` com `defer`). O quadro que `recover()` consulta
("estou dentro de qual `Defers` agora?") vive numa `Zone` por chamada
(`Zone.current.fork(zoneValues: {...})`), não numa pilha estática
compartilhada: com goroutines se intercalando através de um `await` no meio
de uma closure diferida, uma pilha global devolveria o quadro de quem
tivesse empurrado por último — não necessariamente o certo (`Zone` carrega o
valor certo através do próprio `await` de cada cadeia assíncrona, mesmo
intercalada com outras). `defer_async_test.dart` prova a intercalação que
quebraria a pilha global.

### `sync` com goroutines (`src/sync/*.dart`)

Cada primitiva que pode bloquear ganha uma variante suspensiva de sufixo
`$` (impossível em Go — nunca colide): `Mutex.lock$async()`,
`RWMutex.lock$async()`/`rLock$async()` (preferência de escritor: `Lock`
pendente bloqueia `RLock` novo, síncrono ou não), `WaitGroup.wait$async()`,
`Cond.wait$async()` (destrava `L`, espera `Signal`/`Broadcast`, retrava —
com `L.lock$async()` se `L` for um `AsyncLocker`, senão o `lock()` síncrono
dele), `Once.do$async(f)` (chamada concorrente espera a primeira terminar,
sem rodar `f` de novo — mesmo que ela entre em panic: o Go marca `done` num
defer, então só a primeira propaga o panic). `WaitGroup.go$(f)` (Go 1.25; `go$` porque `go` é o prefixo do runtime):
`Add(1)` + `spawn` + `Done` (mesmo em panic). `Unlock`/`RUnlock`/`Signal`/
`Broadcast`/`Done` continuam síncronos: acordam quem espera em ordem FIFO,
por handoff direto (a posse passa pro próximo sem "destravar" de verdade).

As versões síncronas (`lock()`, `wait()`...) continuam valendo: sem outras
goroutines vivas, esperar por algo que só outra resolveria é o deadlock de
sempre (`go.fatal`); COM outras goroutines vivas, a versão síncrona travada
é um **limite do g2d** — algum contexto que precisava ficar síncrono (ex.
um método `String()`, que não pode virar `async`) tentou uma espera que só
a variante `$async` resolveria de verdade — e vira `fatal` com mensagem em
português começando com `g2d:` (não o `all goroutines are asleep` do Go,
que seria enganoso: não é um deadlock real, é o transpilador não tendo como
suspender ali).

`$ptrMethods` (method set usado por `implements`/reflexão de shim) não
ganha os `$async`: eles não são nomes Go — quem decide qual versão chamar é
a cor da chamada, do lado do g2d, nunca um lookup por nome Go em runtime.

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
| `(*[N]T)(s)` (Go 1.17) | `go.sliceToArrayPtr(s, N)`: um `GoArray` sobre o armazenamento do slice (escritas por um aparecem no outro), pânico do Go se curto, slice nil → nil. Array nomeado → `Unsupported` (`conversao:slice-named-array-pointer`). Fixture `convptr` |
| `(*U)(p)`, `*T` e `*U` de mesmo subjacente básico (`*(*uint64)(bs) \|= m`) | `go.convPtr<U, T>(p, (v) => U(v), (v) => T(v))`: vista `go.ConvPtr` sobre a mesma variável, converte na leitura e na escrita; nil → nil; `==` pela variável de origem; voltar ao tipo de origem devolve o ponteiro original (`(*T)((*U)(p)) == p`); `U` com métodos → `U$Ptr(...)`. Structs e arrays: cada tipo é uma classe e o objeto é o próprio endereço, sem aliasing entre classes → `Unsupported` (`conversao:pointer-pointer`, substituição). Fixture `convptr` |
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
| `if init; cond`, `for`, `for cond`, `for {}` | `{ init; if }`, `for (...)`, `while (cond)`, `while (true)`; variável do init em caixa (`&i`) ou struct/array ganha cópia nova antes do post (`i = go.Box(i.value), post`), uma por iteração como no Go 1.22 (fixture `forpervar`) |
| `range` sobre slice / map / int | índice sobre a referência; `keysSnapshot` + `containsKey`; contador |
| `range` sobre string | `for (var i = 0, w = 0; i < s.length; i += w)` com `s.decodeRune(i)` (runa, largura), igual ao `utf8.DecodeRune` |
| `switch` / `switch {}` / type switch | cadeia `if/else` num bloco; `break` sem rótulo que sai do switch → `break $tN;` (bloco rotulado; a pilha de alvos distingue switch de laço). Sem cases (`switch f() {}`, `switch i.(type) {}`): só avalia a tag. Variável do type switch atribuída em algum case não é `final`; com `&v`, mora numa `go.Box` (fixture `stmtedge`) |
| `fallthrough` | seleção do case (`$c`) seguida dos corpos em sequência (`if ($c == i)`); `fallthrough` → `$c = i + 1` na ordem do fonte, inclusive para o `default` no meio |
| rótulos, `break L`, `continue L` | rótulo no laço Dart; reservada do Dart ganha `$` (`in:` → `in$:`, fixture `stmtedge`) |
| alvo entre parênteses (`(*p)++`, `(x) += 3`, `(m[k])++`) | parênteses removidos do alvo (o Dart não aceita `(p!.value) += 1`) |
| `for k, v := range seq` (seq func, Go 1.23) | `seq((K k, V v) { if ($done) go.rangeFuncContinued(); corpo; return true; })`: `continue` → `return true`; `break` → `$done = true; return false`; `return`, `break L`/`continue L` para fora da closure gravam um código em `$st` (valores em `$rv`) e são refeitos depois da chamada; rótulos declarados no corpo ficam nativos; func literal dentro do corpo isola (fixture `rangefunc`) |
| `defer f(a)` | `{ final $t = a; $d.defer(() { f($t); }); }`, com o corpo em `try`/`catch`/`finally` de `go.Defers` |
| `defer f()` com f de tipo func nomeado | o closure em `f.$f` (pode receber `$rd` e recuperar); assinatura do subjacente (fixture `defernamed`) |
| `defer delete(m, k)`, `defer panic(v)`, `defer clear(s)`... | mesmo caminho, com a chamada do builtin no closure (fixture `deferbuiltin`); `defer recover()` → `Unsupported` `defer-recover` (no Go não recupera) |
| `go`, `select`, `ch <- v`, `<-ch`, range sobre chan | ✅ M4b, com cor transitiva ("Cor transitiva" acima) |
| `goto` | ❌ exigiria reescrever a função (blocos rotulados ou máquina de estados). Medido no grafo do kubo (`docs/audit.md`, `branch:goto`, 2026-10-02): 74 ocorrências em 28 pacotes, 10 na fronteira; decisão reaberta em `TODO/P0-design-goto.md` |

`defer`: os argumentos (e o receptor) são avaliados no `defer`; receptor de
método de receptor valor é copiado na hora (desreferenciado se `*T`), no
`defer` e no `go` (fixture `deferrecv`). As chamadas
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
| `Error()`/`String()` no fmt | regras do `handleMethods`/`printValue` do Go: só se o método está no method set do operando — struct/array por valor (na interface, em campo ou elemento) usa os de receptor valor, `*T` aninhado (elemento `[]*T`, valor de map, campo `*T`, ponteiro guardado em campo interface/parâmetro de tipo via `go.dynField`) usa os de `*T` (fixtures `fmtmethodset`, `fmtnested`); campo não exportado não chama método em nenhuma profundidade; panic dentro do método (inclusive no `Println`/`Sprint`) vira `%!v(PANIC=String method: ...)`, e com receptor ponteiro nil (inclusive nil deref do Dart dentro do método) vira `<nil>`; oráculo em `golib_dart/test/fmt_methods_test.dart`. ⚠️ chave `*T` em `map[any]V` é tratada como valor |
| `fmt.Sprintln` | `fmt.sprintln(go.Slice<Object?>)` → `Golang.String` (mesmo formato do `Println`) |
| `fmt.Formatter`, `fmt.State` | interfaces de shim; o printer implementa `State` (`Write`, `Width`, `Precision`, `Flag`) e chama `format(state, verb)` antes de `Error`/`String`, para todo verbo menos `%T`/`%p`, com receptor nil e `%!v(PANIC=Format method: ...)` como o Go (fixture `fmtformatter`) |
| `%v` | `<nil>`; wrappers pelo `toString` (floats = `FormatFloat 'g'`); structs `{a b}`; `&{...}`; slices `[a b]`; maps `map[k:v]` com as chaves na ordem do `internal/fmtsort` (nil primeiro, números, strings, bool, complex, structs e arrays campo a campo); ⚠️ ponteiros ficam na ordem de inserção e chaves interface de tipos diferentes vão pelo nome do tipo, porque o Go ordena ambos por endereço de memória (para tipos, o layout de símbolos do linker, que muda com os pacotes linkados; medido no gc 1.25, não há regra reproduzível); ponteiros aninhados como endereço |
| `fmt.Printf`, `Sprintf` | `fmt.printf(format, go.Slice<Object?>)` / `fmt.sprintf(...)`: porte do `doPrintf`/`format.go` — verbos `v d b o O x X c q U e E f F g G s t T w %`, flags `+ - # 0 ␠`, largura/precisão (inclusive `*`), `%!verbo(tipo=valor)`, `(MISSING)`, `%!(EXTRA ...)`, `BADWIDTH`/`BADPREC`/`NOVERB`; o verbo se aplica a cada elemento de slice/array/map/struct; `Error()`/`String()` para `v s q x X`. Floats com precisão: dígitos do binário exato, meio-para-par. `%q`/`%+q`/`%#U` usam o `unicode.IsPrint` exato do Go (tabela gerada em `golib_dart/lib/src/unicode/isprint.dart` por `tool/gen_isprint.go`, conferida pelo teste). `%+v` escreve os nomes dos campos (`$fieldNames` gerado em toda struct; embutido = nome do tipo), inclusive aninhados; índice explícito `[n]` como o `argNumber` do Go (`BADINDEX`, sem `EXTRA` quando reordenado, `%w` ordenados no `Errorf`). Endereços (`%p`, `%#p`, `%v` de `*T` não-struct, func e ponteiro aninhado): `0xc0` + 8 hex, ⚠️ estável por objeto (`Box` por identidade, `&s[i]`/`&o.f` por dono + posição, slice = `&s[0]`), não o endereço do Go (que nem o Go reproduz; fixture `fmtaddr` compara a forma). `%#v` (sintaxe Go; fixture `fmtsharpv`): básicos (`0x` em sem sinal, string com `%q`), structs (`$fieldNames`), slices, arrays e maps (chaves ordenadas), `&T{...}`, `(*T)(nil)`, `T(nil)`, `interface {}(nil)`, `[]byte{0x..}` no nível de topo, e `GoString()` (`fmt.GoStringer`, só no method set certo) no lugar de `Error()`/`String()`. Os erros do runtime (`errors.New`, `fmt.Errorf`, `errors.Join`) saem como o Go (`&errors.errorString{s:"x"}`, via `go.GoOpaqueStruct`); aninhados (o `err` de um `wrapError`) saem `(*errors.errorString)(0x...)`. `#` em float (`%#g` completa os dígitos significativos, `%#.0f`/`%#e` mantêm o ponto) e em runa (`%#q` = `%q`, como no Go): oráculo em `golib_dart/test/fmt_test.dart`. O valor Dart de slice/map/array não diz o tipo Go: o operando estático vai embrulhado em `go.TypeTag(valor, 'nome Go', 'subjacente')` (g2d `FmtVerbCheck.tag_operands`), e toda struct com campo não básico gera `$fieldTypes` (nomes Go dos campos, `''` se depende de parâmetro de tipo); dentro de interface um slice/array sem nome tem o nome inferido do zero value do elemento. ⚠️ `%#v` ❌ de func, chan e ponteiro para não-struct (aninhados ou não) é recusado na transpilação (`fmt-verbo:%#v-<caso>`); ponteiro aninhado para struct não nil sai `(*T)(0x...)` com o endereço ⚠️ estável do `%p` (fixture `fmtsharpv` compara a forma); lança `UnimplementedError` em runtime map, ou slice de ponteiro/interface, dentro de interface sem nome estático. ❌ `%b`/`%x` em float, verbo ≠ `v` em complex, `%T`/`%!(EXTRA)` de slice/array/map/chan/ponteiro não-struct: com formato constante e tipo estático conhecido o g2d recusa na transpilação (`fmt-verbo:<caso>`, `g2d/behaviors/fmtcheck.py`); ⚠️ operando interface, `args...` ou formato não constante só se descobrem em runtime, onde o shim lança `UnimplementedError` (nunca formata diferente). `%T`/`%!(EXTRA)` de func (nomeado ou não) já formatam (`go.Func`, linha de interfaces acima) |
| `fmt.Errorf` | `fmt.errorf(...)` → `go.ErrorString` (`*errors.errorString`) sem `%w`; `go.WrapError` (`*fmt.wrapError`, `unwrap()`) com um; `go.WrapErrors` com vários (`src/runtime/errors.dart`, reusado pelo futuro shim `errors`) |
| símbolo que o shim não tem | `Unsupported` `shim-simbolo:<pkg>.<nome Dart>` (lista em `g2d/shim_symbols.json`, gerada do dartast por `python -m g2d shims`; o teste de golden confere se está em dia) |
| método ou campo que a classe de um tipo concreto de shim não tem (`t.GobDecode` com `time.Time`; também via ponteiro, method value, method expression, promovido por embedding e cada campo do caminho de embedding) | `Unsupported` `shim-simbolo:<pkg>.<Classe>.<membro Dart>` (ex. `shim-simbolo:time.Time.gobDecode`). Membros de instância públicos de cada classe pública do shim em `g2d/shim_symbols.json` (`members`), com os herdados por `extends`/`with`/interfaces resolvidos em `golib_dart/lib`, extensões públicas da library e `typedef T = C`; classe com superclasse fora de `golib_dart` fica sem conferência (`null`). Método chamado via interface (`io.Writer.Write`, `fmt.Stringer`) não é conferido. ⚠️ Nomes de parâmetro de literal composto de struct de shim (`fs.PathError{Op: ...}`) não são conferidos |
| `math` | `naN()` com os bits do Go (`0x7ff8000000000001`); `sqrt`, `floor`, `ceil`, `trunc`, `abs`, `max`, `min`, `inf`, `isInf`, `isNaN`, `signbit`, `copysign`, `float32bits`/`float64bits`/`...frombits`, com oráculo bit a bit; as constantes são dobradas. ⚠️ payload de NaN não é portável (o JS canoniza). Transcendentais e afins (`exp`, `expm1`, `log`, `log2`, `log10`, `log1p`, `pow`, `frexp`, `ldexp`, `modf`, `mod`, `round`, `roundToEven`, `nextafter`, `cbrt`, `sin`, `cos`, `tan`, `sincos` (Payne-Hanek acima de 2²⁹), `atan`, `lgamma`, `gamma`, `erfc`): porta do código Go puro (`golib_dart/lib/src/math/pure.dart`, fdlibm/Cephes via Go 1.26.5) sobre `double`, com as expressões constantes do Go já dobradas; oráculo bit a bit contra o Go com `GOARCH=386` (lá o `math` é só Go puro). ⚠️ No amd64 o gc usa assembly em `Exp`/`Log` (com FMA conforme a CPU), e por elas em `Pow` fracionário, `Log2`, `Log10`, `Lgamma`, `Gamma`, `Erfc`: o `go run` amd64 pode diferir no último bit; o alvo é o Go puro, igual em VM, JS e Wasm e ao Go fora de amd64/arm64/loong64/s390x. Fixture `mathtrans` (as que usam `Exp`/`Log` impressas com `%.12g`) |
| `math/bits` | todas as funções usadas pelo grafo, sobre as metades de 32 bits dos fixed_types (`Add/Sub/Mul/Div(64)` em records; `Div64` com os pânicos do Go) |
| `errors` | `new$` → `go.ErrorString` (identidade); `is$`, `as`, `unwrap`, `join` (`go.JoinError`), `asType` (Go 1.26), `errUnsupported`: porta de `wrap.go`/`join.go`. A cadeia é percorrida por interfaces do runtime que o g2d declara em todo tipo cujo method set tem a assinatura exata (`Unwrap() error` → `go.Unwrapper`, `Unwrap() []error` → `go.MultiUnwrapper`, `Is(error) bool` → `go.ErrorIs`, `As(any) bool` → `go.ErrorAs`), respeitando o method set do valor (`go.goHasMethod`); `Is` só compara com `==` alvo comparável (`go.goComparable`). `As` escreve no alvo com `Ptr.$assignIfIs` (genéricos reificados: `v is T`; struct por valor não serve a `*S`), ou `$set` quando o alvo é a própria struct; pânicos do Go para alvo nil/não ponteiro/não error. Fixture `errorschain` |
| `encoding/json`, `encoding` | Port do json v1 do Go 1.26.5 sobre o shim `reflect` (`golib_dart/lib/encoding/json.dart`, partes em `lib/src/encoding/json/`); do `encoding`, só as quatro interfaces. `Marshal`, `MarshalIndent`, `Unmarshal`, `Valid`, `Compact`, `Indent`, `HTMLEscape`, `Encoder` (`Encode`, `SetIndent`, `SetEscapeHTML`), `Decoder` (`Decode`, `Token`, `More`, `Buffered`, `InputOffset`, `UseNumber`, `DisallowUnknownFields`; o buffer cresce como no Go), `RawMessage`, `Number`, `Delim`, `Marshaler`/`Unmarshaler` e os erros (`SyntaxError`, `UnmarshalTypeError`, `InvalidUnmarshalError`, `UnsupportedTypeError`, `UnsupportedValueError`, `MarshalerError`) com as mensagens exatas. Regras do Go: tag `json` (`-`, `omitempty`, `omitzero`, `string`), embutidos e o campo que vence por profundidade e tag, chaves de map ordenadas (string, inteiro ou `TextMarshaler`), `[]byte` em base64, escape de HTML, UTF-8 inválido como U+FFFD, cortes `'e'`/`'f'` de float (inclusive float32), `Marshaler`/`TextMarshaler`/`Unmarshaler` no valor e no ponteiro endereçável, ciclo depois de 1000 níveis, `UnmarshalTypeError` que segue e devolve o primeiro erro, nome sem diferenciar caixa; scanner e offsets do `SyntaxError` iguais. Método presente sem `implements` declarado pelo g2d vai pelo nome, decidido pelo method set do descritor. Fixtures `jsonencode`, `jsondecode`, `jsonstream`. ⚠️ `RawMessage` é `typedef` de `[]byte`: fiel onde o descritor `json.RawMessage` chega (campo, elemento, valor de map), mas como alvo direto ou dentro de `any` vira base64; método de receptor ponteiro de nomeado não struct alcançado pelo endereço de campo/elemento/chave dá panic explícito; tipo de shim sem descritor (`big.Int`...; `time.Time`/`Duration`/`Month`/`Weekday` têm) dá panic explícito; `Encode`/`Decode`/`Token`/`More` são síncronos (sobre I/O que suspende, o fatal do `go.syncOfAsync`); copiar `Decoder` por valor dá panic. Os deprecados `UnmarshalFieldError`/`InvalidUTF8Error` viram `shim-simbolo:` |
| `encoding/binary` | `littleEndian`/`bigEndian`/`nativeEndian` (little no amd64): `uint16/32/64`, `putUint16/32/64`, `appendUint16/32/64`, `String()`, acessando o último índice primeiro (mesmo pânico de bounds do Go). As structs vazias não exportadas do Go (`bigEndian`...) são as subclasses `BigEndian`/`LittleEndian`/`NativeEndian` de `ByteOrder` (struct de shim; `var NBO = binary.BigEndian` usa o mapeamento `SHIM_TYPES` do `g2d/config.py`). Varints (`uvarint`, `putUvarint`, `appendUvarint`, `varint`, `putVarint`, `appendVarint`, `readUvarint`, `readVarint`) com os overflows do Go. `read`/`write` sem reflexão: ponteiro para valor de tamanho fixo, slice e array (inteiros de largura fixa, floats, bool; `[]byte` vai direto), struct no `write`; `int`/`uint` dão o erro do Go. ⚠️ `read` em struct lança `UnimplementedError`; tipo nomeado sobre `int` passa como int64. Fixture `binaryvarint` |
| `crypto/subtle` | `xorBytes` (pânicos `dst too short` / `invalid overlap`, via `go.inexactOverlap`), `constantTimeCompare` |
| `bytes` | `equal`, `compare`, `indexByte`, `index`, `count`, `hasPrefix`, `hasSuffix`, `lastIndexByte`, `split` (pedaços com cap limitado, `s[:m:m]`), `trimLeft` (vazio → nil), `trimRight` (vazio continua vazio). `toUpper`/`toLower` (atalho ASCII, senão `unicode.ToUpper`/`ToLower`), `title`, `equalFold`, `trimSpace` (tudo espaço → nil, como o Go), `fields`/`fieldsFunc`, `indexFunc`/`lastIndexFunc`/`containsFunc`, `runes` — sobre o shim `unicode` novo (`src/bytes/case.dart`, parte nova). `contains`/`containsAny`/`containsRune`, `lastIndex`, `indexRune`, `indexAny`/`lastIndexAny`, `trimPrefix`/`trimSuffix`, `trim`/`trimFunc`/`trimLeftFunc`/`trimRightFunc`, `cut`/`cutPrefix`/`cutSuffix`, `clone`, `join`, `repeat`, `map`, `replace`/`replaceAll`, `splitN`/`splitAfter`/`splitAfterN` (porta direta do Go; `src/bytes/search.dart`, `edit.dart`, `split.dart`; fixture `bytesstringsmisc`). `Buffer`, `Reader`/`newReader` como structs de shim (fixture `bytesmore`). ❌ `ToValidUTF8`, `ToTitle`, `SplitSeq` (`TODO/P1-shim-iter.md`) |
| `unicode/utf8` | porta com as regras de decodificação do Go (byte inválido, curto, overlong, surrogate ou acima de U+10FFFF → (U+FFFD, 1)): `decodeRune`/`...InString`, `decodeLastRune`/`...InString`, `encodeRune` (pânico de índice do último byte, como a dica de bounds check), `appendRune`, `runeLen`, `runeCount`/`...InString`, `runeStart`, `valid`/`validString`, `validRune`, `fullRune`/`...InString`; constantes dobradas. Fixture `utf8shim` |
| `unicode` | `RangeTable`/`Range16`/`Range32`/`CaseRange` como structs de shim (`go.GoStruct`, como `bytes.Buffer`): campos `r16`/`r32`/`latinOffset` e `lo`/`hi`/`stride` batem com o `go/types` real do tipo (de qualquer pacote), então o g2d aceita tanto o literal composto Go (`&unicode.RangeTable{R16: []unicode.Range16{...}}`, ex. `dunglas/httpsfv`) quanto o acesso a campo sem nenhum código novo no g2d. Predicados (`isDigit`, `isLetter`, `isSpace`, `isUpper`, `isLower`, `isTitle`, `isControl`, `isMark`, `isNumber`, `isPunct`, `isSymbol`, `isGraphic`, `isPrint`) e conversões (`toUpper`, `toLower`, `toTitle`, `to`, `simpleFold`) sempre varrem a tabela cheia — sem o atalho Latin-1 do Go (`properties[uint8(r)]`, não exportado); ⚠️ resultado idêntico ao atalho, provado por oráculo em 0..0x10FFFF (`test/unicode_tables_test.dart`), nunca assumido. `is$`/`in$` (nomes reservados no Dart). Tabelas (`Categories`, `Properties`, `Scripts["Greek"]` e o mapa `scripts` completo, `CaseRanges`, o ciclo de `SimpleFold`) geradas de `tool/gen_unicode*.go` sobre o `unicode` do Go **1.26.5** (`GOTOOLCHAIN` fixo: difere do Go local em `Cn`/`LC`, mesmo com o mesmo `unicode.Version`), padrão do `isprint.dart` existente (`tool/gen_isprint.go`) mas para as tabelas inteiras, não só booleanos. ⚠️ só `Greek` (o único script usado pelo grafo do kubo hoje) tem var de nível de pacote; os demais ~160 só pelo mapa `scripts` (nome Dart não conferido por um caso real). Fixture `unicodecase` |
| `strings` | `contains`, `containsRune`, `index`, `indexByte`, `lastIndex`, `count`, `hasPrefix`/`hasSuffix`, `trimPrefix`/`trimSuffix`, `trimFunc`/`trimLeftFunc`/`trimRightFunc`, `join`, `split`/`splitN` (cap do resultado igual ao Go); UTF-8 inválido decodifica como o Go. `toUpper`/`toLower` (atalho ASCII do Go, senão `unicode.ToUpper`/`ToLower` runa a runa), `toTitle`, `title` (deprecated no Go, mantido por fidelidade), `equalFold`, `trimSpace` (atalho ASCII), `fields`/`fieldsFunc`, `toValidUTF8` (bytes exatos preservados, sem recodificar), `indexFunc`/`lastIndexFunc`/`containsFunc` sobre o shim `unicode` novo (`src/strings/case.dart`, parte nova para não colidir com quem mexe nas outras). `replace`/`replaceAll`, `repeat`, `compare`, `cut`/`cutPrefix`/`cutSuffix`, `trim`/`trimLeft`/`trimRight`, `lastIndexByte`, `indexRune`, `indexAny`/`lastIndexAny`/`containsAny`, `map`, `splitAfter`/`splitAfterN` (porta direta do Go, `src/strings/search.dart` e `replace.dart`; fixture `bytesstringsmisc`). `Builder`, `Reader`/`newReader`, `Replacer`/`newReplacer` como structs de shim (fixture `stringsmore`; o `Replacer` usa só o algoritmo genérico do Go, sem as otimizações por caso). ❌ `SplitSeq`/`FieldsSeq`/`Lines` (`TODO/P1-shim-iter.md`) |
| `strconv` | inteiros: `itoa`, `formatInt`, `formatUint`, `parseInt`, `parseUint`, `atoi` (porta de `internal/strconv`, `(valor, GoError?)`), erros `*strconv.NumError` (classe privada: `Error()` com `%q` do `fmt`, `Unwrap()`), `errRange`/`errSyntax`; oráculo com ~2500 casos; `parseBool`/`formatBool`/`appendBool`, `appendInt`/`appendUint`, `quote*`/`appendQuote*` (núcleo `src/strconv/quote_core.dart`, o mesmo do `%q` do `fmt`), `unquote`/`unquoteChar`, `isPrint`, `canBackquote`; `formatFloat`/`appendFloat` (`e E f g G`, sobre o formatador exato do `fmt`) e `parseFloat` (gramática do `atof.go`; arredondamento decimal por BigInt meio-para-par, igual ao do Go; hexadecimal é a porta de `atofHex`); oráculo em `golib_dart/test/strconv_misc_test.dart` e fixture `tests/golden/strconvmisc`. `IntSize` é constante dobrada pelo goast. ❌ `FormatFloat` com `b`/`x`/`X`, `ParseComplex`/`FormatComplex`, `QuotedPrefix`, `QuoteToGraphic`, `NumError` exposto |
| `regexp` | motor próprio (não tradução para o `RegExp` do Dart, cujo `.`, `\b`, `$`, dobra de caixa e UTF-16 diferem do RE2): parser da sintaxe do `regexp/syntax` (flags Perl) com os mesmos códigos e trechos de erro (`error parsing regexp: missing closing ): ...`; `MustCompile` entra em pânico com `regexp: Compile(`...`): ...`), compilação para programa e simulação Pike (leftmost-first, tempo linear, sem backtracking), sobre os bytes UTF-8: índices em bytes e UTF-8 inválido casa como U+FFFD de largura 1. `Regexp` é struct de shim (`go.GoStruct`; o programa é imutável e compartilhado nas cópias). Cobre `compile`, `mustCompile`, `matchString`, `match`, `quoteMeta` e os métodos `match`/`matchString`, `find*`/`findAll*` (String, Index, Submatch e combinações, `n` do Go), `replaceAll*` (`$1`, `${name}`, `$$` com as regras do `expand`; `Literal`; `Func`), `expand`/`expandString`, `split`, `numSubexp`, `subexpNames`, `subexpIndex`, `string`; oráculo Go com ~90 mil resultados (255 padrões, válidos e inválidos × 34 entradas, inclusive UTF-8 inválido). Dobra de caixa pelo `unicode.simpleFold` e `\p{..}`/`\P{..}` pelas tabelas `Categories`/`Scripts` do shim `unicode` (as do Go, iguais em toda plataforma); nome desconhecido → `invalid character class range`, como o Go. ❌ `Longest`, `CompilePOSIX`/`MustCompilePOSIX`, `MatchReader`/`FindReaderIndex`, `ReplaceAll*` com `io.RuneReader`, `LiteralPrefix`, `Copy`, `MarshalText`/`UnmarshalText`, `Regexp.Match*` em `RuneReader`: `Unsupported shim-simbolo`. Backreferences e lookaround não existem no RE2 (erro de sintaxe, como no Go). Fixture `regexpbasic` |
| tipo struct de shim (`strings.Builder`, `bytes.Buffer`) | classe do shim `extends go.GoStruct<T>`, com `$copy`/`$set`/`$fields`/`$valueMethods`/`$ptrMethods`: o g2d a trata como struct de outro pacote (zero `strings.Builder()`, cópia, métodos no próprio objeto, `go.Elem` com `.new`) sem olhar os campos não exportados do dump. Porta do Go com o mesmo crescimento (`Cap`) e checagens (cópia de Builder, `Truncate`...). Fixtures `stringsbuilder`, `bytesbuffer` |
| `io` | porta de `io.go`/`multi.go`/`pipe.go` do Go 1.26: sentinelas (`eof`, `errUnexpectedEOF`, `errShortWrite`, `errShortBuffer`, `errNoProgress`, `errClosedPipe`); `pipe` (`PipeReader`/`PipeWriter`, porta do `io/pipe.go` sobre `Chan`/`select`; só a forma `$async` espera); `readFull`/`readAtLeast`, `writeString` (o `WriteString` do próprio Writer no method set do valor, senão `Write([]byte(s))`), `readAll` (o algoritmo do Go 1.26: pedaços 1,5× e cópia final, mesmo `cap`), `copy`/`copyN`/`copyBuffer` (preferindo `WriteTo` do leitor e depois `ReadFrom` do escritor, como o Go; `CopyBuffer` com buffer vazio não nil é pânico), `discard` (implementa `ReaderFrom`), `nopCloser` (encaminha `WriteTo` quando o leitor de baixo o implementa), `limitReader`/`LimitedReader`, `multiReader`/`multiWriter` (achatam os aninhados como o Go), `teeReader`, `newSectionReader`/`SectionReader`, `newOffsetWriter`/`OffsetWriter`; versão dupla (`$async`, "I/O que suspende") de todos os métodos de I/O e das funções que os chamam; `Reader`, `Writer`, `ByteReader`, `ByteWriter`, `StringWriter`, `Closer`, `Seeker`, `ReaderAt`, `WriterAt`, `ReaderFrom`, `WriterTo`, `ByteScanner`, `RuneReader`, `RuneScanner` e as compostas (`ReadCloser`, `WriteCloser`, `ReadWriter`, `ReadWriteCloser`, `ReadSeeker`, `ReadSeekCloser`, `WriteSeeker`, `ReadWriteSeeker`) como interfaces de shim (`SHIM_INTERFACES`: tipo gerado com `Write([]byte) (int, error)` declara `implements io.Writer`); `bytes.Buffer`, `bytes.Reader` e `strings.Reader` implementam as que têm no Go. `LimitedReader` (campos `R`/`N`, construtor de campos nomeados para `&io.LimitedReader{R: r, N: 5}`), `SectionReader` e `OffsetWriter` são structs de shim como `bytes.Buffer`. Var de shim é `final` Dart (sem caixa). Fixtures `iofuncs`, `ioasync`, `iowrapasync` |
| `os` | parcial (1º recorte portável VM/AOT/JS/Wasm): `getenv`/`lookupEnv` (JS/Wasm sem Node: `""`/`false`), `exit`, `getpid`, `args` (só `[nome do programa]`), `stdin`/`stdout`/`stderr` como `*File` (`write`, `writeString`, `close`, `name`, `fd`; `ErrClosed` depois de `Close`; `Read` não existe), `errNotExist`/`errExist`/`errPermission`/`errClosed`/`errInvalid`/`errNoDeadline`/`errDeadlineExceeded`, `isNotExist`/`isExist`/`isPermission`/`isTimeout` (como o `underlyingError` do Go). ❌ sistema de arquivos (`Open`, `ReadFile`, `Stat`, `MkdirAll`...): `Unsupported` `shim-simbolo:os.*` (`TODO/P0-design-os-arquivos.md`). Fixture `osbasic` |
| `io/fs` | parcial: `PathError` (struct, `os.PathError` é alias), `FileMode` (`Uint32Base`; `IsDir`/`IsRegular`/`Perm`/`Type`/`String` sem `<<` acima de 30 bits), `errInvalid`/`errPermission`/`errExist`/`errNotExist`/`errClosed`. Fixture `osbasic` |
| `time` | parcial: `Duration` (classe sobre `Int64Base`, a mesma forma de `type N int64` gerado; `String()` portado do Go, `Seconds`/`Minutes`/`Hours`/`Round`/`Truncate`/`Abs`/...); as constantes (`time.Second`) dobradas em `time.Duration(n)`. `parseDuration` (sobre os bytes, erros do Go). `Time` struct de shim (`wall`/`ext`/`loc` do Go, relógio monotônico incluso): `unix*`, `add`/`sub`/`addDate`/`truncate`/`round`, comparações, `date`/`clock`/componentes/`isoWeek`, `zone`/`location`/`utc`/`local`/`in$`, `string()`; `date`, `unix`/`unixMilli`/`unixMicro`, `now`/`since`/`until`; `Month`/`Weekday` (`Int64Base`, `String()`); `Location` de fuso fixo (`utc`, `local`, `fixedZone`; struct de shim com `==` por identidade, como o `*Location`). Layouts (porta de `time/format.go` e `format_rfc3339.go` do Go 1.26.5, `src/time/layout.dart`, `parse.dart`, `parse_layout.dart`, sobre os bytes): `format`, `appendFormat` (atalho RFC 3339 como o Go), `parse`/`parseInLocation` (atalho `parseRFC3339`; zona por `Z`/offset/nome com as regras do Go: offset ou nome iguais aos do `local` usam o `local`, senão zona fixa inventada; `GMT±h`; `ChST`/`MeST`/`WITA`), `*ParseError` (struct de shim, campo `Value` → `value$`) com as mensagens exatas; as constantes de layout (`time.RFC3339`...) dobradas no literal. `goString`, `isDST` (sempre `false`), `marshalJSON`/`unmarshalJSON`, `marshalText`/`appendText`/`unmarshalText`, `marshalBinary`/`appendBinary`/`unmarshalBinary` com os erros do Go (`Time.MarshalJSON: year outside of range [0,9999]`...); `Time` declara `implements` de `json.Marshaler`/`Unmarshaler`, `encoding.TextMarshaler`/`TextUnmarshaler`/`BinaryMarshaler`/`BinaryUnmarshaler` e `fmt.GoStringer`. Reflexão (`SHIM_RTYPES`, `src/time/rtypes.dart`): `Time` é struct `time.Time` de 24 bytes com `wall`/`ext`/`loc` não exportados (PkgPath `time`, `*time.Location` opaco); `Duration` (`int64`), `Month`/`Weekday` (`int`) nomeados — o `encoding/json` os codifica como o Go (fixture `timejson`). ⚠️ `Local` = UTC (o Go com `TZ=UTC`; o e2e roda o `go run` com `TZ=UTC`): componentes de `now()` diferem do Go em outro fuso, e `Parse` só reconhece no `local` o offset 0. ⚠️ Method set de `Time` sem `GobEncode`/`GobDecode`/`ZoneBounds` (`NumMethod` menor que o do Go; chamá-los é `shim-simbolo:`). Oráculo `golib_dart/test/time_test.dart` (VM × JS × Wasm). Timers (Go ≥ 1.23, `src/time/sleep.dart`): `sleep(d)` → `Future<void>` (o g2d emite `await time.sleep(d)`; `d <= 0` volta sem timer); `newTimer`/`after`/`afterFunc` → `Timer` (struct de shim: campo `C` → `c`, `Chan<Time>?`, nulo no `afterFunc`; `stop()`/`reset(d)` → `bool`); `newTicker`/`tick` → `Ticker` (`c`, `stop()`, `reset(d)`). Canal de timer síncrono como o Go ≥ 1.23: `len`/`cap` 0 (`go.Chan.$timer`), `Stop`/`Reset` descartam o disparo não recebido (e então devolvem `true`), timer vencido dispara ao ser olhado (`recv`/`select`, mesmo sem ceder o laço de eventos). `afterFunc(d, f)` roda `f` com `go.spawn` (aceita closure `async`). Deadlock: `Sleep`/`AfterFunc` pendentes seguram o detector (`holdEvents`); timer de canal só enquanto alguém espera no canal dele (`addEventSource`), como o Go ≥ 1.23 (`time.NewTimer(time.Hour)` esquecido não impede o `fatal`). Esperas acima de 1 dia viram cadeia de `Timer` do Dart (o `setTimeout` do Node estoura em 2^31 ms); acima de 2^62 ns, saturam. Oráculos `golib_dart/test/timer_test.dart` (VM × JS × Wasm) e `timer_context_oracle_test.dart` (programas inteiros contra `go run`, VM × JS × Wasm). ❌ `LoadLocation`/tzdata. Fixtures `timeduration`, `timeformat`, `timejson` |
| `context` | porta de `context/context.go` (`golib_dart/lib/context.dart` + `src/context/impl.dart`): `Context` (interface de shim em `SHIM_INTERFACES`: `deadline()` → `(time.Time, bool)`, `done()` → `go.Chan<go.EmptyStruct>?`, `err()`, `value$(key)`), `background`/`todo`, `withCancel`/`withCancelCause` → `(Context, CancelFunc)`/`(Context, CancelCauseFunc)` (`typedef` de função), `withDeadline`/`withTimeout` (+ `Cause`), `withValue`, `withoutCancel`, `cause`, `afterFunc` (→ `bool Function()`), `canceled`, `deadlineExceeded` (struct vazia por valor: `Timeout()`/`Temporary()`, `%T`/`%#v` do Go). `String()` dos contextos idêntico ao Go (`context.Background.WithCancel.WithValue(main.key, int)`). Implementação de fora (tipo gerado) funciona como pai: acha o `cancelCtx` do shim pela cadeia de `Value` ou propaga com uma goroutine (`go.spawn` + `select`), como o Go. Timers de `WithDeadline` são `time.afterFunc`. ⚠️ `%T`/`stringify` de valor slice/map sem nome dentro do `WithValue` sai com o nome Dart (o valor não carrega o tipo Go); o atalho `afterFuncer` do Go (pai com método `AfterFunc`) cai na goroutine (mesmo efeito); `%T` de `CancelFunc` sai como func sem nome. Oráculos `golib_dart/test/context_test.dart` (VM × JS × Wasm) e `timer_context_oracle_test.dart` |
| `sync` | `Mutex`, `RWMutex`, `Once`, `WaitGroup`, `Pool` (campo `New` → `new$`), `Map$` (`sync.Map`; chave com igualdade de interface), `Cond`/`NewCond`, `Locker`/`AsyncLocker` (interfaces de shim), `OnceFunc`/`OnceValue`/`OnceValues`, como structs de shim. Método síncrono (`Lock`, `Wait`...) continua valendo pra uma goroutine só: esperar o que só outra goroutine faria é o deadlock do Go (`go.fatal`, sem recover); unlock de destravado é o fatal error do Go. Com goroutines (M4), cada um ganha uma variante suspensiva de sufixo `$` (`lock$async`, `rLock$async`, `wait$async`, `do$async`; ver "Concorrência (M4) — runtime"), que o g2d emite numa função `async` (`Wait` sempre; `Lock`/`RLock` só de Mutex disputável, ver "Cor transitiva"; num contexto que precisa ficar síncrono, como `String()`, o `Lock` fica síncrono); a versão síncrona travada com outras goroutines vivas é um limite do g2d (`fatal` com `g2d: ...`). `WaitGroup.Go` (Go 1.25) existe. ⚠️ `Map.Range` em ordem de inserção; `Pool` nunca é esvaziado pelo GC; `%v` de `Map`/`Pool`/`Cond` lança. Fixture `syncshim` |
| `sync/atomic` | `Int32`/`Int64`/`Uint32`/`Uint64`/`Uintptr`/`Bool`/`Value`/`Pointer[T]` (T struct) como structs de shim (`%v` como o Go: `{{} {} 5}`); `Add*`/`Load*`/`Store*`/`Swap*`/`CompareAndSwap*` sobre `go.Ptr`. Decidido no M4: mesmo com goroutines, leitura/escrita simples continua certa — são cooperativas sobre um só event loop, nunca truly paralelas (ao contrário das OS threads que o `atomic` do Go protege), então não há corrida de verdade a impedir. Variantes `*Pointer` (unsafe) → `unsafe:Pointer`. Fixture `syncatomic` |
| `fmt.Fprint`, `Fprintln`, `Fprintf` | `fmt.fprint(w, args)`: a mesma formatação, num só `w.write(bytes)`; `fprint$async`... com `await w.write$async(bytes)` (D2) |
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
  `go.isType`/`go.isIface`/`is`, com a variável ligada por case.
- A classe Dart de uma struct/array é a mesma para `T` e `*T` e declara as
  interfaces dos dois; por isso o teste de interface com métodos
  (`assertIface`, `tryIface`, `isIface`) recebe o method set da interface e,
  para um valor guardado por valor (`$isValue`), confere o method set de `T`
  (`$valueMethods`, em `go.GoValue`; array nomeado também gera
  `$valueMethods`/`$ptrMethods`): `P{}` não satisfaz `Incer` com `Inc` em
  `*P`. O `fmt` segue a mesma regra. Fixture `ifacemethodset`.
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
- O pacote que declara um tipo nomeado `E` (struct, ou nomeado sobre
  básico/slice/map/func/array, não genérico, com method set não vazio)
  **sempre emite** `mixin E$Promote` — getter `$E` anulável + forwarders
  `m() => $E!.m()` — mesmo sem uso local: quem embute `E` mais tarde (no
  mesmo pacote ou em outro) não é conhecido no momento em que `E` é
  emitido. Um único mixin serve embedding por valor e por ponteiro (getter
  sempre anulável; `!` redundante no caso por valor, coberto pelo
  `ignore_for_file`). A struct usa `with E$Promote` (com o import
  qualificado, se `E` for de outro pacote) quando todo o method set de `E`
  é promovido, sem sombreamento nem ambiguidade — o goast/go-types já
  resolve os dois (um método ambíguo simplesmente não aparece no method
  set promovido; dois embutidos de pacotes diferentes com método não
  exportado de mesmo nome **não** são ambíguos, porque no Go um
  identificador não exportado é por pacote — o Dart tem a mesma regra de
  privacidade por library, então os dois mixins convivem na mesma classe
  sem colidir). Com sombreamento, ambiguidade, `E` genérico, `E` de um
  shim da stdlib (sem mixin pra referenciar) ou `E` interface (o valor é
  uma prova de outra classe, sem forwarder concreto pra reusar): os
  forwarders promovidos vão inline.
  ⚠️ Método de tipo de shim que o shim não implementa (`time.Time.GobEncode`)
  não ganha forwarder: chamá-lo dá `shim-simbolo:`, e uma interface que o
  exija não é satisfeita (fixture `embedshim`).
- **Privacidade por library, entre pacotes.** Um método não exportado só
  pode ser citado pelo nome (`_secret`) no Dart gerado a partir da library
  de quem o declara de fato — `_secret` escrito em `b.dart` não é o mesmo
  símbolo que `_secret` escrito em `a.dart`, mesmo que uma classe de `b`
  tenha, por herança/mixin, um `_secret` vindo de `a` (verificado contra
  oráculo `dart analyze`: `The method '_secret' isn't defined for the type
  'W'`). Por isso o mixin `E$Promote` só repassa um método não exportado
  quando é o próprio `E` quem o declara (`owner_pkg(E, index) == E.pkg`,
  seguindo a cadeia de embedding pelo índice do goast); um método não
  exportado que `E` promoveu de um embutido seu **não** entra no
  `E$Promote` de `E` (`mixin` não pode ter `with`, então o mixin de `E`
  não encadeia o do dono de fato). Quem embute `E` resolve: para cada
  método não exportado promovido de outro pacote que nem o mixin do campo
  direto nem um forwarder inline repassa (profundidade ≥ 2, ou `E`
  sombreado), a struct ganha um `with D$Promote` extra do dono de fato `D`,
  com o getter `$D` encadeado pelos campos até ele (`a.T get $T => w.t;`,
  `a.T? get $T => w?.t;` com ponteiro no caminho). ⚠️ `Unsupported`
  `promocao:nao-exportada` quando isso não dá: `D` interface ou genérico
  (sem mixin), campo do caminho não exportado de outro pacote, ou getter
  `$D` já usado por outro mixin da struct.
  Método exportado não tem essa restrição (nome público, a mesma library
  em qualquer lugar) e sempre é repassado.
- Tipo nomeado sobre básico/slice/map/func: o método de receptor ponteiro
  só existe na classe `E$Ptr`. `E$Promote` pede então, além de `$E`, o
  getter `E$Ptr get $E$Ptr`, por onde repassa esses métodos; quem embute
  implementa com a vista sobre o campo (`E$Ptr(go.FieldPtr<S, E>(this,
  'e', ...))`) ou, embutido por ponteiro, o próprio campo (`e!`; o `$E`
  vira `e?.value`). A seleção promovida `h.Inc()` vira `h.Counter.Inc()`
  (`&h.Counter`); o forwarder inline (com sombreamento) usa a mesma vista.
- Tipo local que embute ou é embutido: mixin e getter usam o nome içado
  (`$_main$Q$Promote`, `$$_main$Q`), então locais homônimos em funções
  diferentes não colidem.
- Fixtures `embed`, `embedprivate` (dentro do pacote), `promotenamed`
  (não-struct com método de ponteiro por valor, por ponteiro, em
  profundidade 2, sombreado e por interface; tipos locais homônimos),
  `promotecross` (entre pacotes; embedding por ponteiro `*a.T2`,
  profundidade 2 através de dois pacotes, ambiguidade de método exportado
  entre dois embutidos de pacotes diferentes, e o caso de método não
  exportado de mesmo nome em pacotes diferentes não ser ambíguo) e
  `promotedeep` (não exportado a dois saltos de pacote: por valor, por
  ponteiro no meio, sombreado e de não-struct com receptor ponteiro).

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
  Dart comum: `[3]int | [4]int` (mesmo elemento) usa `go.GoArray<E>` como
  core (índice, len, range; cópia pelo dicionário, `$E.copyOf`); união mista
  (`bool | int64 | string`, `[]byte | string`) e de funcs ficam sem bound,
  e o corpo só move e compara valores: operador sobre T →
  `constraint:operador`, índice/len/range/chamada já recusam
  (`indice:typeparam`...); `P interface{ *T; M }` tem bound `M?` (a
  interface de métodos embutida; P pode ser nil, então `p!.m()`), com
  métodos próprios na constraint → `constraint:ponteiro`. Fixture
  `constraintloose`.
- `/` sobre `T` → `$quo` (truncado nos inteiros, IEEE nos floats); `a /= b`
  → `a = a.$quo(b)` (alvo impuro → `opassign-impuro`). `+` está em
  `GoOrdered` (soma ou concatenação); união só de strings tem bound
  `StringBase<T>`, e uma constante string num contexto de T vira
  `$T.zero().$wrapStr(...)`. Fixture `genericosptr`.
- `*T` no genérico é `go.Ptr<T>`; instanciado com struct/array (o próprio
  objeto fora do genérico), a chamada passa a vista `go.valPtr<P>(x)`
  (`go.ValPtr`: `*p = v` é `$set` in-place, ler `*p` copia, `==` por identidade do objeto)
  e desfaz o resultado `*T` com `go.ptrTarget<P>(r)`; `*N` com métodos
  (`N$Ptr`) já é um `go.Ptr<N>` no argumento. Também em `f[P]` como valor.
  Fixture `genericosptr`. ⚠️ `*T` aninhado (`[]*T`, `func(*T)`, `map[K]*T`,
  resultado múltiplo...), resultado `*N` com métodos e resultado de
  genérico `async` → `generico:ptr-valor`; métodos e campos `*T` de tipo
  genérico instanciado com struct/array não são convertidos (o dump não liga
  a instância à origem; dá erro no `dart analyze`).
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
`typedef`. Os testes de tipo usam `is T` (reificado). A reflexão (abaixo)
lê o descritor pelo próprio objeto (`go.Typed.$rtype`), nunca por
`runtimeType`.

## Reflexão (M5, D1)

Decisão do dono (2026-10-04): o g2d vê o programa inteiro e gera, para cada
tipo, um dicionário estático refletível (nome, tipo, tag, getter e setter
como closures, métodos); o `reflect` do Dart só lê esse dicionário.
`dart:mirrors` continua proibido. Fixtures `reflectbasic` (um pacote) e
`reflectcross` (descritores entre pacotes, `PkgPath` de campo não exportado).

**Quando gera.** Só num grafo reflexivo: algum pacote importa `reflect` ou
`encoding/json` (`REFLECT_PKGS` em `g2d/config.py`; `ColorTable.reflective`
no pipeline e no audit). Fora disso a saída não muda. Num grafo reflexivo,
todo tipo nomeado de pacote transpilado ganha descritor; o tipo genérico
ganha a fábrica estática `$rtOf<T>($T)`, que monta o descritor da instância
(`Box[int]`: nome `Box[int]`, `String()` `main.Box[int]`, argumento nomeado
com o import path inteiro, como o Go) uma vez por argumentos de tipo, com
tamanho e offsets calculados no runtime (`go.rtGeneric`).
⚠️ Default escolhido no lugar de "só os tipos que chegam a `reflect` ou
`interface{}`": a análise de alcance fica para depois, e o tree shaking do
AOT/dart2js descarta os descritores não usados.

**Descritor** (`golib_dart/lib/src/reflect/rtype*.dart`, `go.RType<T>`, T =
representação Dart do tipo). Instâncias canônicas, comparáveis por
identidade como o `reflect.Type` do Go: tipo nomeado em `static final $rt`
na classe gerada (struct, nomeado, array nomeado, interface nomeada) e
`$rtype` de instância (`go.Typed`); básicos são singletons (`go.rtInt`...);
compostos sem nome saem de caches (`ptrTo`, `sliceOf`, `arrayOf`, `chanOf`,
`map` por despacho duplo). Struct: campos `go.RField` com nome, pacote (só
os não exportados), tag, embutido, offset do layout amd64 e getter/setter
como closures. Métodos: method set de T e de `*T` (nomes Go ordenados) e a
descritor da assinatura de cada um (`Method.Type` com o receptor).

**Tipo dinâmico** (`reflect.TypeOf(x)` com `x` interface): `$rtype` do
objeto; básicos pela classe fixa; slice/map/array/chan pelo T reificado
(`Elem.type`, `Elem.$with`, `GoMap.$withKV`, `Ptr.$withElem`, `Chan.$with`);
func sem nome pelo `go.Func` (assinatura). Com tipo estático concreto, o g2d
passa o descritor direto (`reflect.typeOf$static`/`valueOf$static`,
`reflect.TypeFor[T]()` → `typeFor(T.$rt)`), o que cobre ponteiro nil
tipado (`(*I)(nil)`).

**Value** (`src/reflect/value*.dart`): descritor + representação + closures
de leitura/escrita do lugar de onde veio (campo, elemento, `*p`), com as
flags do Go (endereçável, só leitura por campo não exportado). `Set*`,
`Field*`, `Index`, `Slice`, `Elem`, `Addr`, `MapIndex`/`SetMapIndex`/
`MapKeys`/`MapRange`, `Len`/`Cap`/`SetLen`, `IsNil`/`IsZero`, `Convert`,
`Interface`, `New`, `Zero`, `MakeSlice`, `MakeMap`, `Append`, `Copy`,
`Swapper`, `DeepEqual` (com ciclos), `StructTag.Get`/`Lookup` (port do
Go), com os mesmos panics (`*reflect.ValueError`, "using unaddressable
value"...). O `fmt` imprime um `reflect.Value` como o valor que ele guarda.

**Funções** (`src/reflect/func.dart`). O descritor de um tipo func
(`go.rtFuncOf`) traz parâmetros, resultados, variádico e a cor `async`
da assinatura: `NumIn`/`In`/`NumOut`/`Out`/`IsVariadic`. `Value.Call`/
`CallSlice` conferem aridade e tipos com as mensagens do Go, empacotam o
variádico e chamam a closure por `Function.apply` (VM, JS e Wasm); dois ou
mais resultados voltam do record Dart. `Value.Method`/`MethodByName`
ligam o receptor pelo tear-off que o descritor do tipo guarda (`binds`;
`pbinds` para os de `*N` de nomeado não struct, pela vista `N$Ptr`), e
`Method.Func` recebe o receptor como primeiro argumento. `MakeFunc` monta
uma closure com o tipo Dart exato (parâmetros e resultados reificados por
`RType.$with`; até 8 parâmetros e 5 resultados, `src/reflect/make_func.dart`
gerado por `golib_dart/tool/gen_make_func.py`); `FuncOf` acha o tipo
canônico pela assinatura. **D9 (2026-10-04): `Call`/`CallSlice` sempre
suspendem** (a cor não atravessa a reflexão, e a função guardada pode ser
`async`: os construtores do `dig`/`fx`): o g2d os trata como chamada do
shim que suspende (`SUSPENDING_SHIM`), emite `await v.call$async(in)` e
quem chama ganha a cor `async`. Num contexto que precisa ficar síncrono
(`String()`, `Error()`...) a chamada fica `call$` (`SYNC_FALLBACK`), que
dá panic explícito só se a função chamada suspender; uma função `async`
só por chamar por reflexão é *branda* e ganha a gêmea `f$sync` do D2 para
esses contextos (`directSoft` em `g2d/analysis/color.py`). Fixtures
`reflectcall`, `reflectcallasync`, `reflectcallsuspende`.

⚠️ Limites: `Value.Call` de função que suspende dentro de `String()`/`Error()`
e outros contextos síncronos dá panic explícito; um valor func cuja classe
de assinatura fica `async` só por `Value.Call` não tem gêmea síncrona
(chamá-lo num contexto síncrono é `async:contexto-sincrono`, ex.
`gogo/protobuf/proto`); `Value.Call` numa seção crítica não torna o Mutex
disputável (se a função chamada suspender com ele travado, o `Lock`
síncrono de outra goroutine falha explícito);
`NewAt`, `UnsafeAddr`, `UnsafePointer`, `SliceHeader`/`StringHeader`
dependem do `unsafe` (D5); método promovido de struct genérica não entra
em `binds` (sem mixin); tipo de shim sem `$rt` em `SHIM_RTYPES` (têm:
`json.Number`/`Delim`, `time.Time`/`Duration`/`Month`/`Weekday`) e
instância de genérico sobre básico, array ou interface têm descritor opaco
(listar campos dá panic explícito).
`Implements` compara nomes de métodos, não assinaturas. A direção de um
`chan` guardado em interface sai sempre `chan` (o `Chan<T>` não guarda a
direção).

**`StructOf`** (`src/reflect/struct_of.dart`, fixture `reflectstructof`): o
tipo é um `RType<DynStruct>` comum, com o `String()` do Go (`struct { A int
"json:\"a\""; B string }`), layout amd64 calculado no primeiro uso e cache
canônico (mesma lista de campos → o mesmo `Type`; lista vazia → o `struct
{}` do runtime). O valor é um `reflect.DynStruct` (`GoStruct` com os campos
numa lista), então `New`/`Zero`/`Field(i).Set*`, `Interface()`, `fmt`
(`%v`, `%+v`, `%#v`, `%T`), `==` (panic `comparing uncomparable type` se
não comparável), `DeepEqual`, chave de map, slice e aninhamento funcionam
como no Go, com os panics do Go para campos inválidos (sem nome, nome
inválido, sem tipo, minúsculo sem `PkgPath`, duplicado, `PkgPath`
divergente, embutido ilegal ou com métodos fora do primeiro campo).
⚠️ Os métodos do campo embutido não são promovidos (`NumMethod` 0); o Go
devolve o tipo do compilador quando ele já existe no binário (`StructOf` de
`A int` é `TypeOf(struct{ A int }{})`), aqui só para `struct {}`, então
`x.(struct{ A int })` sobre um valor de `StructOf` falha.

**`Select` e canais** (`src/reflect/select.dart`, `chan_ops.dart`, fixture `reflectselect`):
`reflect.Select`, `SelectCase`/`SelectDir`, `Value.Send`/`Recv`/`TrySend`/
`TryRecv`/`Close`, `ChanOf` e `MakeChan` sobre `go.Chan` e o `select` do
runtime, com os panics do Go. O que bloqueia segue a versão dupla do D2:
`select`/`send`/`recv` síncronos só completam o que já está pronto (esperar
cai no `fatal` `g2d:`, como `WaitGroup.wait`) e `select$async`/
`send$async`/`recv$async` esperam de verdade; o g2d chama sempre a
`$async` (`SUSPENDING_SHIM`, suspensão dura), o que colore quem chama
`reflect.Select` mesmo com `SelectDefault`. ⚠️ Method value (`f :=
v.Recv`) não foi coberto; a escolha entre casos prontos é pseudoaleatória
(`Random` do Dart, como o `select` gerado).


## Código gerado

- Cabeçalho `// Code generated by g2d ... DO NOT EDIT.` e
  `ignore_for_file: unused_element, unused_field, dead_code, unnecessary_non_null_assertion`.
  O Go aceita esses casos; o Dart só avisaria.
- Os descritores `const _$eN = go.Elem<T>(...)` ficam no fim da library.
- A saída é canonicalizada por `dart format` e precisa passar em
  `dart analyze --fatal-infos`.

## Interfaces entre pacotes (D8)

Decisão do dono (2026-10-05): **`implements` sobre o grafo, restrito às
conversões que acontecem**. O Go satisfaz interfaces estruturalmente; o
`implements` do goast só olha as interfaces que o pacote do tipo enxerga (as
dele, dos imports diretos e `error`). Um `a.T` passado como `b.Namer` num
`c` que importa os dois não seria um `b.Namer` no Dart; um tipo com
`String()` num pacote sem `import "fmt"` imprimiria os campos.

- O goast (v10) lista por pacote as conversões tipo concreto → interface
  (`conversions`) e os alvos dinâmicos (`asserts`: type assertion, `case I:`,
  interface → interface; `tools/goast/README.md`).
- `g2d/analysis/ifacecross.py`: cada pacote vira um `IfaceSummary` (tipos
  nomeados não genéricos com o method set em assinaturas canônicas,
  conversões, asserts); a `IfaceTable` do grafo diz que T precisa de I se
  algum pacote converte T para I, ou se T vira interface em algum lugar
  (escapa) e algum pacote testa I e o method set de T cobre I. As interfaces
  que os shims testam por dentro (`fmt.Stringer`, `fmt.GoStringer`,
  `fmt.Formatter`, `encoding.TextMarshaler`/`TextUnmarshaler`,
  `json.Marshaler`/`Unmarshaler`) contam como testadas sempre.
- A classe de T ganha o `implements` e a library dele importa a da interface
  (o Dart aceita import cíclico). Só entram interfaces nomeadas não
  genéricas de pacote transpilado ou de shim (`SHIM_INTERFACES`) e anônimas
  canônicas (`Iface$<hash>`); tipos nomeados não genéricos de nível de
  pacote.
- Cor: o método de T e o da interface ficam no mesmo grupo
  (`ColorTable.set_ifaces`).
- O audit reemite sem o `implements` o pacote cuja interface mora numa
  library que não foi emitida (`IfaceTable.missing`): ele não fica
  dependente de um pacote que não é dependência Go dele.

Fixtures: `ifacecross` (interface nomeada entre pacotes por argumento,
`*T` por ponteiro, type assertion e type switch sobre tipo que só virou
`any`, interface anônima entre pacotes, `fmt.Stringer` e `sort.Interface`
sem import) e `ifaceshim`.

⚠️ Limites: tipo genérico e interface genérica ficam de fora (o `implements`
deles continua o do goast); interface anônima com embutida continua uma por
library; interface **nomeada** do pacote testada contra valor de classe de
shim (`type timeouter interface{ Timeout() bool }` com
`context.DeadlineExceeded`) dá `false`
(`TODO/P2-design-interface-nomeada-valor-de-shim.md`); a atribuição de uma
interface a outra que não a embute continua sem cast no Dart.

