/// Shim do pacote Go `time` (parcial: `Duration`; `Time`, `Now`, timers e o
/// resto em `TODO/P0-shim-time.md`).
///
/// As constantes (`time.Second`...) o g2d dobra em `time.Duration(n)`.
// ignore_for_file: library_prefixes
library;

import 'dart:typed_data';

import 'fixed_types/golang.dart' as Golang;
import 'fmt.dart' show Stringer;

final _second = Golang.Int64(1000000000);
final _minute = Golang.Int64(60000000000);
final _hour = Golang.Int64(3600000000000);
final _minDuration = Golang.Int64.fromBigInt(-(BigInt.one << 63));
final _maxDuration = Golang.Int64.fromBigInt((BigInt.one << 63) - BigInt.one);

/// `time.Duration`: nanossegundos em `int64`, tipo nomeado com os métodos do
/// Go (mesma forma das classes que o g2d gera para `type N int64`).
final class Duration extends Golang.Int64Base<Duration> implements Stringer {
  Duration([int v = 0]) : super(v);
  Duration.from(Golang.IntBase v) : super.from(v);
  Duration.fromBigInt(BigInt v) : super.fromBigInt(v);
  Duration._(super.$hi, super.$lo) : super.raw();

  @override
  Duration $make(int hi, int lo) => Duration._(hi, lo);

  @override
  String get $goType => 'time.Duration';

  @override
  List<String> get $methods => const [
    'Abs',
    'Hours',
    'Microseconds',
    'Milliseconds',
    'Minutes',
    'Nanoseconds',
    'Round',
    'Seconds',
    'String',
    'Truncate',
  ];

  Golang.Int64 get _v => Golang.Int64.from(this);

  /// `String()`: `72h3m0.5s`, `1.5µs`, `0s`, como o Go.
  @override
  Golang.String string() {
    var u = _v.toBigInt();
    final neg = u.isNegative;
    if (neg) u = -u;
    final out = <int>[]; // bytes em ordem reversa
    void put(String s) => out.addAll(s.codeUnits.reversed);
    (List<int>, BigInt) frac(BigInt v, int prec) {
      final digits = <int>[];
      var print = false;
      for (var i = 0; i < prec; i++) {
        final d = (v % BigInt.from(10)).toInt();
        print = print || d != 0;
        if (print) digits.add(0x30 + d);
        v ~/= BigInt.from(10);
      }
      if (print) digits.add(0x2e);
      return (digits, v);
    }

    void integer(BigInt v) => put(v.toString());
    if (u < BigInt.from(1000000000)) {
      if (u == BigInt.zero) return Golang.String.fromDart('0s');
      put('s');
      int prec;
      if (u < BigInt.from(1000)) {
        prec = 0;
        put('n');
      } else if (u < BigInt.from(1000000)) {
        prec = 3;
        out.addAll([0xb5, 0xc2]); // "µ" em UTF-8, invertido
      } else {
        prec = 6;
        put('m');
      }
      final (digits, rest) = frac(u, prec);
      out.addAll(digits);
      integer(rest);
    } else {
      put('s');
      final (digits, rest) = frac(u, 9);
      out.addAll(digits);
      var v = rest;
      integer(v % BigInt.from(60));
      v ~/= BigInt.from(60);
      if (v > BigInt.zero) {
        put('m');
        integer(v % BigInt.from(60));
        v ~/= BigInt.from(60);
        if (v > BigInt.zero) {
          put('h');
          integer(v);
        }
      }
    }
    if (neg) put('-');
    return Golang.String.fromBytes(Uint8List.fromList(out.reversed.toList()));
  }

  Golang.Float64 _split(Golang.Int64 unit, double scale) {
    final whole = _v ~/ unit, rest = _v % unit;
    return Golang.Float64.fromInt64(whole) +
        Golang.Float64.fromInt64(rest) / Golang.Float64(scale);
  }

  /// `Nanoseconds()`.
  Golang.Int64 nanoseconds() => _v;

  /// `Microseconds()`.
  Golang.Int64 microseconds() => _v ~/ Golang.Int64(1000);

  /// `Milliseconds()`.
  Golang.Int64 milliseconds() => _v ~/ Golang.Int64(1000000);

  /// `Seconds()`.
  Golang.Float64 seconds() => _split(_second, 1e9);

  /// `Minutes()`.
  Golang.Float64 minutes() => _split(_minute, 60 * 1e9);

  /// `Hours()`.
  Golang.Float64 hours() => _split(_hour, 60 * 60 * 1e9);

  /// `Truncate(m)`.
  Duration truncate(Duration m) {
    if (m <= Duration()) return this;
    return this - this % m;
  }

  /// `Round(m)`: metade arredonda para longe de zero; estouro satura.
  Duration round(Duration m) {
    if (m <= Duration()) return this;
    var r = this % m;
    bool lessThanHalf(Duration x, Duration y) =>
        Golang.Uint64.from(x) + Golang.Uint64.from(x) < Golang.Uint64.from(y);
    if (this < Duration()) {
      r = -r;
      if (lessThanHalf(r, m)) return this + r;
      final d1 = this - m + r;
      if (d1 < this) return d1;
      return Duration.from(_minDuration);
    }
    if (lessThanHalf(r, m)) return this - r;
    final d1 = this + m - r;
    if (d1 > this) return d1;
    return Duration.from(_maxDuration);
  }

  /// `Abs()`.
  Duration abs() {
    if (this >= Duration()) return this;
    if (_v == _minDuration) return Duration.from(_maxDuration);
    return -this;
  }
}
