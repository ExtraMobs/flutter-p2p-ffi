part of '../../time.dart';

// Porta de `time/time.go` (comentário "Computations on Times") do Go 1.26:
// calendário gregoriano exato via divisão euclidiana afim (Neri e
// Schneider, "Euclidean affine functions and their application to calendar
// algorithms", SP&E 2023), com o ano absoluto começando em 1º de março do
// ano -292277022400 (`absoluteYears`). Tudo em `int` puro (sem `&`/`<<`/`>>`
// de mais de 32 bits): os valores intermediários (dias desde o ano
// absoluto) cabem em ±2^53 para qualquer data que o Go também suporta, como
// no comentário de origem.
//
// `absSeconds`/`absDays` do Go são `uint64`; aqui `days` já é o quociente
// (por 86400) de um `Golang.Uint64`, convertido com `.toInt()` (exato: bem
// abaixo de 2^53). Ver `time_type.dart` para essa conversão.

const _secondsPerDay = 24 * 60 * 60;
const _marchThruDecember = 31 + 30 + 31 + 30 + 31 + 31 + 30 + 31 + 30 + 31;
const _absoluteYears = 292277022400;

/// `dateToAbsDays`: ano/mês/dia (podem estar fora do intervalo normal, como
/// no Go) → dias desde o ano absoluto.
int _dateToAbsDays(int year, int month, int day) {
  var amonth = month;
  final janFeb = amonth < 3 ? 1 : 0;
  amonth += 12 * janFeb;
  final y = year - janFeb + _absoluteYears;

  final ayday = (979 * amonth - 2919) ~/ 32;
  final century = y ~/ 100;
  final cyear = y % 100;
  final cday = 1461 * cyear ~/ 4;
  final centurydays = 146097 * century ~/ 4;

  return centurydays + cday + ayday + day - 1;
}

/// `absDays.split`: dias → (century, cyear, ayday).
(int, int, int) _splitDays(int days) {
  final d = 4 * days + 3;
  final century = d ~/ 146097;
  final cdayFull = d % 146097;
  final cd = (cdayFull ~/ 4) * 4 + 3; // `| 3` do Go (arredonda para baixo e liga os 2 bits baixos)
  final full = 2939745 * cd;
  final cyear = full ~/ 0x100000000;
  final ayday = (full % 0x100000000) ~/ 2939745 ~/ 4;
  return (century, cyear, ayday);
}

/// `absYday.split`: ayday (0-based, março=0) → (absMonth 0-based março=0, mday 1-based).
(int, int) _splitAyday(int ayday) {
  final d = 2141 * ayday + 197913;
  final amonth = d ~/ 0x10000;
  final mday = 1 + (d % 0x10000) ~/ 2141;
  return (amonth, mday);
}

/// `absYday.janFeb`: 1 se ayday cai em janeiro/fevereiro do ano padrão.
int _aydayJanFeb(int ayday) => ayday >= _marchThruDecember ? 1 : 0;

/// `absMonth.month`: absMonth (3-based: março=3, ..., janeiro=13,
/// fevereiro=14) + janFeb → `time.Month` (1-based).
int _absMonthToMonth(int amonth, int janFeb) => amonth - janFeb * 12;

/// `absCentury.leap`.
bool _absLeap(int century, int cyear) {
  final y4ok = cyear % 4 == 0;
  final y100ok = cyear != 0;
  final y400ok = century % 4 == 0;
  return y4ok && (y100ok || y400ok);
}

/// `absCentury.year`.
int _absYear(int century, int cyear, int janFeb) =>
    century * 100 - _absoluteYears + cyear + janFeb;

/// `absYday.yday`: 1-based, dia do ano padrão (janeiro=1).
int _aydayToYday(int ayday, int janFeb, bool leap) {
  final leapAdj = janFeb == 1 ? 0 : (leap ? 1 : 0);
  return ayday + (1 + 31 + 28) + leapAdj - 365 * janFeb;
}

/// `days.date()`: dias desde o ano absoluto → (year, month, day).
(int, int, int) _daysToDate(int days) {
  final (century, cyear, ayday) = _splitDays(days);
  final (amonth, day) = _splitAyday(ayday);
  final janFeb = _aydayJanFeb(ayday);
  final year = _absYear(century, cyear, janFeb);
  final month = _absMonthToMonth(amonth, janFeb);
  return (year, month, day);
}

/// `days.yearYday()`: dias → (year, yday 1-based).
(int, int) _daysToYearYday(int days) {
  final (century, cyear, ayday) = _splitDays(days);
  final janFeb = _aydayJanFeb(ayday);
  final year = _absYear(century, cyear, janFeb);
  final yday = _aydayToYday(ayday, janFeb, _absLeap(century, cyear));
  return (year, yday);
}

/// `days.weekday()`: 1º de março do ano absoluto era quarta-feira (3).
int _weekdayOfDays(int days) => (days + 3) % 7;

/// `absSeconds.clock()`: segundos dentro do dia → (hour, min, sec).
(int, int, int) _clockOfSecOfDay(int secOfDay) {
  var sec = secOfDay;
  final hour = sec ~/ 3600;
  sec -= hour * 3600;
  final min = sec ~/ 60;
  sec -= min * 60;
  return (hour, min, sec);
}

/// `isLeap(year)`: `%` do Dart em `int` é módulo euclidiano (sempre
/// não-negativo, ao contrário do Go), o que já dá o resultado certo mesmo
/// para `year` negativo, sem precisar do truque bit a bit do Go (`&`, que
/// dependeria de complemento de dois).
bool _isLeapYear(int year) {
  final mod = year % 25 != 0 ? 4 : 16;
  return year % mod == 0;
}

/// `daysBefore(m)`: dias antes do mês `m` (1-based) num ano não-bissexto;
/// `daysBefore(13)` (December+1) devolve 365.
int _daysBefore(int month) {
  final adj = month >= 3 ? -2 : 0;
  return (214 * month - 211) ~/ 7 + adj;
}

const _daysInMonthTable = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

/// `daysIn(m, year)`.
int _daysInMonth(int month, int year) {
  if (month == 2) return _isLeapYear(year) ? 29 : 28;
  return _daysInMonthTable[month - 1];
}

/// `norm(hi, lo, base)`: `hi*base+lo == nhi*base+nlo`, `0 <= nlo < base`.
(int, int) _norm(int hi, int lo, int base) {
  var nhi = hi, nlo = lo;
  if (nlo < 0) {
    final n = (-nlo - 1) ~/ base + 1;
    nhi -= n;
    nlo += n * base;
  }
  if (nlo >= base) {
    final n = nlo ~/ base;
    nhi += n;
    nlo -= n * base;
  }
  return (nhi, nlo);
}
