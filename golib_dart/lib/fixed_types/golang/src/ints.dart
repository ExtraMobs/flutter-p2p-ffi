// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Representação dos inteiros Go sem BigInt, igual em todas as plataformas.
///
/// - Até 32 bits ([SmallIntBase]): um `int` normalizado à largura.
/// - 64 bits ([WideIntBase]): duas palavras de 32 bits sem sinal ([$hi]/[$lo]).
///
/// Invariantes que tornam o código exato também no JS (int = double, bitwise
/// em 32 bits): nenhum intermediário passa de 2^53; `&`, `|`, `^`, `~`, `<<`
/// e `>>` só recebem valores de até 32 bits e o resultado é sempre
/// renormalizado (no JS esses operadores devolvem 32 bits sem sinal).
/// Carries entre palavras usam `~/` e `*`, nunca shifts de valores maiores
/// que 32 bits.
library;

import 'dart:typed_data';

import 'base.dart';

const int _m32 = 0xFFFFFFFF;
const int _p32 = 0x100000000;
const int _p16 = 0x10000;

/// v (|v| <= 2^53) truncado ao módulo `mod` (2^8, 2^16 ou 2^32).
int _wrap(int v, int mod, bool signed) {
  final u = v & (mod - 1);
  return signed && u >= mod ~/ 2 ? u - mod : u;
}

/// Os 32 bits baixos de a*b, com |a|, |b| < 2^32.
int _mul32(int a, int b) {
  a &= _m32;
  b &= _m32;
  final al = a & 0xFFFF, bl = b & 0xFFFF;
  final mid = ((a ~/ _p16) * bl + al * (b ~/ _p16)) & 0xFFFF;
  return (al * bl + mid * _p16) & _m32;
}

/// Palavra alta (complemento de dois) de um int Dart.
int _hiOf(int v) => ((v - (v & _m32)) ~/ _p32) & _m32;

final _bigM32 = BigInt.from(_m32);

int _bigLo(BigInt v) => (v & _bigM32).toInt();
int _bigHi(BigInt v) => ((v >> 32) & _bigM32).toInt();

int _nonZero(int d) {
  // Mesma exceção de antes (o runtime a traduz para o panic do Go); o
  // substituto sugerido (UnsupportedError) seria amplo demais.
  // ignore: deprecated_member_use
  if (d == 0) throw IntegerDivisionByZeroException();
  return d;
}

void _checkShift(int n) {
  if (n < 0) throw ArgumentError.value(n, 'count', 'negative shift amount');
}

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

/// Inteiros de 64 bits: palavras [$hi]/[$lo] em [0, 2^32).
abstract base class WideIntBase<S extends WideIntBase<S>> extends IntBase<S> {
  const WideIntBase.raw(this.$hi, this.$lo);

  @override
  final int $hi;
  @override
  final int $lo;

  /// Novo valor do tipo a partir das palavras (já em [0, 2^32)).
  S $make(int hi, int lo);

  /// Palavra alta com o sinal do tipo.
  int get _h => $signed && $hi >= 0x80000000 ? $hi - _p32 : $hi;

  /// O valor cabe em ±2^53 (exato como int e como double em toda plataforma).
  bool get $safe {
    final h = _h;
    return h >= -0x200000 && h < 0x200000;
  }

  /// Exato quando [$safe]. Fora disso: na VM, os 64 bits em complemento de
  /// dois; no JS, aproximado (só é usado como índice, que já está fora do
  /// intervalo).
  @override
  int toInt() => _h * _p32 + $lo;

  @override
  BigInt toBigInt() => (BigInt.from(_h) << 32) | BigInt.from($lo);

  S _ofInt(int v) => $make(_hiOf(v), v & _m32);
  S _ofBig(BigInt v) => $make(_bigHi(v), _bigLo(v));

  @override
  Uint8List toLittleEndianBytes() => Uint8List.fromList([
    for (var i = 0; i < 32; i += 8) ($lo >> i) & 0xFF,
    for (var i = 0; i < 32; i += 8) ($hi >> i) & 0xFF,
  ]);

  @override
  S operator +(S o) {
    final lo = $lo + o.$lo;
    return $make(($hi + o.$hi + (lo >= _p32 ? 1 : 0)) & _m32, lo & _m32);
  }

  @override
  S operator -(S o) {
    final lo = $lo - o.$lo;
    return $make(($hi - o.$hi - (lo < 0 ? 1 : 0)) & _m32, lo & _m32);
  }

  @override
  S operator -() => $make((-$hi - ($lo != 0 ? 1 : 0)) & _m32, -$lo & _m32);

  /// Produto em limbs de 16 bits; só os 64 bits baixos.
  @override
  S operator *(S o) {
    final a0 = $lo & 0xFFFF, a1 = $lo ~/ _p16;
    final a2 = $hi & 0xFFFF, a3 = $hi ~/ _p16;
    final b0 = o.$lo & 0xFFFF, b1 = o.$lo ~/ _p16;
    final b2 = o.$hi & 0xFFFF, b3 = o.$hi ~/ _p16;
    final c0 = a0 * b0;
    final c1 = a1 * b0 + a0 * b1 + c0 ~/ _p16;
    final c2 = a2 * b0 + a1 * b1 + a0 * b2 + c1 ~/ _p16;
    final c3 = a3 * b0 + a2 * b1 + a1 * b2 + a0 * b3 + c2 ~/ _p16;
    return $make(
      (c2 & 0xFFFF) + (c3 & 0xFFFF) * _p16,
      (c0 & 0xFFFF) + (c1 & 0xFFFF) * _p16,
    );
  }

  @override
  S operator ~/(S o) => _div(o, remainder: false);
  @override
  S operator %(S o) => _div(o, remainder: true);

  S _div(S o, {required bool remainder}) {
    _nonZero(o.$hi | o.$lo);
    if ($safe && o.$safe) {
      final a = toInt(), b = o.toInt();
      return _ofInt(remainder ? a.remainder(b) : a ~/ b);
    }
    // ponytail: fora de ±2^53 a divisão vai por BigInt; divisão longa em
    // palavras de 32 bits se isso aparecer num caminho quente.
    final a = toBigInt(), b = o.toBigInt();
    return _ofBig(remainder ? a.remainder(b) : a ~/ b);
  }

  @override
  S operator &(S o) => $make($hi & o.$hi, $lo & o.$lo);
  @override
  S operator |(S o) => $make($hi | o.$hi, $lo | o.$lo);
  @override
  S operator ^(S o) => $make($hi ^ o.$hi, $lo ^ o.$lo);
  @override
  S operator ~() => $make(~$hi & _m32, ~$lo & _m32);
  @override
  S andNot(S o) => $make($hi & ~o.$hi & _m32, $lo & ~o.$lo & _m32);

  @override
  S operator <<(int n) {
    _checkShift(n);
    if (n >= 64) return $make(0, 0);
    if (n >= 32) return $make(($lo << (n - 32)) & _m32, 0);
    if (n == 0) return $make($hi, $lo);
    return $make((($hi << n) | ($lo >> (32 - n))) & _m32, ($lo << n) & _m32);
  }

  @override
  S operator >>(int n) {
    _checkShift(n);
    final fill = $signed && $hi >= 0x80000000 ? _m32 : 0;
    if (n >= 64) return $make(fill, fill);
    if (n == 32) return $make(fill, $hi);
    if (n > 32) {
      final k = n - 32;
      return $make(fill, (($hi >> k) | (fill << (32 - k))) & _m32);
    }
    if (n == 0) return $make($hi, $lo);
    return $make(
      (($hi >> n) | (fill << (32 - n))) & _m32,
      (($lo >> n) | ($hi << (32 - n))) & _m32,
    );
  }

  @override
  int compareTo(S o) {
    final a = _h, b = o._h;
    if (a != b) return a < b ? -1 : 1;
    return $lo == o.$lo ? 0 : ($lo < o.$lo ? -1 : 1);
  }

  @override
  bool operator <(S o) => compareTo(o) < 0;
  @override
  bool operator <=(S o) => compareTo(o) <= 0;
  @override
  bool operator >(S o) => compareTo(o) > 0;
  @override
  bool operator >=(S o) => compareTo(o) >= 0;

  @override
  bool operator ==(Object o) => o is S && o.$hi == $hi && o.$lo == $lo;
  @override
  int get hashCode => $hi * 31 + $lo;
  @override
  String toString() => $safe ? toInt().toString() : toBigInt().toString();
}

// Uma base por largura: fixa largura e sinal e dá os construtores que os
// tipos nomeados gerados pelo g2d repassam (`N(v)`, `N.from`, `N.fromBigInt`).

abstract base class Int8Base<S extends Int8Base<S>> extends SmallIntBase<S> {
  Int8Base([int v = 0]) : super.raw(_wrap(v, 0x100, true));
  Int8Base.from(IntBase v) : this(v.$lo);
  Int8Base.fromBigInt(BigInt v) : this(_bigLo(v));
  @override
  int get $width => 8;
  @override
  bool get $signed => true;
}

abstract base class Int16Base<S extends Int16Base<S>> extends SmallIntBase<S> {
  Int16Base([int v = 0]) : super.raw(_wrap(v, 0x10000, true));
  Int16Base.from(IntBase v) : this(v.$lo);
  Int16Base.fromBigInt(BigInt v) : this(_bigLo(v));
  @override
  int get $width => 16;
  @override
  bool get $signed => true;
}

abstract base class Int32Base<S extends Int32Base<S>> extends SmallIntBase<S> {
  Int32Base([int v = 0]) : super.raw(_wrap(v, _p32, true));
  Int32Base.from(IntBase v) : this(v.$lo);
  Int32Base.fromBigInt(BigInt v) : this(_bigLo(v));
  @override
  int get $width => 32;
  @override
  bool get $signed => true;
}

abstract base class Uint8Base<S extends Uint8Base<S>> extends SmallIntBase<S> {
  Uint8Base([int v = 0]) : super.raw(_wrap(v, 0x100, false));
  Uint8Base.from(IntBase v) : this(v.$lo);
  Uint8Base.fromBigInt(BigInt v) : this(_bigLo(v));
  @override
  int get $width => 8;
  @override
  bool get $signed => false;
}

abstract base class Uint16Base<S extends Uint16Base<S>>
    extends SmallIntBase<S> {
  Uint16Base([int v = 0]) : super.raw(_wrap(v, 0x10000, false));
  Uint16Base.from(IntBase v) : this(v.$lo);
  Uint16Base.fromBigInt(BigInt v) : this(_bigLo(v));
  @override
  int get $width => 16;
  @override
  bool get $signed => false;
}

abstract base class Uint32Base<S extends Uint32Base<S>>
    extends SmallIntBase<S> {
  Uint32Base([int v = 0]) : super.raw(_wrap(v, _p32, false));
  Uint32Base.from(IntBase v) : this(v.$lo);
  Uint32Base.fromBigInt(BigInt v) : this(_bigLo(v));
  @override
  int get $width => 32;
  @override
  bool get $signed => false;
}

abstract base class Int64Base<S extends Int64Base<S>> extends WideIntBase<S> {
  Int64Base([int v = 0]) : super.raw(_hiOf(v), v & _m32);
  Int64Base.from(IntBase v) : super.raw(v.$hi, v.$lo);
  Int64Base.fromBigInt(BigInt v) : super.raw(_bigHi(v), _bigLo(v));
  const Int64Base.raw(super.$hi, super.$lo) : super.raw();
  @override
  bool get $signed => true;
}

abstract base class Uint64Base<S extends Uint64Base<S>> extends WideIntBase<S> {
  Uint64Base([int v = 0]) : super.raw(_hiOf(v), v & _m32);
  Uint64Base.from(IntBase v) : super.raw(v.$hi, v.$lo);
  Uint64Base.fromBigInt(BigInt v) : super.raw(_bigHi(v), _bigLo(v));
  const Uint64Base.raw(super.$hi, super.$lo) : super.raw();
  @override
  bool get $signed => false;
}
