part of '../../time.dart';

// Porta do interpretador de layouts de `time/format.go` do Go 1.26.5
// (`nextStdChunk`, `appendFormat`, `appendNano`) e de
// `appendFormatRFC3339`/`appendStrictRFC3339` de `time/format_rfc3339.go`.
//
// Layout, valor e saída são "strings de bytes" (um code unit por byte do Go,
// [_bytesOf]): índices e fatias em bytes, como no Go. Os códigos `std*` e o
// empacotamento (`stdArgShift`/`stdSeparatorShift`) são os do Go; cabem em
// 31 bits, então `&`/`>>`/`<<` valem igual no JS.
//
// As constantes de layout (`time.RFC3339`...) o g2d dobra no literal (são
// `const` string no Go), então não há símbolos delas aqui.

const _stdNeedDate = 1 << 8;
const _stdNeedYday = 1 << 9;
const _stdNeedClock = 1 << 10;
const _stdArgShift = 16;
const _stdSeparatorShift = 28;
const _stdMask = (1 << _stdArgShift) - 1;

const _stdLongMonth = 1 + _stdNeedDate; // "January"
const _stdMonth = 2 + _stdNeedDate; // "Jan"
const _stdNumMonth = 3 + _stdNeedDate; // "1"
const _stdZeroMonth = 4 + _stdNeedDate; // "01"
const _stdLongWeekDay = 5 + _stdNeedDate; // "Monday"
const _stdWeekDay = 6 + _stdNeedDate; // "Mon"
const _stdDay = 7 + _stdNeedDate; // "2"
const _stdUnderDay = 8 + _stdNeedDate; // "_2"
const _stdZeroDay = 9 + _stdNeedDate; // "02"
const _stdUnderYearDay = 10 + _stdNeedYday; // "__2"
const _stdZeroYearDay = 11 + _stdNeedYday; // "002"
const _stdHour = 12 + _stdNeedClock; // "15"
const _stdHour12 = 13 + _stdNeedClock; // "3"
const _stdZeroHour12 = 14 + _stdNeedClock; // "03"
const _stdMinute = 15 + _stdNeedClock; // "4"
const _stdZeroMinute = 16 + _stdNeedClock; // "04"
const _stdSecond = 17 + _stdNeedClock; // "5"
const _stdZeroSecond = 18 + _stdNeedClock; // "05"
const _stdLongYear = 19 + _stdNeedDate; // "2006"
const _stdYear = 20 + _stdNeedDate; // "06"
const _stdPM = 21 + _stdNeedClock; // "PM"
const _stdpm = 22 + _stdNeedClock; // "pm"
const _stdTZ = 23; // "MST"
const _stdISO8601TZ = 24; // "Z0700"
const _stdISO8601SecondsTZ = 25; // "Z070000"
const _stdISO8601ShortTZ = 26; // "Z07"
const _stdISO8601ColonTZ = 27; // "Z07:00"
const _stdISO8601ColonSecondsTZ = 28; // "Z07:00:00"
const _stdNumTZ = 29; // "-0700"
const _stdNumSecondsTz = 30; // "-070000"
const _stdNumShortTZ = 31; // "-07"
const _stdNumColonTZ = 32; // "-07:00"
const _stdNumColonSecondsTZ = 33; // "-07:00:00"
const _stdFracSecond0 = 34; // ".0", ".00", ...
const _stdFracSecond9 = 35; // ".9", ".99", ...

/// `std0x`: "01".."06".
const _std0x = [
  _stdZeroMonth,
  _stdZeroDay,
  _stdZeroHour12,
  _stdZeroMinute,
  _stdZeroSecond,
  _stdYear,
];

const _rfc3339 = '2006-01-02T15:04:05Z07:00';
const _rfc3339Nano = '2006-01-02T15:04:05.999999999Z07:00';

const _shortDayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const _shortMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

bool _startsWithLowerCase(String s) {
  if (s.isEmpty) return false;
  final c = s.codeUnitAt(0);
  return 0x61 <= c && c <= 0x7a;
}

/// `isDigit(s, i)`.
bool _isDigitAt(String s, int i) {
  if (s.length <= i) return false;
  final c = s.codeUnitAt(i);
  return 0x30 <= c && c <= 0x39;
}

bool _has(String s, int i, String w) =>
    s.length >= i + w.length && s.startsWith(w, i);

/// `stdFracSecond(code, n, c)`.
int _stdFracSecond(int code, int n, int c) {
  if (c == 0x2e) return code | ((n & 0xfff) << _stdArgShift);
  return code | ((n & 0xfff) << _stdArgShift) | 1 << _stdSeparatorShift;
}

int _digitsLen(int std) => (std >> _stdArgShift) & 0xfff;

int _separator(int std) => (std >> _stdSeparatorShift) == 0 ? 0x2e : 0x2c;

/// `nextStdChunk(layout)`: (prefixo, std, sufixo).
(String, int, String) _nextStdChunk(String layout) {
  (String, int, String) r(int i, int std, int end) =>
      (layout.substring(0, i), std, layout.substring(end));
  for (var i = 0; i < layout.length; i++) {
    final c = layout.codeUnitAt(i);
    switch (c) {
      case 0x4a: // 'J': January, Jan
        if (_has(layout, i, 'Jan')) {
          if (_has(layout, i, 'January')) return r(i, _stdLongMonth, i + 7);
          if (!_startsWithLowerCase(layout.substring(i + 3))) {
            return r(i, _stdMonth, i + 3);
          }
        }
      case 0x4d: // 'M': Monday, Mon, MST
        if (layout.length >= i + 3) {
          if (_has(layout, i, 'Mon')) {
            if (_has(layout, i, 'Monday')) {
              return r(i, _stdLongWeekDay, i + 6);
            }
            if (!_startsWithLowerCase(layout.substring(i + 3))) {
              return r(i, _stdWeekDay, i + 3);
            }
          }
          if (_has(layout, i, 'MST')) return r(i, _stdTZ, i + 3);
        }
      case 0x30: // '0': 01, 02, 03, 04, 05, 06, 002
        if (layout.length >= i + 2) {
          final d = layout.codeUnitAt(i + 1);
          if (0x31 <= d && d <= 0x36) return r(i, _std0x[d - 0x31], i + 2);
        }
        if (_has(layout, i + 1, '02')) return r(i, _stdZeroYearDay, i + 3);
      case 0x31: // '1': 15, 1
        if (_has(layout, i + 1, '5')) return r(i, _stdHour, i + 2);
        return r(i, _stdNumMonth, i + 1);
      case 0x32: // '2': 2006, 2
        if (_has(layout, i, '2006')) return r(i, _stdLongYear, i + 4);
        return r(i, _stdDay, i + 1);
      case 0x5f: // '_': _2, _2006, __2
        if (_has(layout, i + 1, '2')) {
          // `_2006` é um `_` literal seguido de stdLongYear.
          if (_has(layout, i + 1, '2006')) {
            return (
              layout.substring(0, i + 1),
              _stdLongYear,
              layout.substring(i + 5),
            );
          }
          return r(i, _stdUnderDay, i + 2);
        }
        if (_has(layout, i + 1, '_2')) return r(i, _stdUnderYearDay, i + 3);
      case 0x33: // '3'
        return r(i, _stdHour12, i + 1);
      case 0x34: // '4'
        return r(i, _stdMinute, i + 1);
      case 0x35: // '5'
        return r(i, _stdSecond, i + 1);
      case 0x50: // 'P': PM
        if (_has(layout, i + 1, 'M')) return r(i, _stdPM, i + 2);
      case 0x70: // 'p': pm
        if (_has(layout, i + 1, 'm')) return r(i, _stdpm, i + 2);
      case 0x2d: // '-': -070000, -07:00:00, -0700, -07:00, -07
        if (_has(layout, i, '-070000')) return r(i, _stdNumSecondsTz, i + 7);
        if (_has(layout, i, '-07:00:00')) {
          return r(i, _stdNumColonSecondsTZ, i + 9);
        }
        if (_has(layout, i, '-0700')) return r(i, _stdNumTZ, i + 5);
        if (_has(layout, i, '-07:00')) return r(i, _stdNumColonTZ, i + 6);
        if (_has(layout, i, '-07')) return r(i, _stdNumShortTZ, i + 3);
      case 0x5a: // 'Z': Z070000, Z07:00:00, Z0700, Z07:00, Z07
        if (_has(layout, i, 'Z070000')) {
          return r(i, _stdISO8601SecondsTZ, i + 7);
        }
        if (_has(layout, i, 'Z07:00:00')) {
          return r(i, _stdISO8601ColonSecondsTZ, i + 9);
        }
        if (_has(layout, i, 'Z0700')) return r(i, _stdISO8601TZ, i + 5);
        if (_has(layout, i, 'Z07:00')) return r(i, _stdISO8601ColonTZ, i + 6);
        if (_has(layout, i, 'Z07')) return r(i, _stdISO8601ShortTZ, i + 3);
      case 0x2e || 0x2c: // ,000 .000 ,999 .999: fração de segundo
        if (i + 1 < layout.length) {
          final ch = layout.codeUnitAt(i + 1);
          if (ch == 0x30 || ch == 0x39) {
            var j = i + 1;
            while (j < layout.length && layout.codeUnitAt(j) == ch) {
              j++;
            }
            // A fração termina aqui: só ela é feita só de dígitos.
            if (!_isDigitAt(layout, j)) {
              final code = ch == 0x39 ? _stdFracSecond9 : _stdFracSecond0;
              return r(i, _stdFracSecond(code, j - (i + 1), c), j);
            }
          }
        }
    }
  }
  return (layout, 0, '');
}

/// `appendNano(b, nanosec, std)`.
void _appendNano(StringBuffer b, int nanosec, int std) {
  final trim = std & _stdMask == _stdFracSecond9;
  final n = _digitsLen(std);
  if (trim && (n == 0 || nanosec == 0)) return;
  final dot = _separator(std);
  var digits = nanosec.toString().padLeft(9, '0');
  if (n < 9) digits = digits.substring(0, n);
  var s = String.fromCharCode(dot) + digits;
  if (trim) {
    var end = s.length;
    while (end > 0 && s.codeUnitAt(end - 1) == 0x30) {
      end--;
    }
    if (end > 0 && s.codeUnitAt(end - 1) == dot) end--;
    s = s.substring(0, end);
  }
  b.write(s);
}

/// Offset numérico `±hh[:]mm` (o `-0700` do `stdTZ` sem nome e do RFC 3339).
void _appendZoneHHMM(StringBuffer b, int offset, {bool colon = false}) {
  var zone = offset ~/ 60; // minutos (divisão truncada, como no Go)
  if (zone < 0) {
    b.write('-');
    zone = -zone;
  } else {
    b.write('+');
  }
  _appendInt(b, zone ~/ 60, 2);
  if (colon) b.write(':');
  _appendInt(b, zone % 60, 2);
}

/// Bytes UTF-8 do nome da zona como string de bytes.
String _zoneBytes(String name) => _bytesOf(Golang.String.fromDart(name));

/// `t.AppendFormat` sobre strings de bytes.
String _formatBytes(Time t, String layout) {
  final b = StringBuffer();
  if (layout == _rfc3339) {
    _appendFormatRFC3339(t, b, false);
  } else if (layout == _rfc3339Nano) {
    _appendFormatRFC3339(t, b, true);
  } else {
    _appendFormat(t, b, layout);
  }
  return b.toString();
}

void _appendFormat(Time t, StringBuffer b, String layout) {
  final (name, offset, days, secOfDay) = t._locabs();
  var year = -1, month = 0, day = 0, yday = -1;
  var hour = -1, min = 0, sec = 0;

  // Cada volta gera um valor std.
  while (layout.isNotEmpty) {
    final (prefix, std, suffix) = _nextStdChunk(layout);
    if (prefix.isNotEmpty) b.write(prefix);
    if (std == 0) break;
    layout = suffix;

    if (year < 0 && std & _stdNeedDate != 0) {
      (year, month, day) = _daysToDate(days);
    }
    if (yday < 0 && std & _stdNeedYday != 0) {
      (_, yday) = _daysToYearYday(days);
    }
    if (hour < 0 && std & _stdNeedClock != 0) {
      (hour, min, sec) = _clockOfSecOfDay(secOfDay);
    }

    switch (std & _stdMask) {
      case _stdYear:
        _appendInt(b, year.abs() % 100, 2);
      case _stdLongYear:
        _appendInt(b, year, 4);
      case _stdMonth:
        b.write(_shortMonthNames[month - 1]);
      case _stdLongMonth:
        b.write(_longMonthNames[month - 1]);
      case _stdNumMonth:
        _appendInt(b, month, 0);
      case _stdZeroMonth:
        _appendInt(b, month, 2);
      case _stdWeekDay:
        b.write(_shortDayNames[_weekdayOfDays(days)]);
      case _stdLongWeekDay:
        b.write(_longDayNames[_weekdayOfDays(days)]);
      case _stdDay:
        _appendInt(b, day, 0);
      case _stdUnderDay:
        if (day < 10) b.write(' ');
        _appendInt(b, day, 0);
      case _stdZeroDay:
        _appendInt(b, day, 2);
      case _stdUnderYearDay:
        if (yday < 100) {
          b.write(' ');
          if (yday < 10) b.write(' ');
        }
        _appendInt(b, yday, 0);
      case _stdZeroYearDay:
        _appendInt(b, yday, 3);
      case _stdHour:
        _appendInt(b, hour, 2);
      case _stdHour12:
        // Meio-dia é 12PM, meia-noite 12AM.
        final hr = hour % 12;
        _appendInt(b, hr == 0 ? 12 : hr, 0);
      case _stdZeroHour12:
        final hr = hour % 12;
        _appendInt(b, hr == 0 ? 12 : hr, 2);
      case _stdMinute:
        _appendInt(b, min, 0);
      case _stdZeroMinute:
        _appendInt(b, min, 2);
      case _stdSecond:
        _appendInt(b, sec, 0);
      case _stdZeroSecond:
        _appendInt(b, sec, 2);
      case _stdPM:
        b.write(hour >= 12 ? 'PM' : 'AM');
      case _stdpm:
        b.write(hour >= 12 ? 'pm' : 'am');
      case _stdISO8601TZ ||
          _stdISO8601ColonTZ ||
          _stdISO8601SecondsTZ ||
          _stdISO8601ShortTZ ||
          _stdISO8601ColonSecondsTZ ||
          _stdNumTZ ||
          _stdNumColonTZ ||
          _stdNumSecondsTz ||
          _stdNumShortTZ ||
          _stdNumColonSecondsTZ:
        // As variantes "Z" escrevem `Z` para UTC (ISO 8601).
        if (offset == 0 &&
            (std == _stdISO8601TZ ||
                std == _stdISO8601ColonTZ ||
                std == _stdISO8601SecondsTZ ||
                std == _stdISO8601ShortTZ ||
                std == _stdISO8601ColonSecondsTZ)) {
          b.write('Z');
          break;
        }
        var zone = offset ~/ 60;
        var absoffset = offset;
        if (zone < 0) {
          b.write('-');
          zone = -zone;
          absoffset = -absoffset;
        } else {
          b.write('+');
        }
        _appendInt(b, zone ~/ 60, 2);
        if (std == _stdISO8601ColonTZ ||
            std == _stdNumColonTZ ||
            std == _stdISO8601ColonSecondsTZ ||
            std == _stdNumColonSecondsTZ) {
          b.write(':');
        }
        if (std != _stdNumShortTZ && std != _stdISO8601ShortTZ) {
          _appendInt(b, zone % 60, 2);
        }
        if (std == _stdISO8601SecondsTZ ||
            std == _stdNumSecondsTz ||
            std == _stdNumColonSecondsTZ ||
            std == _stdISO8601ColonSecondsTZ) {
          if (std == _stdNumColonSecondsTZ ||
              std == _stdISO8601ColonSecondsTZ) {
            b.write(':');
          }
          _appendInt(b, absoffset.remainder(60), 2); // `%` truncado do Go
        }
      case _stdTZ:
        if (name.isNotEmpty) {
          b.write(_zoneBytes(name));
        } else {
          // Zona sem nome: escreve no formato -0700.
          _appendZoneHHMM(b, offset);
        }
      case _stdFracSecond0 || _stdFracSecond9:
        _appendNano(b, t._nsecInt(), std);
    }
  }
}

/// `appendFormatRFC3339(b, nanos)`.
void _appendFormatRFC3339(Time t, StringBuffer b, bool nanos) {
  final (_, offset, days, secOfDay) = t._locabs();
  final (year, month, day) = _daysToDate(days);
  _appendInt(b, year, 4);
  b.write('-');
  _appendInt(b, month, 2);
  b.write('-');
  _appendInt(b, day, 2);
  b.write('T');
  final (hour, min, sec) = _clockOfSecOfDay(secOfDay);
  _appendInt(b, hour, 2);
  b.write(':');
  _appendInt(b, min, 2);
  b.write(':');
  _appendInt(b, sec, 2);
  if (nanos) {
    _appendNano(b, t._nsecInt(), _stdFracSecond(_stdFracSecond9, 9, 0x2e));
  }
  if (offset == 0) {
    b.write('Z');
    return;
  }
  _appendZoneHHMM(b, offset, colon: true);
}

/// `appendStrictRFC3339`: o texto RFC 3339 com nanos e a mensagem de erro
/// (sem o prefixo) quando o instante não cabe em RFC 3339.
(String, String?) _strictRFC3339(Time t) {
  final sb = StringBuffer();
  _appendFormatRFC3339(t, sb, true);
  final b = sb.toString();
  int num2(int i) =>
      10 * (b.codeUnitAt(i) - 0x30) + (b.codeUnitAt(i + 1) - 0x30);
  if (b.codeUnitAt(4) != 0x2d) {
    return (b, 'year outside of range [0,9999]');
  }
  if (b.codeUnitAt(b.length - 1) != 0x5a) {
    final c = b.codeUnitAt(b.length - 6);
    if ((0x30 <= c && c <= 0x39) || num2(b.length - 5) >= 24) {
      return (b, 'timezone hour outside of range [0,23]');
    }
  }
  return (b, null);
}
