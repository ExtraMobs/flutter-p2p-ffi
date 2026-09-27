part of '../ints.dart';

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
  int toIndex() => $safe ? toInt() : bigIndex(toString(), negative: _h < 0);

  @override
  BigInt toBigInt() => (BigInt.from(_h) << 32) | BigInt.from($lo);

  S _ofInt(int v) => $make(_hiOf(v), v & _m32);

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
    // Magnitudes sem sinal; o quociente leva o XOR dos sinais e o resto o
    // sinal do dividendo. |MinInt64| = 2^63 cabe sem sinal, e MinInt64 / -1
    // volta a MinInt64 ao truncar, como no Go.
    final an = _h < 0, bn = o._h < 0;
    var ah = $hi, al = $lo, bh = o.$hi, bl = o.$lo;
    if (an) {
      ah = (-ah - (al != 0 ? 1 : 0)) & _m32;
      al = -al & _m32;
    }
    if (bn) {
      bh = (-bh - (bl != 0 ? 1 : 0)) & _m32;
      bl = -bl & _m32;
    }
    _udivmod(ah, al, bh, bl);
    var h = remainder ? _rh : _qh, l = remainder ? _rl : _ql;
    if (remainder ? an : an != bn) {
      h = (-h - (l != 0 ? 1 : 0)) & _m32;
      l = -l & _m32;
    }
    return $make(h, l);
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
  String toString() {
    if ($safe) return toInt().toString();
    // Uma divisão por 10^10 (0x2_540B_E400): o quociente fica abaixo de 2^31
    // e o resto em ±2^53.
    final neg = _h < 0;
    var h = $hi, l = $lo;
    if (neg) {
      h = (-h - (l != 0 ? 1 : 0)) & _m32;
      l = -l & _m32;
    }
    _udivmod(h, l, 2, 0x540BE400);
    final low = (_rh * _p32 + _rl).toString().padLeft(10, '0');
    return '${neg ? '-' : ''}$_ql$low';
  }
}
