/// Shim do pacote Go `path` (porta de `path/path.go` e `path/match.go` do
/// Go 1.26.5). Tudo sobre os bytes da string, como no Go.
// ignore_for_file: library_prefixes
library;

import 'dart:typed_data';

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;

const _slash = 0x2f, _dot = 0x2e;

Golang.String _gs(String s) => Golang.String.fromDart(s);

int _lastSlash(Golang.String s) {
  for (var i = s.length - 1; i >= 0; i--) {
    if (s[i] == _slash) return i;
  }
  return -1;
}

/// `lazybuf`: só copia quando a saída diverge da entrada.
final class _LazyBuf {
  _LazyBuf(this.s);
  final Golang.String s;
  Uint8List? buf;
  int w = 0;

  int index(int i) => buf != null ? buf![i] : s[i];

  void append(int c) {
    if (buf == null) {
      if (w < s.length && s[w] == c) {
        w++;
        return;
      }
      buf = Uint8List(s.length)..setRange(0, w, s.toBytes());
    }
    buf![w++] = c;
  }

  Golang.String string() => buf == null
      ? s.slice(0, w)
      : Golang.String.fromBytes(Uint8List.sublistView(buf!, 0, w));
}

/// `path.Clean(path)`: o menor caminho equivalente por processamento léxico.
Golang.String clean(Golang.String path) {
  if (path.length == 0) return _gs('.');
  final rooted = path[0] == _slash;
  final n = path.length;
  final out = _LazyBuf(path);
  var r = 0, dotdot = 0;
  if (rooted) {
    out.append(_slash);
    r = dotdot = 1;
  }
  while (r < n) {
    if (path[r] == _slash) {
      r++;
    } else if (path[r] == _dot && (r + 1 == n || path[r + 1] == _slash)) {
      r++;
    } else if (path[r] == _dot &&
        path[r + 1] == _dot &&
        (r + 2 == n || path[r + 2] == _slash)) {
      r += 2;
      if (out.w > dotdot) {
        out.w--;
        while (out.w > dotdot && out.index(out.w) != _slash) {
          out.w--;
        }
      } else if (!rooted) {
        if (out.w > 0) out.append(_slash);
        out
          ..append(_dot)
          ..append(_dot);
        dotdot = out.w;
      }
    } else {
      if (rooted && out.w != 1 || !rooted && out.w != 0) out.append(_slash);
      for (; r < n && path[r] != _slash; r++) {
        out.append(path[r]);
      }
    }
  }
  if (out.w == 0) return _gs('.');
  return out.string();
}

/// `path.Split(path)`: (dir, file) após a última barra.
(Golang.String, Golang.String) split(Golang.String path) {
  final i = _lastSlash(path);
  return (path.slice(0, i + 1), path.slice(i + 1));
}

/// `path.Join(elem...)`: junta com `/` os não vazios e limpa.
Golang.String join(Slice<Golang.String> elem) {
  var size = 0;
  for (final e in elem.items) {
    size += e.length;
  }
  if (size == 0) return Golang.String();
  final buf = BytesBuilder(copy: false);
  for (final e in elem.items) {
    if (buf.length > 0 || e.length != 0) {
      if (buf.length > 0) buf.addByte(_slash);
      buf.add(e.toBytes());
    }
  }
  return clean(Golang.String.fromBytes(buf.takeBytes()));
}

/// `path.Ext(path)`: extensão (do último `.` do último elemento), ou "".
Golang.String ext(Golang.String path) {
  for (var i = path.length - 1; i >= 0 && path[i] != _slash; i--) {
    if (path[i] == _dot) return path.slice(i);
  }
  return Golang.String();
}

/// `path.Base(path)`: último elemento.
Golang.String base(Golang.String path) {
  if (path.length == 0) return _gs('.');
  var end = path.length;
  while (end > 0 && path[end - 1] == _slash) {
    end--;
  }
  path = path.slice(0, end);
  final i = _lastSlash(path);
  if (i >= 0) path = path.slice(i + 1);
  if (path.length == 0) return _gs('/');
  return path;
}

/// `path.IsAbs(path)`.
bool isAbs(Golang.String path) => path.length > 0 && path[0] == _slash;

/// `path.Dir(path)`: tudo menos o último elemento, limpo.
Golang.String dir(Golang.String path) => clean(split(path).$1);

/// `path.ErrBadPattern`.
final GoError errBadPattern = ErrorString(_gs('syntax error in pattern'));

/// `path.Match(pattern, name)`.
(bool, GoError?) match(Golang.String pattern, Golang.String name) {
  pattern:
  while (pattern.length > 0) {
    final (star, chunk, rest) = _scanChunk(pattern);
    pattern = rest;
    if (star && chunk.length == 0) {
      return (_lastSlash(name) < 0, null);
    }
    final (t, ok, err) = _matchChunk(chunk, name);
    if (ok && (t.length == 0 || pattern.length > 0)) {
      name = t;
      continue;
    }
    if (err != null) return (false, err);
    if (star) {
      for (var i = 0; i < name.length && name[i] != _slash; i++) {
        final (t, ok, err) = _matchChunk(chunk, name.slice(i + 1));
        if (ok) {
          if (pattern.length == 0 && t.length > 0) continue;
          name = t;
          continue pattern;
        }
        if (err != null) return (false, err);
      }
    }
    // Valida o resto do padrão antes de dizer que não casa.
    while (pattern.length > 0) {
      final (_, chunk, rest) = _scanChunk(pattern);
      pattern = rest;
      final (_, _, err) = _matchChunk(chunk, Golang.String());
      if (err != null) return (false, err);
    }
    return (false, null);
  }
  return (name.length == 0, null);
}

(bool, Golang.String, Golang.String) _scanChunk(Golang.String pattern) {
  var star = false;
  while (pattern.length > 0 && pattern[0] == 0x2a) {
    pattern = pattern.slice(1);
    star = true;
  }
  var inrange = false;
  for (var i = 0; i < pattern.length; i++) {
    switch (pattern[i]) {
      case 0x5c: // '\\'
        if (i + 1 < pattern.length) i++;
      case 0x5b: // '['
        inrange = true;
      case 0x5d: // ']'
        inrange = false;
      case 0x2a: // '*'
        if (!inrange) return (star, pattern.slice(0, i), pattern.slice(i));
    }
  }
  return (star, pattern, Golang.String());
}

int _decode(Golang.String s) => s.length == 0 ? 0 : s.decodeRune(0).$2;

(Golang.String, bool, GoError?) _matchChunk(
  Golang.String chunk,
  Golang.String s,
) {
  var failed = false;
  while (chunk.length > 0) {
    failed = failed || s.length == 0;
    switch (chunk[0]) {
      case 0x5b: // '['
        var r = 0;
        if (!failed) {
          final (c, n) = s.decodeRune(0);
          r = c;
          s = s.slice(n);
        }
        chunk = chunk.slice(1);
        var negated = false;
        if (chunk.length > 0 && chunk[0] == 0x5e) {
          negated = true;
          chunk = chunk.slice(1);
        }
        var match = false;
        var nrange = 0;
        for (;;) {
          if (chunk.length > 0 && chunk[0] == 0x5d && nrange > 0) {
            chunk = chunk.slice(1);
            break;
          }
          final (lo, c1, e1) = _getEsc(chunk);
          if (e1 != null) return (Golang.String(), false, e1);
          chunk = c1;
          var hi = lo;
          if (chunk[0] == 0x2d) {
            final (h, c2, e2) = _getEsc(chunk.slice(1));
            if (e2 != null) return (Golang.String(), false, e2);
            hi = h;
            chunk = c2;
          }
          match = match || lo <= r && r <= hi;
          nrange++;
        }
        failed = failed || match == negated;
      case 0x3f: // '?'
        if (!failed) {
          failed = s[0] == _slash;
          s = s.slice(_decode(s));
        }
        chunk = chunk.slice(1);
      default:
        if (chunk[0] == 0x5c) {
          chunk = chunk.slice(1);
          if (chunk.length == 0) return (Golang.String(), false, errBadPattern);
        }
        if (!failed) {
          failed = chunk[0] != s[0];
          s = s.slice(1);
        }
        chunk = chunk.slice(1);
    }
  }
  if (failed) return (Golang.String(), false, null);
  return (s, true, null);
}

(int, Golang.String, GoError?) _getEsc(Golang.String chunk) {
  if (chunk.length == 0 || chunk[0] == 0x2d || chunk[0] == 0x5d) {
    return (0, chunk, errBadPattern);
  }
  if (chunk[0] == 0x5c) {
    chunk = chunk.slice(1);
    if (chunk.length == 0) return (0, chunk, errBadPattern);
  }
  final (r, n) = chunk.decodeRune(0);
  GoError? err;
  if (r == 0xfffd && n == 1) err = errBadPattern;
  final nchunk = chunk.slice(n);
  if (nchunk.length == 0) err = errBadPattern;
  return (r, nchunk, err);
}
