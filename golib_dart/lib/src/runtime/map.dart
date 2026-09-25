/// Maps Go.
library;

import 'elem.dart';
import 'panic.dart';

/// `map[K]V` do Go.
///
/// - nil (zero value): leituras dão o zero value, `len` 0, `delete` é no-op,
///   escrita dá panic;
/// - leitura de chave ausente dá o zero value (via [elem]);
/// - iteração tolera `delete`/inserção durante o `range` ([keysSnapshot] +
///   [containsKey]), como o Go permite.
///
/// A igualdade das chaves vem das classes intermediárias (`Golang.*`,
/// `GoStruct`, `Addr`, `Ptr`), que já seguem as regras do Go (NaN nunca é
/// encontrado, +0 ≡ −0, structs campo a campo, ponteiros por endereço).
final class GoMap<K, V> {
  /// `make(map[K]V)` / `map[K]V{}`.
  GoMap(this.elem) : _m = <K, V>{};

  /// Map nil (zero value).
  GoMap.nil(this.elem) : _m = null;

  /// Literal `map[K]V{k: v, ...}`.
  GoMap.of(Map<K, V> entries, this.elem) : _m = Map<K, V>.of(entries);

  final Map<K, V>? _m;
  final Elem<V> elem;

  bool get isNil => _m == null;
  int get length => _m?.length ?? 0;

  bool containsKey(K k) => _m?.containsKey(k) ?? false;

  /// `m[k]`: zero value quando ausente.
  V operator [](K k) {
    final m = _m;
    return m != null && m.containsKey(k) ? m[k] as V : elem.zero();
  }

  /// `m[k] = v`.
  void operator []=(K k, V v) {
    final m = _m;
    if (m == null)
      throw Panic(const RuntimeError('assignment to entry in nil map'));
    m[k] = v;
  }

  /// `v, ok := m[k]`.
  (V, bool) lookup(K k) {
    final m = _m;
    return m != null && m.containsKey(k)
        ? (m[k] as V, true)
        : (elem.zero(), false);
  }

  /// `delete(m, k)`.
  void delete(K k) => _m?.remove(k);

  /// Chaves no início de um `range`.
  List<K> keysSnapshot() => _m?.keys.toList() ?? <K>[];

  /// Pares atuais (formatação).
  Iterable<MapEntry<K, V>> get entries => _m?.entries ?? const [];
}
