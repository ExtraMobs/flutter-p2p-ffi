part of '../../time.dart';

// Porta de `Time.String` de `time/format.go` do Go 1.26: só o layout fixo
// `"2006-01-02 15:04:05.999999999 -0700 MST"` (sem o interpretador de
// layouts de `Format`/`Parse`, ver `TODO/P1-shim-time-layout.md`), mais o sufixo
// monotônico ` m=±s.nnnnnnnnn`.

/// `appendInt(b, x, width)`: sinal e zeros à esquerda até `width` dígitos.
void _appendInt(StringBuffer b, int x, int width) {
  if (x < 0) b.write('-');
  b.write(x.abs().toString().padLeft(width, '0'));
}

String _timeString(Time t) {
  final (name, offset, days, secOfDay) = t._locabs();
  final (year, month, day) = _daysToDate(days);
  final (hour, min, sec) = _clockOfSecOfDay(secOfDay);
  final b = StringBuffer();
  _appendInt(b, year, 4);
  b.write('-');
  _appendInt(b, month, 2);
  b.write('-');
  _appendInt(b, day, 2);
  b.write(' ');
  _appendInt(b, hour, 2);
  b.write(':');
  _appendInt(b, min, 2);
  b.write(':');
  _appendInt(b, sec, 2);
  // `.999999999`: fração sem zeros à direita; omitida (com o ponto) se zero.
  final nsec = t._nsecInt();
  if (nsec != 0) {
    var frac = nsec.toString().padLeft(9, '0');
    var end = frac.length;
    while (frac.codeUnitAt(end - 1) == 0x30) {
      end--;
    }
    frac = frac.substring(0, end);
    b
      ..write('.')
      ..write(frac);
  }
  b.write(' ');
  // `-0700` (divisão truncada como a do Go: o `~/` do Dart também trunca).
  void numTZ() {
    var zone = offset ~/ 60;
    if (zone < 0) {
      b.write('-');
      zone = -zone;
    } else {
      b.write('+');
    }
    _appendInt(b, zone ~/ 60, 2);
    _appendInt(b, zone % 60, 2);
  }

  numTZ();
  b.write(' ');
  // `MST`: o nome da zona, ou `-0700` sem o segundo campo se não há nome.
  if (name.isNotEmpty) {
    b.write(name);
  } else {
    var zone = offset ~/ 60;
    if (zone < 0) {
      b.write('-');
      zone = -zone;
    } else {
      b.write('+');
    }
    _appendInt(b, zone ~/ 60, 2);
    _appendInt(b, zone % 60, 2);
  }
  if ((t.wall & _hasMonotonicU64) != _zeroU64) {
    // `m=±s.nnnnnnnnn`: |ext| em BigInt (|minInt64| não cabe em int64).
    final e = t.ext.toBigInt();
    final billion = BigInt.from(_nsPerSecond);
    final m = e.abs();
    final m2 = (m % billion).toInt();
    final m1All = m ~/ billion;
    final m0 = m1All ~/ billion;
    final m1 = (m1All % billion).toInt();
    b
      ..write(' m=')
      ..write(e.isNegative ? '-' : '+');
    var wid = 0;
    if (m0 != BigInt.zero) {
      b.write(m0.toString());
      wid = 9;
    }
    _appendInt(b, m1, wid);
    b.write('.');
    _appendInt(b, m2, 9);
  }
  return b.toString();
}
