/// Ponteiros Go para valores que não são struct (`*int`, `*string`...).
library;

import '../../fixed_types/golang.dart' show GoTyped;
import 'panic.dart';
import 'struct.dart';

/// `*T` quando T não é struct (uma struct é o seu próprio endereço).
/// Igualdade = mesmo endereço.
abstract interface class Ptr<T> {
  T get value;
  set value(T v);

  /// `*p = v` se v é atribuível a T (o `errors.As`); false senão.
  bool $assignIfIs(Object? v);

  /// T é interface ou implementa `error`? (o `errors.As` exige.)
  bool $errorTargetOk();
}

/// T implementa `error`, ou é anulável sem ser ponteiro de dado/struct
/// (então é interface): o que o `errors.As` aceita como `*target`.
bool _errorTarget<T>() {
  if (<T>[] is List<GoError?>) return true;
  if (null is! T) return false; // string, int, slice, map...: não é error
  return !(<T>[] is List<Ptr?> || <T>[] is List<GoValue?>);
}

/// v (valor dinâmico de uma interface) é atribuível a T? Struct guardada por
/// valor não serve a um `*S` (T é `S?`), só a uma interface que S implementa.
bool _accepts<T>(Object? v) =>
    v is T && !(v is GoValue && v.$isValue && v.$classIs<T>());

/// Ponteiro nil tipado (`(*int)(nil)`) dentro de uma interface, que no Go
/// não é nil. Ler ou escrever dá o panic de nil pointer.
final class NilPtr<T> implements Ptr<T> {
  const NilPtr();

  @override
  T get value => nilDeref();

  @override
  set value(T v) => nilDeref();

  @override
  bool $assignIfIs(Object? v) => nilDeref();

  @override
  bool $errorTargetOk() => _errorTarget<T>();

  @override
  bool operator ==(Object other) => other is NilPtr<T>;

  @override
  int get hashCode => 0;
}

/// Variável cujo endereço é tomado (`&x`) ou criada por `new(T)`: ela passa
/// a morar numa caixa, e a identidade da caixa é o endereço.
final class Box<T> implements Ptr<T> {
  Box(this.value);

  @override
  T value;

  @override
  bool $assignIfIs(Object? v) {
    if (!_accepts<T>(v)) return false;
    value = v as T;
    return true;
  }

  @override
  bool $errorTargetOk() => _errorTarget<T>();
}

/// `*N` para N nomeado não-struct com métodos (`type Counter int`): a classe
/// gerada `N$Ptr` estende esta vista sobre qualquer [Ptr] (caixa, elemento,
/// campo), com os métodos de receptor ponteiro e as interfaces de `*N`.
/// Igualdade = mesmo endereço (o do [Ptr] envolvido).
abstract base class PtrView<T> implements Ptr<T>, GoTyped {
  PtrView(this.$p);

  final Ptr<T> $p;

  @override
  T get value => $p.value;

  @override
  set value(T v) => $p.value = v;

  @override
  bool $assignIfIs(Object? v) => $p.$assignIfIs(v);

  @override
  bool $errorTargetOk() => $p.$errorTargetOk();

  @override
  bool operator ==(Object other) => other is PtrView<T> && other.$p == $p;

  @override
  int get hashCode => $p.hashCode;
}

/// `&s[i]`: posição de um array compartilhado.
final class ElemPtr<T> implements Ptr<T> {
  ElemPtr(this._array, this._index);

  final List<T> _array;
  final int _index;

  @override
  T get value => _array[_index];

  @override
  set value(T v) => _array[_index] = v;

  @override
  bool $assignIfIs(Object? v) {
    if (!_accepts<T>(v)) return false;
    value = v as T;
    return true;
  }

  @override
  bool $errorTargetOk() => _errorTarget<T>();

  @override
  bool operator ==(Object other) =>
      other is ElemPtr<T> &&
      identical(other._array, _array) &&
      other._index == _index;

  @override
  int get hashCode => Object.hash(identityHashCode(_array), _index);
}

/// `&o.f`: campo de um objeto; endereço = (objeto, campo).
final class FieldPtr<O extends Object, T> implements Ptr<T> {
  FieldPtr(this._owner, this._field, this._get, this._set);

  final O _owner;
  final String _field;
  final T Function(O) _get;
  final void Function(O, T) _set;

  @override
  T get value => _get(_owner);

  @override
  set value(T v) => _set(_owner, v);

  @override
  bool $assignIfIs(Object? v) {
    if (!_accepts<T>(v)) return false;
    value = v as T;
    return true;
  }

  @override
  bool $errorTargetOk() => _errorTarget<T>();

  @override
  bool operator ==(Object other) =>
      other is FieldPtr &&
      identical(other._owner, _owner) &&
      other._field == _field;

  @override
  int get hashCode => Object.hash(identityHashCode(_owner), _field);
}
