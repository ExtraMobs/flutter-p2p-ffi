part of '../../time.dart';

// Descritores de reflexão (`reflect.Type`) dos tipos do shim que o g2d
// referencia por `<Classe>.$rt` (`SHIM_RTYPES` em `g2d/config.py`).
//
// `time.Time` é descrito como no Go: struct de 24 bytes com os três campos
// não exportados `wall uint64`, `ext int64`, `loc *time.Location` (PkgPath
// "time"). `*time.Location` é opaco (os campos de `Location` não são
// descritos). ⚠️ Os method sets listam só o que o shim implementa (faltam
// `GobEncode`/`GobDecode`/`ZoneBounds`), então `NumMethod` é menor que o do
// Go.

/// Method set de `time.Time` implementado (nomes Go ordenados).
const _timeValueMethods = [
  'Add', 'AddDate', 'After', 'AppendBinary', 'AppendFormat', 'AppendText',
  'Before', 'Clock', 'Compare', 'Date', 'Day', 'Equal', 'Format',
  'GoString', 'Hour', 'ISOWeek', 'In', 'IsDST', 'IsZero', 'Local',
  'Location', 'MarshalBinary', 'MarshalJSON', 'MarshalText', 'Minute',
  'Month', 'Nanosecond', 'Round', 'Second', 'String', 'Sub', 'Truncate',
  'UTC', 'Unix', 'UnixMicro', 'UnixMilli', 'UnixNano', 'Weekday', 'Year',
  'YearDay', 'Zone', //
];

/// Method set de `*time.Time` implementado.
const _timePtrMethods = [
  'Add', 'AddDate', 'After', 'AppendBinary', 'AppendFormat', 'AppendText',
  'Before', 'Clock', 'Compare', 'Date', 'Day', 'Equal', 'Format',
  'GoString', 'Hour', 'ISOWeek', 'In', 'IsDST', 'IsZero', 'Local',
  'Location', 'MarshalBinary', 'MarshalJSON', 'MarshalText', 'Minute',
  'Month', 'Nanosecond', 'Round', 'Second', 'String', 'Sub', 'Truncate',
  'UTC', 'Unix', 'UnixMicro', 'UnixMilli', 'UnixNano', 'UnmarshalBinary',
  'UnmarshalJSON', 'UnmarshalText', 'Weekday', 'Year', 'YearDay', 'Zone', //
];

const _durationMethods = [
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

/// `*time.Location` (opaco: o mesmo descritor que o reflect monta para um
/// `Location` numa interface, ver `rtypeOf`).
RType _locationPtrRType() =>
    rtOpaque('time.Location', kStruct, ptrMethods: const ['String']).ptrTo();

RType<Time> _timeRType() => rtStruct<Time>(
  'time',
  'Time',
  'time.Time',
  size: 24,
  align: 8,
  ptrs: true,
  zero: Time.new,
  nil: () => Time.$nil,
  methods: _timeValueMethods,
  ptrMethods: _timePtrMethods,
  fields: () => [
    rtField(
      'wall',
      'time',
      () => rtUint64,
      get: (o) => (o as Time).wall,
      set: (o, v) => (o as Time).wall = v as Golang.Uint64,
    ),
    rtField(
      'ext',
      'time',
      () => rtInt64,
      offset: 8,
      get: (o) => (o as Time).ext,
      set: (o, v) => (o as Time).ext = v as Golang.Int64,
    ),
    rtField(
      'loc',
      'time',
      _locationPtrRType,
      offset: 16,
      get: (o) => (o as Time).loc,
      set: (o, v) => (o as Time).loc = v as Location?,
    ),
  ],
);

RType<Duration> _durationRType() => rtNamed<Duration>(
  'time',
  'Duration',
  'time.Duration',
  () => rtInt64,
  kind: kInt64,
  size: 8,
  align: 8,
  zero: Duration.new,
  conv: (v) => Duration.from(v as Golang.IntBase),
  methods: _durationMethods,
  ptrMethods: _durationMethods,
);

RType<Month> _monthRType() => rtNamed<Month>(
  'time',
  'Month',
  'time.Month',
  () => rtInt,
  kind: kInt,
  size: 8,
  align: 8,
  zero: Month.new,
  conv: (v) => Month.from(v as Golang.IntBase),
  methods: const ['String'],
  ptrMethods: const ['String'],
);

RType<Weekday> _weekdayRType() => rtNamed<Weekday>(
  'time',
  'Weekday',
  'time.Weekday',
  () => rtInt,
  kind: kInt,
  size: 8,
  align: 8,
  zero: Weekday.new,
  conv: (v) => Weekday.from(v as Golang.IntBase),
  methods: const ['String'],
  ptrMethods: const ['String'],
);
