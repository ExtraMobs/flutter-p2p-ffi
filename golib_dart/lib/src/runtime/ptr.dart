/// Ponteiros Go para valores que não são struct (`*int`, `*string`...).
library;

/// `*T` quando T não é struct (uma struct é o seu próprio endereço).
/// Igualdade = mesmo endereço.
abstract interface class Ptr<T> {
  T get value;
  set value(T v);
}

/// Variável cujo endereço é tomado (`&x`) ou criada por `new(T)`: ela passa
/// a morar numa caixa, e a identidade da caixa é o endereço.
final class Box<T> implements Ptr<T> {
  Box(this.value);

  @override
  T value;
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
