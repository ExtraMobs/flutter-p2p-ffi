part of '../../../net/netip.dart';

/// `parseAddrError` (não exportado): erro por valor de `ParseAddr`.
final class _ParseAddrError extends GoStruct<_ParseAddrError>
    implements GoError {
  _ParseAddrError({required this.in$, required this.msg, Golang.String? at})
    : at = at ?? Golang.String() {
    $isValue = true;
  }

  Golang.String in$;
  Golang.String msg;
  Golang.String at;

  @override
  String get $goType => 'netip.parseAddrError';
  @override
  List<String> get $valueMethods => const ['Error'];
  @override
  List<String> get $ptrMethods => const ['Error'];
  @override
  _ParseAddrError $copy() => _ParseAddrError(in$: in$, msg: msg, at: at);
  @override
  void $set(_ParseAddrError o) {
    in$ = o.in$;
    msg = o.msg;
    at = o.at;
  }

  @override
  List<Object?> get $fields => [in$, msg, at];
  @override
  List<String> get $fieldNames => const ['in', 'msg', 'at'];
  @override
  List<String> get $fieldTypes => const ['string', 'string', 'string'];

  @override
  Golang.String error() {
    final q = strconv.quote;
    if (at.length != 0) {
      return _gs('ParseAddr(') +
          q(in$) +
          _gs('): ') +
          msg +
          _gs(' (at ') +
          q(at) +
          _gs(')');
    }
    return _gs('ParseAddr(') + q(in$) + _gs('): ') + msg;
  }
}

_ParseAddrError _perr(Golang.String in$, String msg, [Golang.String? at]) =>
    _ParseAddrError(in$: in$, msg: _gs(msg), at: at);

/// `ParseAddr(s)`: decimal com pontos, IPv6 ou IPv6 com zona.
(Addr, GoError?) parseAddr(Golang.String s) {
  for (var i = 0; i < s.length; i++) {
    switch (s[i]) {
      case 0x2e: // '.'
        return _parseIPv4(s);
      case 0x3a: // ':'
        return _parseIPv6(s);
      case 0x25: // '%'
        return (Addr(), _perr(s, 'missing IPv6 address'));
    }
  }
  return (Addr(), _perr(s, 'unable to parse IP'));
}

/// `MustParseAddr(s)`: pânico com o erro de [parseAddr].
Addr mustParseAddr(Golang.String s) {
  final (ip, err) = parseAddr(s);
  if (err != null) throw Panic(err);
  return ip;
}

/// `parseIPv4Fields`: os 4 octetos de `in[off:end]` em [fields] a partir
/// de [fo].
GoError? _parseIPv4Fields(
  Golang.String in$,
  int off,
  int end,
  List<int> fields,
  int fo,
) {
  var val = 0, pos = 0, digLen = 0;
  final s = in$.slice(off, end);
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c >= 0x30 && c <= 0x39) {
      if (digLen == 1 && val == 0) {
        return _perr(in$, 'IPv4 field has octet with leading zero');
      }
      val = val * 10 + c - 0x30;
      digLen++;
      if (val > 255) return _perr(in$, 'IPv4 field has value >255');
    } else if (c == 0x2e) {
      if (i == 0 || i == s.length - 1 || s[i - 1] == 0x2e) {
        return _perr(
          in$,
          'IPv4 field must have at least one digit',
          s.slice(i),
        );
      }
      if (pos == 3) return _perr(in$, 'IPv4 address too long');
      fields[fo + pos] = val;
      pos++;
      val = 0;
      digLen = 0;
    } else {
      return _perr(in$, 'unexpected character', s.slice(i));
    }
  }
  if (pos < 3) return _perr(in$, 'IPv4 address too short');
  fields[fo + 3] = val;
  return null;
}

(Addr, GoError?) _parseIPv4(Golang.String s) {
  final fields = List<int>.filled(4, 0);
  final err = _parseIPv4Fields(s, 0, s.length, fields, 0);
  if (err != null) return (Addr(), err);
  return (_addrFrom4Bytes(fields), null);
}

int _hexVal(int c) {
  if (c >= 0x30 && c <= 0x39) return c - 0x30;
  if (c >= 0x61 && c <= 0x66) return c - 0x61 + 10;
  if (c >= 0x41 && c <= 0x46) return c - 0x41 + 10;
  return -1;
}

(Addr, GoError?) _parseIPv6(Golang.String in$) {
  var s = in$;
  var zone = Golang.String();
  var i = _indexByte(s, 0x25);
  if (i != -1) {
    zone = s.slice(i + 1);
    s = s.slice(0, i);
    if (zone.length == 0) {
      return (Addr(), _perr(in$, 'zone must be a non-empty string'));
    }
  }
  final ip = List<int>.filled(16, 0);
  var ellipsis = -1;
  if (s.length >= 2 && s[0] == 0x3a && s[1] == 0x3a) {
    ellipsis = 0;
    s = s.slice(2);
    if (s.length == 0) return (iPv6Unspecified().withZone(zone), null);
  }
  i = 0;
  while (i < 16) {
    var off = 0;
    var acc = 0;
    for (; off < s.length; off++) {
      final d = _hexVal(s[off]);
      if (d < 0) break;
      acc = (acc << 4) + d;
      if (off > 3) {
        return (Addr(), _perr(in$, 'each group must have 4 or less digits', s));
      }
      if (acc > 0xffff) {
        return (Addr(), _perr(in$, 'IPv6 field has value >=2^16', s));
      }
    }
    if (off == 0) {
      return (
        Addr(),
        _perr(
          in$,
          'each colon-separated field must have at least one digit',
          s,
        ),
      );
    }
    if (off < s.length && s[off] == 0x2e) {
      if (ellipsis < 0 && i != 12) {
        return (
          Addr(),
          _perr(
            in$,
            'embedded IPv4 address must replace the final 2 fields of the address',
            s,
          ),
        );
      }
      if (i + 4 > 16) {
        return (
          Addr(),
          _perr(
            in$,
            'too many hex fields to fit an embedded IPv4 at the end of the address',
            s,
          ),
        );
      }
      var end = in$.length;
      if (zone.length > 0) end -= zone.length + 1;
      final err = _parseIPv4Fields(in$, end - s.length, end, ip, i);
      if (err != null) return (Addr(), err);
      s = Golang.String();
      i += 4;
      break;
    }
    ip[i] = (acc >> 8) & 0xff;
    ip[i + 1] = acc & 0xff;
    i += 2;
    s = s.slice(off);
    if (s.length == 0) break;
    if (s[0] != 0x3a) {
      return (Addr(), _perr(in$, 'unexpected character, want colon', s));
    } else if (s.length == 1) {
      return (
        Addr(),
        _perr(in$, 'colon must be followed by more characters', s),
      );
    }
    s = s.slice(1);
    if (s[0] == 0x3a) {
      if (ellipsis >= 0) {
        return (Addr(), _perr(in$, 'multiple :: in address', s));
      }
      ellipsis = i;
      s = s.slice(1);
      if (s.length == 0) break;
    }
  }
  if (s.length != 0) {
    return (Addr(), _perr(in$, 'trailing garbage after address', s));
  }
  if (i < 16) {
    if (ellipsis < 0) return (Addr(), _perr(in$, 'address string too short'));
    final n = 16 - i;
    for (var j = i - 1; j >= ellipsis; j--) {
      ip[j + n] = ip[j];
    }
    ip.fillRange(ellipsis, ellipsis + n, 0);
  } else if (ellipsis >= 0) {
    return (
      Addr(),
      _perr(in$, 'the :: must expand to at least one field of zeros'),
    );
  }
  return (_addrFrom16Bytes(ip).withZone(zone), null);
}

/// `bytealg.IndexByteString(s, c)`.
int _indexByte(Golang.String s, int c) {
  for (var i = 0; i < s.length; i++) {
    if (s[i] == c) return i;
  }
  return -1;
}

/// `bytealg.LastIndexByteString(s, c)`.
int _lastIndexByte(Golang.String s, int c) {
  for (var i = s.length - 1; i >= 0; i--) {
    if (s[i] == c) return i;
  }
  return -1;
}
