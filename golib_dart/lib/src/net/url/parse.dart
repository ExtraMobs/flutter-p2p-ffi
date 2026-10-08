part of '../../../net/url.dart';

const _byteElem = Elem<Golang.Uint8>(
  1,
  Golang.Uint8.new,
  ofInt: Golang.Uint8.from,
);

/// `getScheme(rawURL)`.
(Golang.String, Golang.String, GoError?) _getScheme(Golang.String rawURL) {
  for (var i = 0; i < rawURL.length; i++) {
    final c = rawURL[i];
    if (0x61 <= c && c <= 0x7a || 0x41 <= c && c <= 0x5a) {
      // letra
    } else if (0x30 <= c && c <= 0x39 || c == 0x2b || c == 0x2d || c == 0x2e) {
      if (i == 0) return (Golang.String(), rawURL, null);
    } else if (c == 0x3a) {
      if (i == 0) {
        return (
          Golang.String(),
          Golang.String(),
          _errNew('missing protocol scheme'),
        );
      }
      return (rawURL.slice(0, i), rawURL.slice(i + 1), null);
    } else {
      return (Golang.String(), rawURL, null);
    }
  }
  return (Golang.String(), rawURL, null);
}

/// `Parse(rawURL)`: URL absoluta ou relativa; o fragmento é separado antes.
(URL?, GoError?) parse(Golang.String rawURL) => _parseURL(rawURL);

(URL?, GoError?) _parseURL(Golang.String rawURL) {
  final (u, frag, _) = strings.cut(rawURL, _gs('#'));
  final (url, err) = _parse(u, false);
  if (err != null) return (null, Error(op: _gs('parse'), url: u, err: err));
  if (frag.length == 0) return (url, null);
  final err2 = url!._setFragment(frag);
  if (err2 != null) {
    return (null, Error(op: _gs('parse'), url: rawURL, err: err2));
  }
  return (url, null);
}

/// `ParseRequestURI(rawURL)`: URL absoluta ou caminho absoluto, sem
/// fragmento (como numa requisição HTTP).
(URL?, GoError?) parseRequestURI(Golang.String rawURL) {
  final (url, err) = _parse(rawURL, true);
  if (err != null) {
    return (null, Error(op: _gs('parse'), url: rawURL, err: err));
  }
  return (url, null);
}

(URL?, GoError?) _parse(Golang.String rawURL, bool viaRequest) {
  if (_stringContainsCTLByte(rawURL)) {
    return (null, _errNew('net/url: invalid control character in URL'));
  }
  if (rawURL.length == 0 && viaRequest) return (null, _errNew('empty url'));
  final url = URL();
  if (rawURL == _gs('*')) {
    url.path = _gs('*');
    return (url, null);
  }
  final (scheme, rest0, err) = _getScheme(rawURL);
  if (err != null) return (null, err);
  var rest = rest0;
  url.scheme = strings.toLower(scheme);
  final q = _gs('?');
  if (strings.hasSuffix(rest, q) && strings.count(rest, q) == Golang.Int(1)) {
    url.forceQuery = true;
    rest = rest.slice(0, rest.length - 1);
  } else {
    final (r, query, _) = strings.cut(rest, q);
    rest = r;
    url.rawQuery = query;
  }
  final slash = _gs('/');
  if (!strings.hasPrefix(rest, slash)) {
    if (url.scheme.length != 0) {
      url.opaque = rest;
      return (url, null);
    }
    if (viaRequest) return (null, _errNew('invalid URI for request'));
    final (segment, _, _) = strings.cut(rest, slash);
    if (strings.contains(segment, _gs(':'))) {
      return (null, _errNew('first path segment in URL cannot contain colon'));
    }
  }
  if ((url.scheme.length != 0 ||
          !viaRequest && !strings.hasPrefix(rest, _gs('///'))) &&
      strings.hasPrefix(rest, _gs('//'))) {
    var authority = rest.slice(2);
    rest = Golang.String();
    final i = strings.index(authority, slash).toInt();
    if (i >= 0) {
      rest = authority.slice(i);
      authority = authority.slice(0, i);
    }
    final (user, host, err) = _parseAuthority(url.scheme, authority);
    if (err != null) return (null, err);
    url.user = user;
    url.host = host;
  } else if (url.scheme.length != 0 && strings.hasPrefix(rest, slash)) {
    url.omitHost = true;
  }
  final err2 = url._setPath(rest);
  if (err2 != null) return (null, err2);
  return (url, null);
}

(Userinfo?, Golang.String, GoError?) _parseAuthority(
  Golang.String scheme,
  Golang.String authority,
) {
  final i = strings.lastIndex(authority, _gs('@')).toInt();
  final (host, err) = _parseHost(
    scheme,
    i < 0 ? authority : authority.slice(i + 1),
  );
  if (err != null) return (null, Golang.String(), err);
  if (i < 0) return (null, host, null);
  var userinfo = authority.slice(0, i);
  if (!_validUserinfo(userinfo)) {
    return (null, Golang.String(), _errNew('net/url: invalid userinfo'));
  }
  final Userinfo user;
  if (!strings.contains(userinfo, _gs(':'))) {
    final (ui, err) = _unescape(userinfo, _encodeUserPassword);
    if (err != null) return (null, Golang.String(), err);
    userinfo = ui;
    user = Userinfo(username: userinfo);
  } else {
    final (username0, password0, _) = strings.cut(userinfo, _gs(':'));
    final (username, err1) = _unescape(username0, _encodeUserPassword);
    if (err1 != null) return (null, Golang.String(), err1);
    final (password, err2) = _unescape(password0, _encodeUserPassword);
    if (err2 != null) return (null, Golang.String(), err2);
    user = userPassword(username, password);
  }
  return (user, host, null);
}

(Golang.String, GoError?) _parseHost(Golang.String scheme, Golang.String host) {
  final openBracketIdx = strings.lastIndex(host, _gs('[')).toInt();
  if (openBracketIdx > 0) {
    return (Golang.String(), _errNew('invalid IP-literal'));
  } else if (openBracketIdx == 0) {
    final closeBracketIdx = strings.lastIndex(host, _gs(']')).toInt();
    if (closeBracketIdx < 0) {
      return (Golang.String(), _errNew("missing ']' in host"));
    }
    final colonPort = host.slice(closeBracketIdx + 1);
    if (!_validOptionalPort(colonPort)) {
      return (
        Golang.String(),
        fmt.errorf(
          _gs('invalid port %q after host'),
          Slice.of([colonPort], _anyElem),
        ),
      );
    }
    final (unescapedColonPort, err) = _unescape(colonPort, _encodeHost);
    if (err != null) return (Golang.String(), err);
    final hostname = host.slice(openBracketIdx + 1, closeBracketIdx);
    Golang.String unescapedHostname;
    final zoneIdx = strings.index(hostname, _gs('%25')).toInt();
    if (zoneIdx >= 0) {
      final (hostPart, err1) = _unescape(
        hostname.slice(0, zoneIdx),
        _encodeHost,
      );
      if (err1 != null) return (Golang.String(), err1);
      final (zonePart, err2) = _unescape(hostname.slice(zoneIdx), _encodeZone);
      if (err2 != null) return (Golang.String(), err2);
      unescapedHostname = hostPart + zonePart;
    } else {
      final (h, err1) = _unescape(hostname, _encodeHost);
      if (err1 != null) return (Golang.String(), err1);
      unescapedHostname = h;
    }
    final (addr, err3) = netip.parseAddr(unescapedHostname);
    if (err3 != null) {
      return (
        Golang.String(),
        fmt.errorf(_gs('invalid host: %w'), Slice.of([err3], _anyElem)),
      );
    }
    if (addr.is4()) return (Golang.String(), _errNew('invalid IP-literal'));
    return (_gs('[') + unescapedHostname + _gs(']') + unescapedColonPort, null);
  } else {
    var i = strings.index(host, _gs(':')).toInt();
    if (i != -1) {
      final lastColon = strings.lastIndex(host, _gs(':')).toInt();
      // urlstrictcolons=1 (padrão do Go 1.26): só fora de http(s) a porta
      // vem do último `:`.
      if (lastColon != i && scheme != _gs('http') && scheme != _gs('https')) {
        i = lastColon;
      }
      final colonPort = host.slice(i);
      if (!_validOptionalPort(colonPort)) {
        return (
          Golang.String(),
          fmt.errorf(
            _gs('invalid port %q after host'),
            Slice.of([colonPort], _anyElem),
          ),
        );
      }
    }
  }
  return _unescape(host, _encodeHost);
}

bool _validOptionalPort(Golang.String port) {
  if (port.length == 0) return true;
  if (port[0] != 0x3a) return false;
  // `range` sobre runas: byte inválido vira U+FFFD, que não é dígito.
  for (var i = 1; i < port.length; i++) {
    final b = port[i];
    if (b < 0x30 || b > 0x39) return false;
  }
  return true;
}

/// `resolvePath(base, ref)`: junta e resolve `.`/`..` (RFC 3986 § 5.2.4).
Golang.String _resolvePath(Golang.String base, Golang.String ref) {
  Golang.String full;
  if (ref.length == 0) {
    full = base;
  } else if (ref[0] != 0x2f) {
    final i = strings.lastIndex(base, _gs('/')).toInt();
    full = base.slice(0, i + 1) + ref;
  } else {
    full = ref;
  }
  if (full.length == 0) return Golang.String();
  final dot = _gs('.'), dotdot = _gs('..'), slash = _gs('/');
  var elem = Golang.String();
  final dst = <int>[0x2f];
  var first = true;
  var remaining = full;
  var found = true;
  while (found) {
    final (e, r, f) = strings.cut(remaining, slash);
    elem = e;
    remaining = r;
    found = f;
    if (elem == dot) {
      first = false;
      continue;
    }
    if (elem == dotdot) {
      final str = dst.sublist(1);
      final index = str.lastIndexOf(0x2f);
      dst
        ..clear()
        ..add(0x2f);
      if (index == -1) {
        first = true;
      } else {
        dst.addAll(str.sublist(0, index));
      }
    } else {
      if (!first) dst.add(0x2f);
      dst.addAll(elem.toBytes());
      first = false;
    }
  }
  if (elem == dot || elem == dotdot) dst.add(0x2f);
  var r = Golang.String.fromBytes(Uint8List.fromList(dst));
  if (r.length > 1 && r[1] == 0x2f) r = r.slice(1);
  return r;
}

/// `splitHostPort(hostPort)`: separa a porta (só dígitos) e tira colchetes.
(Golang.String, Golang.String) _splitHostPort(Golang.String hostPort) {
  var host = hostPort, port = Golang.String();
  final colon = strings.lastIndexByte(host, Golang.Uint8(0x3a)).toInt();
  if (colon != -1 && _validOptionalPort(host.slice(colon))) {
    port = host.slice(colon + 1);
    host = host.slice(0, colon);
  }
  if (strings.hasPrefix(host, _gs('[')) && strings.hasSuffix(host, _gs(']'))) {
    host = host.slice(1, host.length - 1);
  }
  return (host, port);
}

/// `validUserinfo(s)`: só os caracteres do RFC 3986 (mais `@`, aceito por
/// compatibilidade), por runa.
bool _validUserinfo(Golang.String s) {
  const allowed = "-._:~!\$&'()*+,;=%@";
  for (final r in s.runes()) {
    if (0x41 <= r && r <= 0x5a || 0x61 <= r && r <= 0x7a) continue;
    if (0x30 <= r && r <= 0x39) continue;
    if (allowed.codeUnits.contains(r)) continue;
    return false;
  }
  return true;
}

bool _stringContainsCTLByte(Golang.String s) {
  for (var i = 0; i < s.length; i++) {
    final b = s[i];
    if (b < 0x20 || b == 0x7f) return true;
  }
  return false;
}

/// `JoinPath(base, elem...)`: base analisada com os elementos juntados.
(Golang.String, GoError?) joinPath(
  Golang.String base,
  Slice<Golang.String> elem,
) {
  final (url, err) = parse(base);
  if (err != null) return (Golang.String(), err);
  final (res, err2) = url!._joinPath(elem);
  if (err2 != null) return (Golang.String(), err2);
  return (res.string(), null);
}
