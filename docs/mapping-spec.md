# Mapping spec Go → Dart

Correspondência semântica implementada pelo `g2d` (fonte: `g2d/mapping.py`,
`g2d/emit.py`). Toda construção fora desta tabela levanta `Unsupported` com a
posição Go — o transpilador nunca emite código aproximado em silêncio.

Legenda: ✅ fiel · ⚠️ fiel no caso comum, limite conhecido (coluna Limite) · ❌ não suportado ainda.

## Unidade de compilação

| Go | Dart | |
|---|---|---|
| pacote (todos os arquivos) | uma library `lib/<import path>.dart` | ✅ |
| `import "fmt"` | `import 'package:golib_dart/fmt.dart' as fmt;` (só se usado no Dart) | ✅ |
| universo (`error`, `panic`) | `import 'package:golib_dart/builtin.dart' as go;` | ✅ |
| import de pacote não-stdlib | — | ❌ (M2: grafo) |
| import `_` / `.` | — | ❌ |

## Identificadores

| Go | Dart | Limite |
|---|---|---|
| tipo exportado `Greeter` | `Greeter` | |
| tipo não exportado `point` | `_point` | |
| func/var/const/campo/método exportado `HTTPServer` | `httpServer` (lowerCamel ciente de siglas) | ⚠️ `FOO` e `Foo` no mesmo escopo colidem |
| idem não exportado `add` | `_add` (privado da library = do pacote) | |
| `main` do pacote `main` | `main` | |
| local/parâmetro | nome Go; repetido na função ou igual a nome de library → `x$1` | |
| palavra reservada Dart (`new`, `in`, ...) | sufixo `$` (`new$`) | |
| temporários do transpilador | `$tN` (Go não permite `$`) | |

## Tipos

| Go | Dart | Limite |
|---|---|---|
| `int`, `int8..64`, `uint..64`, `uintptr`, `byte`, `rune` | `int` | ⚠️ sem wraparound de largura; `uint64` > 2⁶³ |
| `float32`, `float64` | `double` | ⚠️ `float32` com precisão de 64 bits |
| `string` | `String` | ⚠️ UTF-16, não bytes: `len(s)`/`s[i]` ❌ |
| `bool` | `bool` | |
| `error` | `go.GoError?` | |
| `any` / `interface{}` | `Object?` | |
| struct nomeada | `class` (ver abaixo) | ⚠️ semântica de valor ❌ (cópia na atribuição, `==` estrutural) |
| `*T` (T struct) | `T?` | ⚠️ ponteiro para não-struct ❌ |
| `[]T` | `List<T>` | ⚠️ sem `cap`/aliasing de backing array; nil ≡ vazio |
| `map[K]V` | `Map<K, V>` | ⚠️ nil ≡ vazio |
| `func(A) R` | `R Function(A)?` | |
| múltiplos resultados | record `(A, B)` | |
| nomeado sobre não-struct, genéricos, arrays, chans, complex | — | ❌ |

## Structs

```go
type Greeter struct { Name string; next *Greeter }
```
```dart
class Greeter {
  Greeter({String? name, Greeter? next}) : name = name ?? '', _next = next;
  String name;
  Greeter? _next;
}
```

- Construtor com parâmetros nomeados opcionais; ausente = zero value.
- `T{Name: x}` e `T{x}` → `T(name: x)`; `&T{...}` → o mesmo objeto.
- Métodos (receptor valor ou ponteiro) viram métodos da classe; o receptor
  vira `this`. ⚠️ receptor valor não copia.
- Campos em branco (`_`) são omitidos. Embedding: campo comum; promoção ❌.

## Valores e expressões

| Go | Dart |
|---|---|
| expressão constante (incl. `iota`, constantes importadas) | literal do valor exato calculado pelo `go/types` |
| constante do próprio pacote | referência pelo nome |
| literal string | aspas simples; `\`, `'`, `$` e controles escapados |
| `a / b` inteiro | `a ~/ b` |
| `a % b` inteiro | `a.remainder(b)` (truncado, como Go) |
| `a &^ b` | `a & ~b` |
| `^x` | `~x` |
| precedência | parênteses onde a precedência Dart difere da Go |
| `m[k]` (leitura) | `m[k] ?? zero` |
| `p.f` com `p *T` | `p!.f` (nil → exceção, como panic) |
| `*p` | `p!` |
| `f(x)` com `f` variável de função | `f!(x)` |
| variádico `f(a, b)` / `f(s...)` | `f(<T>[a, b])` / `f(s)` |
| `T(x)` int↔float | `toInt()` (trunca) / `toDouble()` |
| `len(s)` slice/map | `s.length` |
| `append(s, x)` / `append(s, t...)` | `<T>[...s, x]` / `<T>[...s, ...t]` ⚠️ sempre copia (O(n)) |
| `delete(m, k)` | `m.remove(k)` |
| `panic(v)` | `throw go.Panic(v)` |
| func literal | função anônima |

## Statements

| Go | Dart |
|---|---|
| `x := e` / `var x T = e` | `T x = e;` (tipo sempre explícito) |
| `var x T` | `T x = <zero>;` |
| `a, b := f()` (todos novos) | `var (a, b) = f();` |
| `a, b = b, a` | `(a, b) = (b, a);` |
| `a, err := f()` (misto) / alvos não-identificador | `final $t = f(); T a = $t.$1; err = $t.$2;` |
| `_ = e` | `e;` |
| `x op= e` | idem; `/=` → `~/=`; `%=` → `remainder`; em `m[k]` → `m[k] = (m[k] ?? zero) op e` |
| resultados nomeados + `return` nu | locais inicializados no zero + `return (q, r);` |
| `if init; cond {}` | `{ init; if (cond) {} }` |
| `for init; cond; post {}` / `for cond {}` / `for {}` | `for (...)` / `while (cond)` / `while (true)` |
| `for i, v := range slice` | índice sobre cópia da referência, `len` avaliado uma vez |
| `for k, v := range map` | itera `keys.toList()` e pula chaves removidas (Go permite `delete` durante o range) |
| `for i := range n` | `for (var i = 0; i < n; i++)` |
| `switch` / `switch {}` | cadeia `if/else` (cases Go aceitam expressões arbitrárias); `break`/`fallthrough` ❌ |
| rótulos, `break L`, `continue L` | rótulo no laço Dart |
| `go`, `defer`, `select`, type switch, `goto`, range sobre string/chan/func | ❌ |

## Stdlib (shims em `golib_dart/`)

| Símbolo | Shim |
|---|---|
| `fmt.Println` | `fmt.println(List<Object?>)` → `(int, GoError?)` |
| `fmt.Sprint` | `fmt.sprint(List<Object?>)` |
| `%v` | `fmt.formatV`: `nil` → `<nil>`, floats como `strconv.FormatFloat(f, 'g', -1, 64)` |

## Código gerado

- Cabeçalho `// Code generated by g2d ... DO NOT EDIT.` e
  `ignore_for_file: unused_element, unused_field, dead_code, unnecessary_non_null_assertion`
  (Go aceita esses casos; o Dart só avisaria).
- Saída canonicalizada por `dart format`; precisa passar em `dart analyze --fatal-infos`.
