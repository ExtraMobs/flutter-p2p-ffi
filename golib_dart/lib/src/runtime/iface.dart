/// Valores de interface Go: type assertion, comma-ok e type switch.
library;

import '../../fixed_types/golang.dart' show GoTyped;
import 'panic.dart';
import 'ptr.dart';
import 'struct.dart';

/// Nome Go do tipo dinâmico de um valor em interface (mensagens de erro).
/// Uma struct guardada como ponteiro aparece como `*T`.
String goTypeName(Object? v) => switch (v) {
  null => 'nil',
  GoValue s when !s.$isValue => '*${s.$goType}',
  GoTyped t => t.$goType,
  bool() => 'bool',
  _ => v.runtimeType.toString(),
};

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
  // Interface nil nunca satisfaz uma assertion (mesmo com T anulável).
  if (x == null || x is! T) return false;
  if (struct == null) return true;
  return x is GoValue && x.$isValue == struct;
}

/// `x.(T)` para T concreto. Struct por valor sai copiada.
T assertType<T>(Object? x, String iface, String target, {bool? struct}) {
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
  if (!isType<T>(x, struct: struct)) return (zero, false);
  if (struct == true) return ((x as GoValue).$copy() as T, true);
  return (_unwrapNil(x) as T, true);
}

/// `x.(I)` para I interface; [methods] = method set de I (nomes Go
/// ordenados), para a mensagem de erro do Go.
T assertIface<T>(Object? x, String target, List<String> methods) {
  if (x != null && x is T) return x as T;
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

/// `v, ok := x.(I)` para I interface.
(T?, bool) tryIface<T>(Object? x) =>
    x != null && x is T ? (x as T, true) : (null, false);

/// `==` entre valores de interface: struct por valor compara campos,
/// ponteiro (struct guardada por referência) compara identidade.
bool ifaceEq(Object? a, Object? b) {
  if (a is GoValue && b is GoValue) {
    if (!a.$isValue || !b.$isValue) return identical(a, b);
  }
  return a == b;
}
