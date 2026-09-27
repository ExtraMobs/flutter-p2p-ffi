part of '../../time.dart';

const _longMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December', //
];

const _shortMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

const _longDayNames = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
];

const _shortDayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// `time.Month`: tipo nomeado sobre `int` (janeiro = 1, ...), como o g2d
/// gera para `type Month int` — os construtores de `Golang.Int64Base` porque
/// `int` do Go é 64 bits (`fixed_types/golang/int.dart`). As constantes
/// (`time.January`...) o g2d dobra no literal `Month(n)` (mesma regra de
/// `time.Second`, ver `duration.dart`), então não há símbolos delas aqui.
final class Month extends Golang.Int64Base<Month> implements Stringer {
  Month([int v = 0]) : super(v);
  Month.from(Golang.IntBase v) : super.from(v);
  Month.fromBigInt(BigInt v) : super.fromBigInt(v);
  Month._(super.$hi, super.$lo) : super.raw();

  @override
  Month $make(int hi, int lo) => Month._(hi, lo);

  @override
  String get $goType => 'time.Month';

  @override
  List<String> get $methods => const ['String'];

  /// `String()`: `"January"`..`"December"`, ou `"%!Month(n)"` fora do
  /// intervalo (como o Go).
  @override
  Golang.String string() {
    final n = toInt();
    if (n >= 1 && n <= 12 && $safe) {
      return Golang.String.fromDart(_longMonthNames[n - 1]);
    }
    return Golang.String.fromDart('%!Month(${toBigInt()})');
  }
}

/// `time.Weekday`: tipo nomeado sobre `int` (domingo = 0, ...).
final class Weekday extends Golang.Int64Base<Weekday> implements Stringer {
  Weekday([int v = 0]) : super(v);
  Weekday.from(Golang.IntBase v) : super.from(v);
  Weekday.fromBigInt(BigInt v) : super.fromBigInt(v);
  Weekday._(super.$hi, super.$lo) : super.raw();

  @override
  Weekday $make(int hi, int lo) => Weekday._(hi, lo);

  @override
  String get $goType => 'time.Weekday';

  @override
  List<String> get $methods => const ['String'];

  /// `String()`: `"Sunday"`..`"Saturday"`, ou `"%!Weekday(n)"` fora do
  /// intervalo.
  @override
  Golang.String string() {
    final n = toInt();
    if (n >= 0 && n <= 6 && $safe) {
      return Golang.String.fromDart(_longDayNames[n]);
    }
    return Golang.String.fromDart('%!Weekday(${toBigInt()})');
  }
}
