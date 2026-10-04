part of '../../time.dart';

const _longMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December', //
];

const _longDayNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday', //
];

/// `time.Month`: tipo nomeado sobre `int` (janeiro = 1, ...), como o g2d
/// gera para `type Month int` — os construtores de `Golang.Int64Base` porque
/// `int` do Go é 64 bits (`fixed_types/golang/int.dart`). As constantes
/// (`time.January`...) o g2d dobra no literal `Month(n)` (mesma regra de
/// `time.Second`, ver `duration.dart`), então não há símbolos delas aqui.
final class Month extends Golang.Int64Base<Month> implements Stringer, Typed {
  Month([int v = 0]) : super(v);
  Month.from(Golang.IntBase v) : super.from(v);
  Month.fromBigInt(BigInt v) : super.fromBigInt(v);
  Month._(super.$hi, super.$lo) : super.raw();

  @override
  Month $make(int hi, int lo) => Month._(hi, lo);

  @override
  String get $goType => 'time.Month';

  /// Descritor de reflexão (`SHIM_RTYPES`, `rtypes.dart`).
  static final RType<Month> $rt = _monthRType();

  @override
  RType get $rtype => $rt;

  @override
  List<String> get $methods => const ['String'];

  /// `String()`: `"January"`..`"December"`, ou `"%!Month(n)"` fora do
  /// intervalo, com `n` como `uint64` (como o Go).
  @override
  Golang.String string() {
    if (this >= Month(1) && this <= Month(12)) {
      return Golang.String.fromDart(_longMonthNames[toInt() - 1]);
    }
    return Golang.String.fromDart('%!Month(${Golang.Uint64.from(this)})');
  }
}

/// `time.Weekday`: tipo nomeado sobre `int` (domingo = 0, ...).
final class Weekday extends Golang.Int64Base<Weekday>
    implements Stringer, Typed {
  Weekday([int v = 0]) : super(v);
  Weekday.from(Golang.IntBase v) : super.from(v);
  Weekday.fromBigInt(BigInt v) : super.fromBigInt(v);
  Weekday._(super.$hi, super.$lo) : super.raw();

  @override
  Weekday $make(int hi, int lo) => Weekday._(hi, lo);

  @override
  String get $goType => 'time.Weekday';

  /// Descritor de reflexão (`SHIM_RTYPES`, `rtypes.dart`).
  static final RType<Weekday> $rt = _weekdayRType();

  @override
  RType get $rtype => $rt;

  @override
  List<String> get $methods => const ['String'];

  /// `String()`: `"Sunday"`..`"Saturday"`, ou `"%!Weekday(n)"` fora do
  /// intervalo.
  @override
  Golang.String string() {
    if (this >= Weekday() && this <= Weekday(6)) {
      return Golang.String.fromDart(_longDayNames[toInt()]);
    }
    return Golang.String.fromDart('%!Weekday(${Golang.Uint64.from(this)})');
  }
}
