part of '../../time.dart';

// Porta de `parse(layout, value, defaultLocation, local)` de
// `time/format.go` do Go 1.26.5: o laço sobre `nextStdChunk` e a montagem do
// `Time` (ano/dia do ano, AM/PM, zona por offset ou por nome). Auxiliares
// em `parse.dart`.

(Time, GoError?) _parseBytes(
  String layout,
  String value,
  Location? defaultLocation,
  Location? local,
) {
  final alayout = layout, avalue = value;
  var rangeErrString = '';
  var amSet = false, pmSet = false;

  var year = 0, month = -1, day = -1, yday = -1;
  var hour = 0, min = 0, sec = 0, nsec = 0;
  var zUTC = false;
  var zoneOffset = -1;
  var zoneName = '';

  (Time, GoError?) fail(String layoutElem, String valueElem, String msg) =>
      (Time(), _newParseError(alayout, avalue, layoutElem, valueElem, msg));

  for (;;) {
    final (prefix, std0, suffix) = _nextStdChunk(layout);
    var std = std0;
    final stdstr = layout.substring(
      prefix.length,
      layout.length - suffix.length,
    );
    final skipped = _skip(value, prefix);
    if (skipped == null) return fail(prefix, value, '');
    value = skipped;
    if (std == 0) {
      if (value.isNotEmpty) {
        return fail('', value, ': extra text: ${_quote(value)}');
      }
      break;
    }
    layout = suffix;
    final hold = value;
    var bad = false;

    // `getnum`/`getnum3`: atribui e devolve o número, ou marca `errBad`
    // (o valor fica como estava e o número é 0, como no Go).
    int num((int, String)? r) {
      if (r == null) {
        bad = true;
        return 0;
      }
      value = r.$2;
      return r.$1;
    }

    switch (std & _stdMask) {
      case _stdYear:
        if (value.length < 2) {
          bad = true;
          break;
        }
        final p = value.substring(0, 2);
        value = value.substring(2);
        final y = _atoi(p);
        if (y == null) {
          bad = true;
          break;
        }
        // O tempo Unix começa em 31/12/1969 em alguns fusos.
        year = y >= 69 ? y + 1900 : y + 2000;
      case _stdLongYear:
        if (value.length < 4 || !_isDigitAt(value, 0)) {
          bad = true;
          break;
        }
        final p = value.substring(0, 4);
        value = value.substring(4);
        final y = _atoi(p);
        if (y == null) {
          bad = true;
        } else {
          year = y;
        }
      case _stdMonth || _stdLongMonth:
        final (i, rest) = _lookupName(
          std == _stdMonth ? _shortMonthNames : _longMonthNames,
          value,
        );
        value = rest;
        bad = i < 0;
        month = i + 1;
      case _stdNumMonth || _stdZeroMonth:
        month = num(_getnum(value, std == _stdZeroMonth));
        if (!bad && (month <= 0 || 12 < month)) rangeErrString = 'month';
      case _stdWeekDay || _stdLongWeekDay:
        // O dia da semana só é conferido, não usado.
        final (i, rest) = _lookupName(
          std == _stdWeekDay ? _shortDayNames : _longDayNames,
          value,
        );
        value = rest;
        bad = i < 0;
      case _stdDay || _stdUnderDay || _stdZeroDay:
        if (std == _stdUnderDay && value.isNotEmpty && value[0] == ' ') {
          value = value.substring(1);
        }
        day = num(_getnum(value, std == _stdZeroDay));
      case _stdUnderYearDay || _stdZeroYearDay:
        for (var i = 0; i < 2; i++) {
          if (std == _stdUnderYearDay && value.isNotEmpty && value[0] == ' ') {
            value = value.substring(1);
          }
        }
        yday = num(_getnum3(value, std == _stdZeroYearDay));
      case _stdHour:
        hour = num(_getnum(value, false));
        if (hour < 0 || 24 <= hour) rangeErrString = 'hour';
      case _stdHour12 || _stdZeroHour12:
        hour = num(_getnum(value, std == _stdZeroHour12));
        if (hour < 0 || 12 < hour) rangeErrString = 'hour';
      case _stdMinute || _stdZeroMinute:
        min = num(_getnum(value, std == _stdZeroMinute));
        if (min < 0 || 60 <= min) rangeErrString = 'minute';
      case _stdSecond || _stdZeroSecond:
        sec = num(_getnum(value, std == _stdZeroSecond));
        if (bad) break;
        if (sec < 0 || 60 <= sec) {
          rangeErrString = 'second';
          break;
        }
        // Fração de segundo no valor sem fração no layout?
        if (value.length >= 2 &&
            _commaOrPeriod(value.codeUnitAt(0)) &&
            _isDigitAt(value, 1)) {
          final (_, next, _) = _nextStdChunk(layout);
          std = next & _stdMask;
          if (std == _stdFracSecond0 || std == _stdFracSecond9) break;
          var n = 2;
          while (n < value.length && _isDigitAt(value, n)) {
            n++;
          }
          final (ns, rerr, ok) = _parseNanoseconds(value, n);
          nsec = ns;
          rangeErrString = rerr;
          bad = !ok;
          value = value.substring(n);
        }
      case _stdPM || _stdpm:
        if (value.length < 2) {
          bad = true;
          break;
        }
        final p = value.substring(0, 2);
        value = value.substring(2);
        final (pm, am) = std == _stdPM ? ('PM', 'AM') : ('pm', 'am');
        if (p == pm) {
          pmSet = true;
        } else if (p == am) {
          amSet = true;
        } else {
          bad = true;
        }
      case _stdISO8601TZ ||
          _stdISO8601ShortTZ ||
          _stdISO8601ColonTZ ||
          _stdISO8601SecondsTZ ||
          _stdISO8601ColonSecondsTZ ||
          _stdNumTZ ||
          _stdNumShortTZ ||
          _stdNumColonTZ ||
          _stdNumSecondsTz ||
          _stdNumColonSecondsTZ:
        if (std < _stdNumTZ && value.isNotEmpty && value[0] == 'Z') {
          value = value.substring(1);
          zUTC = true;
          break;
        }
        String sign, hh, mm, ss;
        if (std == _stdISO8601ColonTZ || std == _stdNumColonTZ) {
          if (value.length < 6 || value[3] != ':') {
            bad = true;
            break;
          }
          (sign, hh, mm, ss) = (
            value[0],
            value.substring(1, 3),
            value.substring(4, 6),
            '00',
          );
          value = value.substring(6);
        } else if (std == _stdNumShortTZ || std == _stdISO8601ShortTZ) {
          if (value.length < 3) {
            bad = true;
            break;
          }
          (sign, hh, mm, ss) = (value[0], value.substring(1, 3), '00', '00');
          value = value.substring(3);
        } else if (std == _stdISO8601ColonSecondsTZ ||
            std == _stdNumColonSecondsTZ) {
          if (value.length < 9 || value[3] != ':' || value[6] != ':') {
            bad = true;
            break;
          }
          (sign, hh, mm, ss) = (
            value[0],
            value.substring(1, 3),
            value.substring(4, 6),
            value.substring(7, 9),
          );
          value = value.substring(9);
        } else if (std == _stdISO8601SecondsTZ || std == _stdNumSecondsTz) {
          if (value.length < 7) {
            bad = true;
            break;
          }
          (sign, hh, mm, ss) = (
            value[0],
            value.substring(1, 3),
            value.substring(3, 5),
            value.substring(5, 7),
          );
          value = value.substring(7);
        } else {
          if (value.length < 5) {
            bad = true;
            break;
          }
          (sign, hh, mm, ss) = (
            value[0],
            value.substring(1, 3),
            value.substring(3, 5),
            '00',
          );
          value = value.substring(5);
        }
        var hr = 0, mi = 0, se = 0;
        final rh = _getnum(hh, true);
        if (rh == null) {
          bad = true;
        } else {
          hr = rh.$1;
          final rm = _getnum(mm, true);
          if (rm == null) {
            bad = true;
          } else {
            mi = rm.$1;
            final rs = _getnum(ss, true);
            if (rs == null) {
              bad = true;
            } else {
              se = rs.$1;
            }
          }
        }
        // `>` e não `>=`: há quem escreva offsets de 24h ou 60min.
        if (hr > 24) rangeErrString = 'time zone offset hour';
        if (mi > 60) rangeErrString = 'time zone offset minute';
        if (se > 60) rangeErrString = 'time zone offset second';
        zoneOffset = (hr * 60 + mi) * 60 + se;
        switch (sign) {
          case '+':
            break;
          case '-':
            zoneOffset = -zoneOffset;
          default:
            bad = true;
        }
      case _stdTZ:
        if (value.length >= 3 && value.startsWith('UTC')) {
          zUTC = true;
          value = value.substring(3);
          break;
        }
        final n = _parseTimeZone(value);
        if (n == null) {
          bad = true;
          break;
        }
        zoneName = value.substring(0, n);
        value = value.substring(n);
      case _stdFracSecond0:
        // Exige exatamente os dígitos do layout.
        final ndigit = 1 + _digitsLen(std);
        if (value.length < ndigit) {
          bad = true;
          break;
        }
        final (ns, rerr, ok) = _parseNanoseconds(value, ndigit);
        nsec = ns;
        rangeErrString = rerr;
        bad = !ok;
        value = value.substring(ndigit);
      case _stdFracSecond9:
        if (value.length < 2 ||
            !_commaOrPeriod(value.codeUnitAt(0)) ||
            !_isDigitAt(value, 1)) {
          break; // fração omitida
        }
        // Aceita quantos dígitos vierem (como o caso stdSecond).
        var i = 0;
        while (i + 1 < value.length && _isDigitAt(value, i + 1)) {
          i++;
        }
        final (ns, rerr, ok) = _parseNanoseconds(value, 1 + i);
        nsec = ns;
        rangeErrString = rerr;
        bad = !ok;
        value = value.substring(1 + i);
    }
    if (rangeErrString.isNotEmpty) {
      return fail(stdstr, value, ': $rangeErrString out of range');
    }
    if (bad) return fail(stdstr, hold, '');
  }
  if (pmSet && hour < 12) {
    hour += 12;
  } else if (amSet && hour == 12) {
    hour = 0;
  }

  // Dia do ano → mês e dia.
  if (yday >= 0) {
    var d = 0, m = 0;
    if (_isLeap(year)) {
      if (yday == 31 + 29) {
        m = 2;
        d = 29;
      } else if (yday > 31 + 29) {
        yday--;
      }
    }
    if (yday < 1 || yday > 365) {
      return fail('', value, ': day-of-year out of range');
    }
    if (m == 0) {
      m = (yday - 1) ~/ 31 + 1;
      if (_daysBefore(m + 1) < yday) m++;
      d = yday - _daysBefore(m);
    }
    // Mês e dia já lidos têm de bater com os do dia do ano.
    if (month >= 0 && month != m) {
      return fail('', value, ': day-of-year does not match month');
    }
    month = m;
    if (day >= 0 && day != d) {
      return fail('', value, ': day-of-year does not match day');
    }
    day = d;
  } else {
    if (month < 0) month = 1;
    if (day < 0) day = 1;
  }

  if (day < 1 || day > _daysIn(month, year)) {
    return fail('', value, ': day out of range');
  }

  if (zUTC) {
    return (
      _dateImpl(year, month, day, hour, min, sec, nsec, _utcSentinel),
      null,
    );
  }

  if (zoneOffset != -1) {
    final t = _dateImpl(year, month, day, hour, min, sec, nsec, _utcSentinel);
    t._addSecs(Golang.Int64(-zoneOffset));
    // Zona do `local` com esse offset (e nome, se houver)?
    final (name, offset) = (local ?? _utcSentinel)._lookup();
    if (offset == zoneOffset && (zoneName.isEmpty || name == zoneName)) {
      t._setLocation(local);
      return (t, null);
    }
    // Senão, uma zona fixa inventada para guardar o offset.
    t._setLocation(Location._(zoneName, zoneOffset));
    return (t, null);
  }

  if (zoneName.isNotEmpty) {
    final t = _dateImpl(year, month, day, hour, min, sec, nsec, _utcSentinel);
    // `lookupName`: zona fixa só conhece o próprio nome.
    final (name, lofs) = (local ?? _utcSentinel)._lookup();
    if (name == zoneName) {
      t._addSecs(Golang.Int64(-lofs));
      t._setLocation(local);
      return (t, null);
    }
    // Zona inventada com offset desconhecido (0), salvo `GMT±h`.
    var offset = 0;
    if (zoneName.length > 3 && zoneName.startsWith('GMT')) {
      offset = (_atoi(zoneName.substring(3)) ?? 0) * 3600;
    }
    t._setLocation(Location._(zoneName, offset));
    return (t, null);
  }

  // Sem zona: a padrão.
  if (defaultLocation == null) {
    throw Panic(
      Golang.String.fromDart('time: missing Location in call to Date'),
    );
  }
  return (
    _dateImpl(year, month, day, hour, min, sec, nsec, defaultLocation),
    null,
  );
}
