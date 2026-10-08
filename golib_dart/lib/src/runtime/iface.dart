/// Valores de interface Go: type assertion, comma-ok e type switch.
library;

import '../../fixed_types/golang.dart' show GoTyped;
import 'panic.dart';
import 'ptr.dart';
import 'slice.dart';
import 'map.dart';
import 'struct.dart';

/// Valor de classe de shim guardado numa interface gerada que o shim não
/// declara (D8: `return new(bytes.Buffer)` como `LW`, `net.ListenUDP(...)`
/// como o `transport.UDPConn` do pion). O g2d gera, no ponto da conversão,
/// a subclasse que implementa a interface e repassa cada método a [$v]. O
/// embrulho é transparente: assertion, type switch, `==`, `%T`/`%v` e o
/// `reflect` veem o valor do shim.
abstract class ShimIface<S extends Object> {
  ShimIface(this.$v);

  /// O valor do shim (a sentinela `$nil` para o ponteiro nil tipado).
  final S $v;

  @override
  bool operator ==(Object other) => ifaceEq($v, other);

  @override
  int get hashCode => $v.hashCode;

  @override
  String toString() => $v.toString();
}

/// O valor dinâmico de uma interface sem o embrulho [ShimIface].
Object? unShim(Object? x) => x is ShimIface ? x.$v : x;

/// Nome Go do tipo dinâmico de um valor em interface (mensagens de erro).
/// Uma struct guardada como ponteiro aparece como `*T`.
String goTypeName(Object? v) => switch (v) {
  null => 'nil',
  ShimIface s => goTypeName(s.$v),
  Func f => f.sig,
  GoValue s when !s.$isValue => '*${s.$goType}',
  GoTyped t => t.$goType,
  bool() => 'bool',
  // Ponteiro para não-struct: o tipo do alvo (o nil tipado não o tem).
  Ptr p when p is! NilPtr => '*${goTypeName(p.value)}',
  _ => v.runtimeType.toString(),
};

/// Valor de um tipo func **sem nome** guardado numa interface (`any(f)`,
/// argumento variádico de `...any`...). O Dart só testa subtipo entre tipos
/// de função (`void` é o topo do retorno, parâmetros são contravariantes),
/// mas o Go exige o tipo idêntico em `x.(F)`/`case F:`. Por isso o valor
/// viaja com o nome Go do tipo (o mesmo de `%T`), comparado bit a bit em vez
/// de `is`. Tipo func **nomeado** (`type Op func(...)`) não passa por aqui:
/// a classe gerada já dá identidade nominal (`x is Op`).
final class Func {
  const Func(this.value, this.sig, [this.type]);

  /// A closure Dart. `null` é o zero value de um tipo func: guardado numa
  /// interface ele não é nil (como ponteiro/slice/map/chan nil).
  final Function? value;

  /// Nome Go do tipo, como em `%T` (ex. `func(int) int`, `func() (int, error)`).
  final String sig;

  /// Descritor de reflexão do tipo (thunk; só num grafo que usa reflexão).
  final Object Function()? type;
}

/// Valor de tipo func nomeado (`type Op func(int) int`): a classe gerada
/// guarda a closure em `$f` (o `reflect` a chama).
abstract interface class FuncValue {
  Function? get $f;
}

/// O valor dinâmico em [x] é exatamente o tipo func sem nome [sig]?
///
/// ponytail: [x] só chega embrulhado em [Func] quando o g2d viu, na
/// conversão para interface, um tipo func concreto (`g2d/services/values.py`
/// `coerce`); um parâmetro de tipo com union de funcs (`~func() | ~func()
/// error`, ex. go.uber.org/fx.Callable) instanciado com T func não carrega o
/// nome Go do tipo dentro do corpo genérico, então cai no teste de subtipo
/// do Dart (limite conhecido, `docs/mapping-spec.md`).
bool isFuncType<T>(Object? x, String sig) {
  if (x == null) return false;
  if (x is Func) return x.sig == sig;
  return x is T;
}

/// Desembrulha o valor de um `case F:`/`x.(F)` de func sem nome já confirmado
/// por [isFuncType] (case único de um type switch: o `is`/`as` já foi feito
/// na condição, aqui só sai o valor Dart certo).
T unwrapFunc<T>(Object? x) => x is Func ? x.value as T : x as T;

/// `x.(F)` para F tipo func sem nome.
T assertFunc<T>(Object? x, String iface, String target) {
  if (x is Func) {
    if (x.sig == target) return x.value as T;
  } else if (x is T) {
    return x;
  }
  final dyn = x == null ? 'nil' : goTypeName(x);
  throw Panic(
    RuntimeError('interface conversion: $iface is $dyn, not $target'),
  );
}

/// `v, ok := x.(F)` para F tipo func sem nome.
(T, bool) tryFunc<T>(Object? x, T zero, String sig) {
  if (x == null) return (zero, false);
  if (x is Func) return x.sig == sig ? (x.value as T, true) : (zero, false);
  return x is T ? (x as T, true) : (zero, false);
}

/// Ponteiro para struct tirado de uma interface: a sentinela vira nil.
T? unNil<T extends Object>(T? x) => x is GoValue && x.$nilPtr ? null : x;

/// Ponteiro nil tipado guardado na interface (sentinela ou NilPtr) → null.
Object? _unwrapNil(Object? x) =>
    (x is GoValue && x.$nilPtr) ||
        x is NilPtr ||
        (x is PtrView && x.$p is NilPtr)
    ? null
    : x;

/// O valor dinâmico em `x` tem o tipo concreto `T`?
/// [struct]: `true` para struct por valor (`x.(T)`), `false` para ponteiro
/// para struct (`x.(*T)`), `null` para os demais tipos.
bool isType<T>(Object? x, {bool? struct}) {
  x = unShim(x);
  // Interface nil nunca satisfaz uma assertion (mesmo com T anulável).
  if (x == null || x is! T) return false;
  if (struct == null) return true;
  return x is GoValue && x.$isValue == struct;
}

/// `x.(T)` para T concreto. Struct por valor sai copiada.
T assertType<T>(Object? x, String iface, String target, {bool? struct}) {
  x = unShim(x);
  if (isType<T>(x, struct: struct)) {
    if (struct == true) return (x as GoValue).$copy() as T;
    return _unwrapNil(x) as T;
  }
  final dyn = x == null ? 'nil' : goTypeName(x);
  throw Panic(
    RuntimeError('interface conversion: $iface is $dyn, not $target'),
  );
}

/// `v, ok := x.(T)` para T concreto.
(T, bool) tryType<T>(Object? x, T zero, {bool? struct}) {
  x = unShim(x);
  if (!isType<T>(x, struct: struct)) return (zero, false);
  if (struct == true) return ((x as GoValue).$copy() as T, true);
  return (_unwrapNil(x) as T, true);
}

/// O valor dinâmico em `x` satisfaz a interface `I` (classe Dart [T],
/// [methods] = method set de I)? A classe Dart de uma struct/array é a mesma
/// para T e *T e declara as interfaces dos dois; um valor guardado por valor
/// ([GoValue.$isValue]) só tem o method set de T (`$valueMethods`), como no
/// Go: `P{}` não é `Incer` se `Inc` é de `*P`. O [ShimIface] que não é T
/// é testado pelo valor do shim (`x.(io.Reader)` de um `LW`).
bool isIface<T>(Object? x, List<String> methods) {
  x = _ifaceOf<T>(x);
  return x != null &&
      x is T &&
      (x is! GoValue || !x.$isValue || methods.every(x.$methods.contains));
}

Object? _ifaceOf<T>(Object? x) => x is ShimIface && x is! T ? x.$v : x;

/// `x.(I)` para I interface; [methods] = method set de I (nomes Go
/// ordenados), também para a mensagem de erro do Go.
T assertIface<T>(Object? x, String target, List<String> methods) {
  x = _ifaceOf<T>(x);
  if (isIface<T>(x, methods)) return x as T;
  if (x == null) {
    throw Panic(
      RuntimeError('interface conversion: interface is nil, not $target'),
    );
  }
  final have = x is GoTyped ? x.$methods : const <String>[];
  final missing = methods.firstWhere(
    (m) => !have.contains(m),
    orElse: () => methods.isEmpty ? '' : methods.first,
  );
  throw Panic(
    RuntimeError(
      'interface conversion: ${goTypeName(x)} is not $target: missing method $missing',
    ),
  );
}

/// `v, ok := x.(I)` para I interface ([methods]: ver [isIface]).
(T?, bool) tryIface<T>(Object? x, [List<String> methods = const []]) =>
    isIface<T>(x, methods) ? (_ifaceOf<T>(x) as T, true) : (null, false);

/// `==` entre valores de interface: struct por valor compara campos,
/// ponteiro (struct guardada por referência) compara identidade.
bool ifaceEq(Object? a, Object? b) {
  a = unShim(a);
  b = unShim(b);
  if (a is GoValue && b is GoValue) {
    if (!a.$isValue || !b.$isValue) return identical(a, b);
  }
  return a == b;
}

/// O método está no method set do valor dinâmico? Struct/array por valor
/// numa interface só tem os de receptor valor (`$valueMethods`).
bool goHasMethod(Object v, String name) {
  if (v is GoTyped) return v.$methods.contains(name);
  return true;
}

/// `reflectlite.TypeOf(v).Comparable()`: slice, map e func não são
/// comparáveis, nem struct/array que os contenham.
bool goComparable(Object? v) => switch (v) {
  null => true,
  Slice() || GoMap() || Function() || Func() => false,
  GoStruct s when s.$isValue => s.$fields.every(goComparable),
  _ => true,
};
