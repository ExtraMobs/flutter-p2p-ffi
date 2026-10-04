/// Shim do pacote Go `reflect` sobre descritores estáticos (M5, decisão D1).
///
/// O g2d enxerga o programa inteiro e gera, para cada tipo nomeado de um
/// grafo que usa reflexão, um descritor [RType] estático (`static final $rt`
/// na classe gerada): nome, pacote, kind, campos com tag, getter e setter
/// como closures e method sets. Tipos sem nome (`[]T`, `*T`, `map[K]V`...)
/// são montados em runtime a partir dos descritores dos elementos, com cache
/// (um objeto por tipo Go: `==` entre `reflect.Type` é identidade, como no
/// Go). O `reflect` só lê esses descritores; `dart:mirrors` não entra.
///
/// O valor dinâmico de uma interface acha o descritor pelo próprio objeto
/// ([rtypeOf]): classes geradas implementam [Typed]; os tipos básicos são
/// classes fixas; `go.Slice`/`go.GoMap`/`go.GoArray` levam o descritor do
/// elemento no `go.Elem`; `go.Ptr` reifica o tipo apontado.
// ignore_for_file: library_prefixes
library;

import 'dart:typed_data';

import 'builtin.dart';
import 'fmt.dart' as fmt;
import 'strconv.dart' as strconv;
import 'fixed_types/golang.dart' as Golang;

part 'src/reflect/kind.dart';
part 'src/reflect/rtype.dart';
part 'src/reflect/rtype_make.dart';
part 'src/reflect/dynamic.dart';
part 'src/reflect/type_api.dart';
part 'src/reflect/struct_field.dart';
part 'src/reflect/value.dart';
part 'src/reflect/value_set.dart';
part 'src/reflect/value_map.dart';
part 'src/reflect/ops.dart';
part 'src/reflect/deep_equal.dart';

/// `reflect.Type`: o descritor ([RType]). Tipos são canônicos, então
/// `t1 == t2` do Go é identidade.
typedef Type = RType;

/// `reflect.TypeOf(i)`: o tipo dinâmico de `i` (nil para interface nil).
RType? typeOf(Object? i) => rtypeOf(i);

/// `reflect.TypeOf(x)` com `x` de tipo estático concreto: o g2d já sabe o
/// tipo ([t]); `x` foi avaliado pelo chamador.
RType? typeOf$static(Object? x, RType t) => t;

/// `reflect.TypeFor[T]()`: o g2d passa o descritor de T.
RType? typeFor(RType t) => t;

/// `reflect.ValueOf(i)`.
Value valueOf(Object? i) {
  if (i == null) return Value();
  return Value._of(rtypeOf(i)!, $repOf(i));
}

/// `reflect.ValueOf(x)` com `x` de tipo estático concreto ([t]): o valor já
/// convertido para interface (struct por valor é uma cópia).
Value valueOf$static(Object? x, RType t) => Value._of(t, $repOf(x));

/// `reflect.PtrTo(t)` / `reflect.PointerTo(t)`.
RType? ptrTo(RType? t) => _needType(t, 'PointerTo').ptrTo();
RType? pointerTo(RType? t) => _needType(t, 'PointerTo').ptrTo();

/// `reflect.SliceOf(t)`.
RType? sliceOf(RType? t) => _needType(t, 'SliceOf').sliceOf();

/// `reflect.MapOf(key, elem)`.
RType? mapOf(RType? key, RType? elem) {
  final k = _needType(key, 'MapOf');
  if (!k.$isComparable) {
    throw Panic(
      Golang.String.fromDart('reflect.MapOf: invalid key type ${k.$str}'),
    );
  }
  return rtMap(k, _needType(elem, 'MapOf'));
}

/// `reflect.ArrayOf(n, t)`.
RType? arrayOf(Golang.Int n, RType? t) =>
    _needType(t, 'ArrayOf').arrayOf(n.toInt());

RType _needType(RType? t, String fn) =>
    t ??
    (throw Panic(Golang.String.fromDart('reflect: nil type passed to $fn')));
