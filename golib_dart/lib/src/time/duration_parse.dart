part of '../../time.dart';

// Porta de `ParseDuration`/`leadingInt`/`leadingFraction` de
// `time/format.go` do Go 1.26. O acumulador (`d`, `v`, `f`) usa
// `Golang.Uint64` porque chega perto de 2^63 (fora de ±2^53, o intervalo
// seguro do `int`/`double` do JS); a fração convertida em `double` já é
// aritmética `float64` no próprio Go (`float64(f) * (float64(unit)/scale)`),
// então usar `double` do Dart aqui é exato (IEEE 754 binary64 em toda
// plataforma, ao contrário de `int`).

const _unitMap = <String, int>{
  'ns': 1,
  'us': 1000,
  'µs': 1000, // U+00B5 (sinal de micro)
  'μs': 1000, // U+03BC (letra grega mu)
  'ms': 1000000,
  's': 1000000000,
  'm': 60000000000,
  'h': 3600000000000,
};

final class _ParseDurationError implements GoError, Golang.GoTyped {
  _ParseDurationError(this.message, this.value);

  final String message;
  final String value;

  @override
  Golang.String error() =>
      Golang.String.fromDart('time: $message ${_quote(value)}');

  @override
  String get $goType => '*time.parseDurationError';
  @override
  List<String> get $methods => const ['Error'];
}

bool _isAsciiDigit(String s, int i) {
  final c = s.codeUnitAt(i);
  return c >= 0x30 && c <= 0x39;
}

(Golang.Uint64, String, bool) _leadingInt(String s) {
  var i = 0;
  var x = Golang.Uint64();
  final limit = Golang.Uint64(1) << 63;
  final limitDiv10 = limit ~/ Golang.Uint64(10);
  for (; i < s.length; i++) {
    if (!_isAsciiDigit(s, i)) break;
    if (x > limitDiv10) return (Golang.Uint64(), s, false);
    x = x * Golang.Uint64(10) + Golang.Uint64(s.codeUnitAt(i) - 0x30);
    if (x > limit) return (Golang.Uint64(), s, false);
  }
  return (x, s.substring(i), true);
}

(Golang.Uint64, double, String) _leadingFraction(String s) {
  var i = 0;
  var scale = 1.0;
  var overflow = false;
  var x = Golang.Uint64();
  final limit = Golang.Uint64(1) << 63;
  final threshDiv10 = (limit - Golang.Uint64(1)) ~/ Golang.Uint64(10);
  for (; i < s.length; i++) {
    if (!_isAsciiDigit(s, i)) break;
    if (overflow) continue;
    if (x > threshDiv10) {
      overflow = true;
      continue;
    }
    final y = x * Golang.Uint64(10) + Golang.Uint64(s.codeUnitAt(i) - 0x30);
    if (y > limit) {
      overflow = true;
      continue;
    }
    x = y;
    scale *= 10;
  }
  return (x, scale, s.substring(i));
}

/// `time.ParseDuration(s)`.
(Duration, GoError?) parseDuration(Golang.String s0) {
  final orig = s0.toDart();
  var s = orig;
  var neg = false;
  if (s.isNotEmpty) {
    final c = s[0];
    if (c == '-' || c == '+') {
      neg = c == '-';
      s = s.substring(1);
    }
  }
  if (s == '0') return (Duration(), null);
  if (s.isEmpty) {
    return (Duration(), _ParseDurationError('invalid duration', orig));
  }

  final limit63 = Golang.Uint64(1) << 63;
  var d = Golang.Uint64();
  while (s.isNotEmpty) {
    if (!(s[0] == '.' || _isAsciiDigit(s, 0))) {
      return (Duration(), _ParseDurationError('invalid duration', orig));
    }
    final len0 = s.length;
    final (v0, rest0, ok0) = _leadingInt(s);
    if (!ok0) {
      return (Duration(), _ParseDurationError('invalid duration', orig));
    }
    var v = v0;
    s = rest0;
    final pre = len0 != s.length;

    var f = Golang.Uint64();
    var scale = 1.0;
    var post = false;
    if (s.isNotEmpty && s[0] == '.') {
      s = s.substring(1);
      final len1 = s.length;
      final (f0, scale0, rest1) = _leadingFraction(s);
      f = f0;
      scale = scale0;
      s = rest1;
      post = len1 != s.length;
    }
    if (!pre && !post) {
      return (Duration(), _ParseDurationError('invalid duration', orig));
    }

    var i = 0;
    for (; i < s.length; i++) {
      if (s[i] == '.' || _isAsciiDigit(s, i)) break;
    }
    if (i == 0) {
      return (Duration(), _ParseDurationError('missing unit in duration', orig));
    }
    final u = s.substring(0, i);
    s = s.substring(i);
    final unit = _unitMap[u];
    if (unit == null) {
      return (
        Duration(),
        _ParseDurationError('unknown unit ${_quote(u)} in duration', orig),
      );
    }
    final unitU64 = Golang.Uint64(unit);
    if (v > limit63 ~/ unitU64) {
      return (Duration(), _ParseDurationError('invalid duration', orig));
    }
    v = v * unitU64;
    if (f > Golang.Uint64()) {
      final add = f.toBigInt().toDouble() * (unit.toDouble() / scale);
      v = v + Golang.Uint64(add.truncate());
      if (v > limit63) {
        return (Duration(), _ParseDurationError('invalid duration', orig));
      }
    }
    d = d + v;
    if (d > limit63) {
      return (Duration(), _ParseDurationError('invalid duration', orig));
    }
  }
  if (neg) return (-Duration.from(d), null);
  if (d > limit63 - Golang.Uint64(1)) {
    return (Duration(), _ParseDurationError('invalid duration', orig));
  }
  return (Duration.from(d), null);
}
