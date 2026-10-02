/// Shim do pacote Go `strconv` (inteiros, bool, `Quote*`/`Unquote*`,
/// `Append*`, `FormatFloat`/`ParseFloat`; o resto em `TODO/P0-shim-strconv.md`).
///
/// Porta de `internal/strconv/atoi.go` do Go 1.26, com a aritmética nos
/// fixed_types (exata também no JS).
// ignore_for_file: library_prefixes
library;

import 'dart:convert';
import 'dart:typed_data';

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;
import 'fixed_types/golang/src/float_format.dart' as ff;
import 'fmt.dart' as fmt;
import 'math.dart' show naN;
import 'src/strconv/quote_core.dart' as qc;
import 'src/unicode/isprint.dart' as ip;

part 'src/strconv/misc.dart';
part 'src/strconv/ftoa.dart';
part 'src/strconv/atof.dart';

/// `strconv.ErrRange`.
final GoError errRange = ErrorString(
  Golang.String.fromDart('value out of range'),
);

/// `strconv.ErrSyntax`.
final GoError errSyntax = ErrorString(Golang.String.fromDart('invalid syntax'));

/// `*strconv.NumError`. Privado: código gerado que nomeia o tipo (campos,
/// type assertion) ainda cai em `shim-simbolo:strconv.NumError`.
final class _NumError implements GoError, Golang.GoTyped {
  _NumError(this.func, this.num, this.err);

  final String func;
  final Golang.String num;
  final GoError err;

  @override
  Golang.String error() =>
      Golang.String.fromDart('strconv.$func: parsing ') +
      fmt.sprintf(
        Golang.String.fromDart('%q'),
        Slice<Object?>.of([num], const Elem<Object?>(16, zeroNull)),
      ) +
      Golang.String.fromDart(': ') +
      err.error();

  /// `Unwrap() error`.
  GoError unwrap() => err;

  @override
  String get $goType => '*strconv.NumError';

  @override
  List<String> get $methods => const ['Error', 'Unwrap'];
}

/// `strconv.FormatInt(i, base)`: dígitos minúsculos, base 2..36.
Golang.String formatInt(Golang.Int64 i, Golang.Int base) =>
    Golang.String.fromDart(
      i.toBigInt().toRadixString(_base(base, 'FormatInt')),
    );

/// `strconv.FormatUint(i, base)`.
Golang.String formatUint(Golang.Uint64 i, Golang.Int base) =>
    Golang.String.fromDart(
      i.toBigInt().toRadixString(_base(base, 'FormatInt')),
    );

/// `strconv.Itoa(i)`.
Golang.String itoa(Golang.Int i) =>
    Golang.String.fromDart(i.toBigInt().toString());

int _base(Golang.Int base, String fn) {
  final b = base.toInt();
  if (b < 2 || b > 36) {
    throw Panic(Golang.String.fromDart('strconv: illegal AppendInt/$fn base'));
  }
  return b;
}

/// `strconv.ParseUint(s, base, bitSize)`.
(Golang.Uint64, GoError?) parseUint(
  Golang.String s,
  Golang.Int base,
  Golang.Int bitSize,
) {
  final (n, e) = _parseUint(s, base.toInt(), bitSize.toInt());
  return (n, _toError('ParseUint', s, base.toInt(), bitSize.toInt(), e));
}

/// `strconv.ParseInt(s, base, bitSize)`.
(Golang.Int64, GoError?) parseInt(
  Golang.String s,
  Golang.Int base,
  Golang.Int bitSize,
) {
  final (n, e) = _parseInt(s, base.toInt(), bitSize.toInt());
  return (n, _toError('ParseInt', s, base.toInt(), bitSize.toInt(), e));
}

/// `strconv.Atoi(s)`: o mesmo resultado do caminho rápido do Go.
(Golang.Int, GoError?) atoi(Golang.String s) {
  final (n, e) = _parseInt(s, 10, 0);
  return (Golang.Int.from(n), _toError('Atoi', s, 0, 0, e));
}

// Erros internos (sentinelas de `internal/strconv`).
enum _E { syntax, range, base, bitSize }

GoError? _toError(String fn, Golang.String s, int base, int bitSize, _E? e) =>
    switch (e) {
      null => null,
      _E.syntax => _NumError(fn, s, errSyntax),
      _E.range => _NumError(fn, s, errRange),
      _E.base => _NumError(
        fn,
        s,
        ErrorString(Golang.String.fromDart('invalid base $base')),
      ),
      _E.bitSize => _NumError(
        fn,
        s,
        ErrorString(Golang.String.fromDart('invalid bit size $bitSize')),
      ),
    };

int _lower(int c) => c | 0x20;

(Golang.Uint64, _E?) _parseUint(Golang.String s, int base, int bitSize) {
  final zero = Golang.Uint64();
  if (s.length == 0) return (zero, _E.syntax);
  final base0 = base == 0;
  final s0 = s;
  if (base == 0) {
    base = 10;
    if (s[0] == 0x30) {
      if (s.length >= 3 && _lower(s[1]) == 0x62) {
        base = 2;
        s = s.slice(2);
      } else if (s.length >= 3 && _lower(s[1]) == 0x6f) {
        base = 8;
        s = s.slice(2);
      } else if (s.length >= 3 && _lower(s[1]) == 0x78) {
        base = 16;
        s = s.slice(2);
      } else {
        base = 8;
        s = s.slice(1);
      }
    }
  } else if (base < 2 || base > 36) {
    return (zero, _E.base);
  }
  if (bitSize == 0) {
    bitSize = 64;
  } else if (bitSize < 0 || bitSize > 64) {
    return (zero, _E.bitSize);
  }
  final b = Golang.Uint64(base);
  final maxUint64 = ~zero;
  final cutoff = maxUint64 ~/ b + Golang.Uint64(1);
  final maxVal = bitSize == 64
      ? maxUint64
      : (Golang.Uint64(1) << bitSize) - Golang.Uint64(1);
  var underscores = false;
  var n = zero;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    int d;
    if (c == 0x5f && base0) {
      underscores = true;
      continue;
    } else if (c >= 0x30 && c <= 0x39) {
      d = c - 0x30;
    } else if (_lower(c) >= 0x61 && _lower(c) <= 0x7a) {
      d = _lower(c) - 0x61 + 10;
    } else {
      return (zero, _E.syntax);
    }
    if (d >= base) return (zero, _E.syntax);
    if (n >= cutoff) return (maxVal, _E.range);
    n *= b;
    final n1 = n + Golang.Uint64(d);
    if (n1 < n || n1 > maxVal) return (maxVal, _E.range);
    n = n1;
  }
  if (underscores && !_underscoreOK(s0)) return (zero, _E.syntax);
  return (n, null);
}

(Golang.Int64, _E?) _parseInt(Golang.String s, int base, int bitSize) {
  if (s.length == 0) return (Golang.Int64(), _E.syntax);
  var neg = false;
  if (s[0] == 0x2b) {
    s = s.slice(1);
  } else if (s[0] == 0x2d) {
    s = s.slice(1);
    neg = true;
  }
  final (un, e) = _parseUint(s, base, bitSize);
  if (e != null && e != _E.range) return (Golang.Int64(), e);
  if (bitSize == 0) bitSize = 64;
  final cutoff = Golang.Uint64(1) << (bitSize - 1);
  if (!neg && un >= cutoff) {
    return (Golang.Int64.from(cutoff - Golang.Uint64(1)), _E.range);
  }
  if (neg && un > cutoff) return (-Golang.Int64.from(cutoff), _E.range);
  final n = Golang.Int64.from(un);
  return (neg ? -n : n, null);
}

bool _underscoreOK(Golang.String s) {
  var saw = 0x5e; // '^'
  var i = 0;
  if (s.length >= 1 && (s[0] == 0x2d || s[0] == 0x2b)) s = s.slice(1);
  var hex = false;
  if (s.length >= 2 &&
      s[0] == 0x30 &&
      (_lower(s[1]) == 0x62 || _lower(s[1]) == 0x6f || _lower(s[1]) == 0x78)) {
    i = 2;
    saw = 0x30;
    hex = _lower(s[1]) == 0x78;
  }
  for (; i < s.length; i++) {
    final c = s[i];
    if ((c >= 0x30 && c <= 0x39) ||
        (hex && _lower(c) >= 0x61 && _lower(c) <= 0x66)) {
      saw = 0x30;
      continue;
    }
    if (c == 0x5f) {
      if (saw != 0x30) return false;
      saw = 0x5f;
      continue;
    }
    if (saw == 0x5f) return false;
    saw = 0x21;
  }
  return saw != 0x5f;
}
