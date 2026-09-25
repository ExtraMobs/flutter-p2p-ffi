/// Ponteiros Go para valores que não são struct (`*int`, `*string`...).
library;

import '../../fixed_types/golang.dart' show GoTyped;
import 'panic.dart';

/// `*T` quando T não é struct (uma struct é o seu próprio endereço).
/// Igualdade = mesmo endereço.
abstract interface class Ptr<T> {
  T get value;
  set value(T v);
}

/// Ponteiro nil tipado (`(*int)(nil)`) dentro de uma interface, que no Go
/// não é nil. Ler ou escrever dá o panic de nil pointer.
final class NilPtr<T> implements Ptr<T> {
  const NilPtr();

  @override
  T get value => nilDeref();

  @override
  set value(T v) => nilDeref();

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
  bool operator ==(Object other) =>
      other is FieldPtr &&
      identical(other._owner, _owner) &&
      other._field == _field;

  @override
  int get hashCode => Object.hash(identityHashCode(_owner), _field);
}
