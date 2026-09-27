part of '../ints.dart';

/// Inteiros de até 32 bits: [$v] já truncado à largura; toda operação
/// renormaliza pelo construtor do tipo ([$make]).
abstract base class SmallIntBase<S extends SmallIntBase<S>> extends IntBase<S> {
  const SmallIntBase.raw(this.$v);

  /// Valor exato, no intervalo do tipo.
  final int $v;

  /// Largura em bits (8, 16 ou 32).
  int get $width;

  /// Novo valor do tipo, truncado à largura.
  S $make(int v);

  @override
  int get $hi => $v < 0 ? _m32 : 0;
  @override
  int get $lo => $v & _m32;
  @override
  int toInt() => $v;
  @override
  BigInt toBigInt() => BigInt.from($v);

  @override
  Uint8List toLittleEndianBytes() => Uint8List.fromList([
    for (var i = 0; i < $width; i += 8) ($lo >> i) & 0xFF,
  ]);

  @override
  S operator +(S o) => $make($v + o.$v);
  @override
  S operator -(S o) => $make($v - o.$v);
  @override
  S operator *(S o) => $make(_mul32($v, o.$v));
  @override
  S operator -() => $make(-$v);
  @override
  S operator ~/(S o) => $make($v ~/ _nonZero(o.$v));
  @override
  S operator %(S o) => $make($v.remainder(_nonZero(o.$v)));
  @override
  S operator &(S o) => $make($v & o.$v);
  @override
  S operator |(S o) => $make($v | o.$v);
  @override
  S operator ^(S o) => $make($v ^ o.$v);
  @override
  S operator ~() => $make(~$v);
  @override
  S andNot(S o) => $make($v & ~o.$v);

  @override
  S operator <<(int n) {
    _checkShift(n);
    return $make(n >= $width ? 0 : $v << n);
  }

  @override
  S operator >>(int n) {
    _checkShift(n);
    return $make(n >= $width ? ($v < 0 ? -1 : 0) : $v >> n);
  }

  @override
  int compareTo(S o) => $v < o.$v ? -1 : ($v > o.$v ? 1 : 0);
  @override
  bool operator <(S o) => $v < o.$v;
  @override
  bool operator <=(S o) => $v <= o.$v;
  @override
  bool operator >(S o) => $v > o.$v;
  @override
  bool operator >=(S o) => $v >= o.$v;

  @override
  bool operator ==(Object o) => o is S && o.$v == $v;
  @override
  int get hashCode => $v.hashCode;
  @override
  String toString() => $v.toString();
}
