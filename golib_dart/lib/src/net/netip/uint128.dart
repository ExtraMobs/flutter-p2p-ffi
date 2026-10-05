part of '../../../net/netip.dart';

final _zero64 = Golang.Uint64();
final _ones64 = ~Golang.Uint64();
final _one64 = Golang.Uint64(1);

/// `uint128`: inteiro de 128 bits sem sinal, imutável (as operações do Go
/// sobre a cópia por valor devolvem um novo).
final class _U128 {
  const _U128(this.hi, this.lo);

  final Golang.Uint64 hi;
  final Golang.Uint64 lo;

  static final _U128 zero = _U128(_zero64, _zero64);

  /// `isZero()`.
  bool get isZero => hi == _zero64 && lo == _zero64;

  _U128 and(_U128 m) => _U128(hi & m.hi, lo & m.lo);

  _U128 xor(_U128 m) => _U128(hi ^ m.hi, lo ^ m.lo);

  _U128 or(_U128 m) => _U128(hi | m.hi, lo | m.lo);

  _U128 not() => _U128(~hi, ~lo);

  /// `subOne()`: com o empréstimo de `bits.Sub64`.
  _U128 subOne() {
    final borrow = lo == _zero64 ? _one64 : _zero64;
    return _U128(hi - borrow, lo - _one64);
  }

  /// `addOne()`: com o vai-um de `bits.Add64`.
  _U128 addOne() {
    final l = lo + _one64;
    final carry = l == _zero64 ? _one64 : _zero64;
    return _U128(hi + carry, l);
  }

  @override
  bool operator ==(Object other) =>
      other is _U128 && other.hi == hi && other.lo == lo;

  @override
  int get hashCode => Object.hash(hi, lo);
}

/// `mask6(n)`: os n bits altos ligados (os shifts de 64 ou mais dão 0, como
/// no Go).
_U128 _mask6(int n) => _U128(~(_ones64 >> n), _ones64 << (128 - n));
