part of '../../time.dart';

// Porta de `Add`/`Sub`/`AddDate`/`Round`/`Truncate`/`div` de `time/time.go`
// do Go 1.26. `Time.add`/`sub`/... (métodos, ver `time_type.dart`) são só
// wrappers finos para as funções privadas daqui, para manter a classe
// pequena (uma classe não é fatiada entre arquivos, então tudo que pode sair
// do corpo dela sai).

const _nsPerSecond = 1000000000;

Time _addImpl(Time t0, Duration d) {
  final t = t0.$copy();
  var dsec = (d ~/ Duration(_nsPerSecond)).toInt();
  var nsec = t._nsecInt() + (d % Duration(_nsPerSecond)).toInt();
  if (nsec >= _nsPerSecond) {
    dsec++;
    nsec -= _nsPerSecond;
  } else if (nsec < 0) {
    dsec--;
    nsec += _nsPerSecond;
  }
  t.wall = t.wall.andNot(_nsecMaskU64) | Golang.Uint64(nsec);
  t._addSecs(Golang.Int64(dsec));
  if ((t.wall & _hasMonotonicU64) != _zeroU64) {
    final te = t.ext + Golang.Int64.from(d);
    final overflow =
        (d < Duration() && te > t.ext) || (d > Duration() && te < t.ext);
    if (overflow) {
      t._stripMono();
    } else {
      t.ext = te;
    }
  }
  return t;
}

Duration _subMono(Golang.Int64 a, Golang.Int64 b) {
  final d = Duration.from(a - b);
  if (d < Duration() && a > b) return Duration.from(_maxDuration);
  if (d > Duration() && a < b) return Duration.from(_minDuration);
  return d;
}

Duration _subImpl(Time t, Time u) {
  if ((t.wall & u.wall & _hasMonotonicU64) != _zeroU64) {
    return _subMono(t.ext, u.ext);
  }
  final d =
      Duration.from(t._secInternal() - u._secInternal()) *
          Duration(_nsPerSecond) +
      Duration(t._nsecInt() - u._nsecInt());
  if (_addImpl(u, d).equal(t)) return d;
  if (t.before(u)) return Duration.from(_minDuration);
  return Duration.from(_maxDuration);
}

Time _addDateImpl(Time t, int years, int months, int days) {
  final (year, month, day) = t.date();
  final (hour, min, sec) = t.clock();
  return _dateImpl(
    year.toInt() + years,
    month.toInt() + months,
    day.toInt() + days,
    hour.toInt(),
    min.toInt(),
    sec.toInt(),
    t._nsecInt(),
    t.loc ?? _utcSentinel,
  );
}

bool _lessThanHalf(Duration x, Duration y) =>
    Golang.Uint64.from(x) + Golang.Uint64.from(x) < Golang.Uint64.from(y);

Time _truncateImpl(Time t0, Duration d) {
  final t = t0.$copy();
  t._stripMono();
  if (d <= Duration()) return t;
  final r = _divRemainder(t, d);
  return _addImpl(t, -r);
}

Time _roundImpl(Time t0, Duration d) {
  final t = t0.$copy();
  t._stripMono();
  if (d <= Duration()) return t;
  final r = _divRemainder(t, d);
  if (_lessThanHalf(r, d)) return _addImpl(t, -r);
  return _addImpl(t, d - r);
}

/// `div`: só o resto (`r`); o quociente de paridade do Go não é mais usado
/// nem por `Round` nem por `Truncate`.
Duration _divRemainder(Time t, Duration d) {
  var sec = t._secInternal();
  var nsec = t._nsecInt();
  var neg = false;
  if (sec < Golang.Int64()) {
    neg = true;
    sec = -sec;
    nsec = -nsec;
    if (nsec < 0) {
      nsec += _nsPerSecond;
      sec = sec - Golang.Int64(1);
    }
  }
  Duration r;
  if (d < Duration(_nsPerSecond) &&
      Duration(_nsPerSecond) % (d + d) == Duration()) {
    r = Duration(nsec % d.toInt());
  } else if (d % Duration(_nsPerSecond) == Duration()) {
    final d1 = Golang.Int64.from(d) ~/ Golang.Int64(_nsPerSecond);
    r = Duration.from(sec % d1) * Duration(_nsPerSecond) + Duration(nsec);
  } else {
    r = _divGeneral(sec, nsec, d);
  }
  if (neg && r != Duration()) {
    r = d - r;
  }
  return r;
}

/// Caso geral de `div`: `sec*1e9+nsec` como inteiro sem sinal de 128 bits
/// (`u1:u0`), dividido por `d` bit a bit (deslocar e subtrair) só pelo resto.
Duration _divGeneral(Golang.Int64 secNonNeg, int nsec, Duration d) {
  final sec = secNonNeg.toUint64();
  final billion = Golang.Uint64(_nsPerSecond);
  var tmp = (sec >> 32) * billion;
  var u1 = tmp >> 32;
  var u0 = tmp << 32;
  tmp = (sec & Golang.Uint64(0xFFFFFFFF)) * billion;
  var carry = u0;
  u0 = u0 + tmp;
  if (u0 < carry) u1 = u1 + Golang.Uint64(1);
  carry = u0;
  u0 = u0 + Golang.Uint64(nsec);
  if (u0 < carry) u1 = u1 + Golang.Uint64(1);

  final dU64 = Golang.Uint64.from(d);
  var d1 = dU64;
  while ((d1 >> 63) != Golang.Uint64(1)) {
    d1 = d1 << 1;
  }
  var d0 = Golang.Uint64();
  while (true) {
    if (u1 > d1 || (u1 == d1 && u0 >= d0)) {
      final u0x = u0;
      u0 = u0 - d0;
      if (u0 > u0x) u1 = u1 - Golang.Uint64(1);
      u1 = u1 - d1;
    }
    if (d1 == Golang.Uint64() && d0 == dU64) break;
    d0 = d0 >> 1;
    d0 = d0 | ((d1 & Golang.Uint64(1)) << 63);
    d1 = d1 >> 1;
  }
  return Duration.from(u0);
}
