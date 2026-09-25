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
/// Chave `*T` com T struct é o próprio objeto da struct: [identity] compara
/// por endereço (identidade) em vez de campo a campo.
///
/// `base`: um tipo nomeado Go sobre map é uma subclasse gerada, e a conversão
/// entre eles é [GoMap.alias] (mesmo armazenamento).
base class GoMap<K, V> {
  /// Mesmo map que [m] (tipos de map com o mesmo subjacente).
  GoMap.alias(GoMap<K, V> m) : _m = m._m, elem = m.elem;

  /// `make(map[K]V)` / `map[K]V{}`.
  GoMap(this.elem, {bool identity = false}) : _m = _new<K, V>(identity);

  /// Map nil (zero value).
  GoMap.nil(this.elem) : _m = null;

  /// Literal `map[K]V{k: v, ...}`.
  GoMap.of(Map<K, V> entries, this.elem, {bool identity = false})
    : _m = _new<K, V>(identity)..addAll(entries);

  static Map<K, V> _new<K, V>(bool identity) =>
      identity ? Map<K, V>.identity() : <K, V>{};

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
