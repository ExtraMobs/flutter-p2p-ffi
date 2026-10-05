part of '../../time.dart';

// Porta de `time/time.go` (struct Time e as constantes de época) do Go 1.26.
// `wall`/`ext` são exatamente os campos do Go (o mesmo empacotamento do
// relógio monotônico: 1 bit de flag + 33 bits de segundos + 30 bits de
// nanossegundos em `wall`, ou o `ext` puro sem flag), para que `==` de
// struct (campo a campo, como o g2d emite para `time.Time`) se comporte como
// no Go — inclusive as pegadinhas documentadas ali (dois valores do mesmo
// instante podem comparar diferentes por causa da leitura monotônica ou da
// `Location`; prefira [Time.equal]).
//
// Só a "época absoluta" (`absoluteToInternal`/`internalToAbsolute`/
// `absoluteToUnix`/`unixToAbsolute`, ~9.22e18) precisa de `Int64.fromBigInt`
// (fora de ±2^53); as demais (`unixToInternal`, `wallToInternal`,
// `maxWall`/`minWall`) cabem no construtor comum de `Int64`/`Uint64`, que já
// converte plain `int` de até 2^53 corretamente em toda plataforma.

final _hasMonotonicU64 = Golang.Uint64(1) << 63;
final _nsecMaskU64 = Golang.Uint64((1 << 30) - 1);
final _zeroU64 = Golang.Uint64();
final _zeroI64 = Golang.Int64();
final _secDayU64 = Golang.Uint64(_secondsPerDay);

const _unixToInternal = 62135596800;
const _internalToUnix = -62135596800;
const _wallToInternal = 59453308800;
const _minWallSec = _wallToInternal;

final _unixToAbsoluteI64 = Golang.Int64.fromBigInt(
  BigInt.parse('9223372028741760000'),
);
final _absoluteToUnixI64 = Golang.Int64.fromBigInt(
  BigInt.parse('-9223372028741760000'),
);
final _maxInt64 = Golang.Int64.fromBigInt(BigInt.parse('9223372036854775807'));
final _minInt64Plus1 = Golang.Int64.fromBigInt(
  BigInt.parse('-9223372036854775807'),
);

/// `time.Time`.
final class Time extends GoStruct<Time>
    implements
        Stringer,
        fmt.GoStringer,
        Typed,
        json.Marshaler,
        json.Unmarshaler,
        encoding.TextMarshaler,
        encoding.TextUnmarshaler,
        encoding.BinaryMarshaler,
        encoding.BinaryUnmarshaler {
  Time() : wall = Golang.Uint64(), ext = Golang.Int64(), loc = null;
  Time._(this.wall, this.ext, this.loc);

  /// `(*Time)(nil)` dentro de uma interface.
  static final Time $nil = Time()..$nilPtr = true;

  Golang.Uint64 wall;
  Golang.Int64 ext;

  /// `nil` é UTC, como no Go (`loc==nil` nunca é `&utcLoc`).
  Location? loc;

  /// Descritor de reflexão (`SHIM_RTYPES`, `rtypes.dart`).
  static final RType<Time> $rt = _timeRType();

  @override
  RType get $rtype => $rt;

  @override
  String get $goType => 'time.Time';
  @override
  List<String> get $valueMethods => _timeValueMethods;
  @override
  List<String> get $ptrMethods => _timePtrMethods;

  @override
  Time $copy() => Time._(wall, ext, loc);
  @override
  void $set(Time o) {
    wall = o.wall;
    ext = o.ext;
    loc = o.loc;
  }

  @override
  List<Object?> get $fields => [wall, ext, loc];
  @override
  List<String> get $fieldNames => const ['wall', 'ext', 'loc'];

  // ---- helpers privados (porta 1:1 dos métodos não exportados do Go) ----

  int _nsecInt() => (wall & _nsecMaskU64).toInt();

  Golang.Int64 _secInternal() {
    if ((wall & _hasMonotonicU64) != _zeroU64) {
      final secField = (wall << 1) >> 31; // 33 bits, cabe em `int`
      return Golang.Int64(_wallToInternal + secField.toInt());
    }
    return ext;
  }

  /// `unixSec()`.
  Golang.Int64 _unixSec() => _secInternal() + Golang.Int64(_internalToUnix);

  void _addSecs(Golang.Int64 d) {
    if ((wall & _hasMonotonicU64) != _zeroU64) {
      final secField = (wall << 1) >> 31;
      final sec = Golang.Int64(secField.toInt());
      final dsec = sec + d;
      if (_zeroI64 <= dsec &&
          dsec <=
              Golang.Int64(
                8589934591,
              ) /* 1<<33 - 1 (o `<<` de `int` é 32 bits no JS) */ ) {
        // `t.wall&nsecMask | uint64(dsec)<<nsecShift | hasMonotonic` do Go:
        // guarda só o nsec e troca o campo de segundos (guardar o resto
        // deixaria os segundos antigos no OU).
        wall =
            (wall & _nsecMaskU64) |
            (dsec.toUint64() << 30) |
            _hasMonotonicU64;
        return;
      }
      _stripMono();
    }
    final sum = ext + d;
    if ((sum > ext) == (d > _zeroI64)) {
      ext = sum;
    } else if (d > _zeroI64) {
      ext = _maxInt64;
    } else {
      ext = _minInt64Plus1;
    }
  }

  void _stripMono() {
    if ((wall & _hasMonotonicU64) != _zeroU64) {
      ext = _secInternal();
      wall = wall & _nsecMaskU64;
    }
  }

  // `utc`/`local` (as variáveis de nível de pacote) não podem ser
  // referenciadas sem qualificação aqui: a classe também tem métodos `utc()`
  // e `local()` (mesma regra de nomes do g2d para `Time.UTC`/`Time.Local`),
  // que sombreariam a variável dentro do corpo de qualquer método da
  // classe. Por isso os métodos usam as sentinelas privadas.
  void _setLocation(Location? l) {
    _stripMono();
    loc = identical(l, _utcSentinel) ? null : l;
  }

  (String, int) _zoneInfo() => (loc ?? _utcSentinel)._lookup();

  /// `locabs()`: zona em vigor + dias/segundo-do-dia desde o ano absoluto,
  /// já ajustados pelo offset (uma só busca de zona, como o Go).
  (String, int, int, int) _locabs() {
    final (name, offset) = _zoneInfo();
    final sec = _unixSec() + Golang.Int64(offset);
    final absU = (sec + _unixToAbsoluteI64).toUint64();
    final days = (absU ~/ _secDayU64).toInt();
    final secOfDay = (absU % _secDayU64).toInt();
    return (name, offset, days, secOfDay);
  }

  // ---- comparação (porta de `After`/`Before`/`Compare`/`Equal`) ----

  bool isZero() => wall == _zeroU64 && ext == _zeroI64;

  bool before(Time u) {
    if ((wall & u.wall & _hasMonotonicU64) != _zeroU64) return ext < u.ext;
    final ts = _secInternal(), us = u._secInternal();
    return ts < us || (ts == us && _nsecInt() < u._nsecInt());
  }

  bool after(Time u) {
    if ((wall & u.wall & _hasMonotonicU64) != _zeroU64) return ext > u.ext;
    final ts = _secInternal(), us = u._secInternal();
    return ts > us || (ts == us && _nsecInt() > u._nsecInt());
  }

  bool equal(Time u) {
    if ((wall & u.wall & _hasMonotonicU64) != _zeroU64) return ext == u.ext;
    return _secInternal() == u._secInternal() && _nsecInt() == u._nsecInt();
  }

  Golang.Int compare(Time u) {
    Golang.Int64 tc, uc;
    if ((wall & u.wall & _hasMonotonicU64) != _zeroU64) {
      tc = ext;
      uc = u.ext;
    } else {
      tc = _secInternal();
      uc = u._secInternal();
      if (tc == uc) {
        tc = Golang.Int64(_nsecInt());
        uc = Golang.Int64(u._nsecInt());
      }
    }
    if (tc < uc) return Golang.Int(-1);
    if (tc > uc) return Golang.Int(1);
    return Golang.Int(0);
  }

  // ---- calendário/relógio (porta de `Date`/`Clock`/os acessores) ----

  (Golang.Int, Month, Golang.Int) date() {
    final (_, _, days, _) = _locabs();
    final (y, m, d) = _daysToDate(days);
    return (Golang.Int(y), Month(m), Golang.Int(d));
  }

  Golang.Int year() {
    final (_, _, days, _) = _locabs();
    final (y, _, _) = _daysToDate(days);
    return Golang.Int(y);
  }

  Month month() {
    final (_, _, days, _) = _locabs();
    final (_, m, _) = _daysToDate(days);
    return Month(m);
  }

  Golang.Int day() {
    final (_, _, days, _) = _locabs();
    final (_, _, d) = _daysToDate(days);
    return Golang.Int(d);
  }

  Weekday weekday() {
    final (_, _, days, _) = _locabs();
    return Weekday(_weekdayOfDays(days));
  }

  (Golang.Int, Golang.Int) isoWeek() {
    final (_, _, days, _) = _locabs();
    final off = 4 - (_weekdayOfDays(days - 1) + 1); // 4 = Thursday
    final (year, yday) = _daysToYearYday(days + off);
    return (Golang.Int(year), Golang.Int((yday - 1) ~/ 7 + 1));
  }

  (Golang.Int, Golang.Int, Golang.Int) clock() {
    final (_, _, _, secOfDay) = _locabs();
    final (h, m, s) = _clockOfSecOfDay(secOfDay);
    return (Golang.Int(h), Golang.Int(m), Golang.Int(s));
  }

  Golang.Int hour() => Golang.Int(_locabs().$4 ~/ 3600);
  Golang.Int minute() => Golang.Int(_locabs().$4 % 3600 ~/ 60);
  Golang.Int second() => Golang.Int(_locabs().$4 % 60);
  Golang.Int nanosecond() => Golang.Int(_nsecInt());

  Golang.Int yearDay() {
    final (_, _, days, _) = _locabs();
    final (_, yday) = _daysToYearYday(days);
    return Golang.Int(yday);
  }

  // ---- zona (porta de `Zone`/`Location`/`UTC`/`Local`/`In`) ----

  (Golang.String, Golang.Int) zone() {
    final (name, offset) = _zoneInfo();
    return (Golang.String.fromDart(name), Golang.Int(offset));
  }

  Location location() => loc ?? _utcSentinel;

  /// `UTC()`.
  Time utc() {
    final t = $copy();
    t._setLocation(_utcSentinel);
    return t;
  }

  /// `Local()`.
  Time local() {
    final t = $copy();
    t._setLocation(_localSentinel);
    return t;
  }

  Time in$(Location? l) {
    if (l == null) {
      throw Panic(
        Golang.String.fromDart('time: missing Location in call to Time.In'),
      );
    }
    final t = $copy();
    t._setLocation(l);
    return t;
  }

  // ---- época Unix (porta de `Unix`/`UnixNano`/`UnixMilli`/`UnixMicro`) ----

  Golang.Int64 unix() => _unixSec();
  Golang.Int64 unixNano() =>
      _unixSec() * Golang.Int64(_nsPerSecond) + Golang.Int64(_nsecInt());
  Golang.Int64 unixMilli() =>
      _unixSec() * Golang.Int64(1000) + Golang.Int64(_nsecInt() ~/ 1000000);
  Golang.Int64 unixMicro() =>
      _unixSec() * Golang.Int64(1000000) + Golang.Int64(_nsecInt() ~/ 1000);

  /// `String()`: `Format("2006-01-02 15:04:05.999999999 -0700 MST")` e,
  /// com leitura monotônica, ` m=±s.nnnnnnnnn` (`time_format.dart`).
  @override
  Golang.String string() => Golang.String.fromDart(_timeString(this));

  // ---- aritmética (implementação em `time_arith.dart`) ----

  Time add(Duration d) => _addImpl(this, d);
  Duration sub(Time u) => _subImpl(this, u);
  Time addDate(Golang.Int years, Golang.Int months, Golang.Int days) =>
      _addDateImpl(this, years.toInt(), months.toInt(), days.toInt());
  Time truncate(Duration d) => _truncateImpl(this, d);
  Time round(Duration d) => _roundImpl(this, d);

  // ---- layout e serialização (`layout.dart`, `marshal.dart`) ----

  Golang.String format(Golang.String layout) => _formatImpl(this, layout);
  Slice<Golang.Uint8> appendFormat(
    Slice<Golang.Uint8> b,
    Golang.String layout,
  ) => _appendFormatImpl(this, b, layout);
  @override
  Golang.String goString() => _goStringImpl(this);

  /// `IsDST()`: fuso fixo nunca está em horário de verão.
  bool isDST() => false;

  (Slice<Golang.Uint8>, GoError?) appendBinary(Slice<Golang.Uint8> b) =>
      _appendBinaryImpl(this, b);
  @override
  (Slice<Golang.Uint8>, GoError?) marshalBinary() => _marshalBinaryImpl(this);
  @override
  GoError? unmarshalBinary(Slice<Golang.Uint8> data) =>
      _unmarshalBinaryImpl(this, data);
  @override
  (Slice<Golang.Uint8>, GoError?) marshalJSON() => _marshalJSONImpl(this);
  @override
  GoError? unmarshalJSON(Slice<Golang.Uint8> data) =>
      _unmarshalJSONImpl(this, data);
  (Slice<Golang.Uint8>, GoError?) appendText(Slice<Golang.Uint8> b) =>
      _appendTextImpl(this, b, 'Time.AppendText: ');
  @override
  (Slice<Golang.Uint8>, GoError?) marshalText() =>
      _appendTextImpl(this, _nilBytes(), 'Time.MarshalText: ');
  @override
  GoError? unmarshalText(Slice<Golang.Uint8> data) =>
      _unmarshalTextImpl(this, data);
}
