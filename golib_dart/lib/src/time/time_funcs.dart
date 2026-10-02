part of '../../time.dart';

// Porta de `Now`/`Unix`/`UnixMilli`/`UnixMicro`/`Date`/`Since`/`Until` de
// `time/time.go` do Go 1.26.
//
// `Now` não tem o relógio do runtime Go (`runtimeNow`); usa `DateTime.now()`
// (relógio de parede) e `Stopwatch` (monotônico), ambos de `dart:core`, sem
// API exclusiva de plataforma. `Local` é [local] (⚠️ = `utc`, ver
// `location.dart`), então todo horário "de parede" que este shim produz é
// UTC de fato.

final Stopwatch _stopwatch = Stopwatch()..start();

/// `startNano`: leitura monotônica na primeira vez que o relógio é usado
/// (menos 1, para nunca reportar 0, como o Go).
final Golang.Int64 _startNano =
    Golang.Int64(_stopwatch.elapsedMicroseconds) * Golang.Int64(1000) -
    Golang.Int64(1);

Golang.Int64 _runtimeNanoSinceStart() =>
    Golang.Int64(_stopwatch.elapsedMicroseconds) * Golang.Int64(1000) -
    _startNano;

/// `time.Now`.
Time now() {
  final wallNow = DateTime.now();
  final micros = wallNow.microsecondsSinceEpoch;
  var sec = Golang.Int64(micros ~/ 1000000);
  final nsec = (micros % 1000000) * 1000;
  final mono = _runtimeNanoSinceStart();
  sec = sec + Golang.Int64(_unixToInternal - _minWallSec);
  if ((sec.toUint64() >> 33) != Golang.Uint64()) {
    return Time._(Golang.Uint64(nsec), sec + Golang.Int64(_minWallSec), local);
  }
  return Time._(
    _hasMonotonicU64 | (sec.toUint64() << 30) | Golang.Uint64(nsec),
    mono,
    local,
  );
}

Time _unixTime(Golang.Int64 sec, int nsec) =>
    Time._(Golang.Uint64(nsec), sec + Golang.Int64(_unixToInternal), local);

/// `time.Unix(sec, nsec)`.
Time unix(Golang.Int64 sec, Golang.Int64 nsec) {
  var s = sec, n = nsec;
  if (n < Golang.Int64() || n >= Golang.Int64(_nsPerSecond)) {
    final div = n ~/ Golang.Int64(_nsPerSecond);
    s = s + div;
    n = n - div * Golang.Int64(_nsPerSecond);
    if (n < Golang.Int64()) {
      n = n + Golang.Int64(_nsPerSecond);
      s = s - Golang.Int64(1);
    }
  }
  return _unixTime(s, n.toInt());
}

/// `time.UnixMilli(msec)`.
Time unixMilli(Golang.Int64 msec) => unix(
  msec ~/ Golang.Int64(1000),
  (msec % Golang.Int64(1000)) * Golang.Int64(1000000),
);

/// `time.UnixMicro(usec)`.
Time unixMicro(Golang.Int64 usec) => unix(
  usec ~/ Golang.Int64(1000000),
  (usec % Golang.Int64(1000000)) * Golang.Int64(1000),
);

/// `time.Date`: implementação usada tanto pela função exportada quanto por
/// `AddDate`/`Parse` (`time_arith.dart`/`parse.dart`).
Time _dateImpl(
  int year,
  int month,
  int day,
  int hour,
  int min,
  int sec,
  int nsec,
  Location loc,
) {
  var (y, m) = _norm(year, month - 1, 12);
  m += 1;
  var (s2, ns2) = _norm(sec, nsec, _nsPerSecond);
  var (mi2, s3) = _norm(min, s2, 60);
  var (h2, mi3) = _norm(hour, mi2, 60);
  var (d2, h3) = _norm(day, h2, 24);

  final absDays = _dateToAbsDays(y, m, d2);
  var unixSecs =
      Golang.Int64(absDays) * Golang.Int64(_secondsPerDay) +
      Golang.Int64(h3 * 3600 + mi3 * 60 + s3) +
      _absoluteToUnixI64;

  final (_, offset) = loc._lookup();
  if (offset != 0) unixSecs = unixSecs - Golang.Int64(offset);

  final t = _unixTime(unixSecs, ns2);
  t._setLocation(loc);
  return t;
}

/// `time.Date(year, month, day, hour, min, sec, nsec, loc)`.
Time date(
  Golang.Int year,
  Month month,
  Golang.Int day,
  Golang.Int hour,
  Golang.Int min,
  Golang.Int sec,
  Golang.Int nsec,
  Location? loc,
) {
  if (loc == null) {
    throw Panic(Golang.String.fromDart('time: missing Location in call to Date'));
  }
  return _dateImpl(
    year.toInt(),
    month.toInt(),
    day.toInt(),
    hour.toInt(),
    min.toInt(),
    sec.toInt(),
    nsec.toInt(),
    loc,
  );
}

/// `time.Since(t)`.
Duration since(Time t) {
  if ((t.wall & _hasMonotonicU64) != _zeroU64) {
    return _subMono(_runtimeNanoSinceStart(), t.ext);
  }
  return _subImpl(now(), t);
}

/// `time.Until(t)`.
Duration until(Time t) {
  if ((t.wall & _hasMonotonicU64) != _zeroU64) {
    return _subMono(t.ext, _runtimeNanoSinceStart());
  }
  return _subImpl(t, now());
}
