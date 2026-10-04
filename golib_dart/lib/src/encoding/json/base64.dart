part of '../../../encoding/json.dart';

// `base64.StdEncoding` (com padding, não estrito) para os `[]byte`: porta
// de `AppendEncode` e do `decodeQuantum` do Go (pula `\r`/`\n`, mesmas
// posições no `CorruptInputError`).

const _b64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

final List<int> _b64Decode = () {
  final m = List<int>.filled(256, 0xff);
  for (var i = 0; i < _b64.length; i++) {
    m[_b64.codeUnitAt(i)] = i;
  }
  return m;
}();

/// `base64.StdEncoding.AppendEncode(dst, src)`.
void _base64Encode(List<int> dst, List<int> src) {
  var i = 0;
  final n = src.length ~/ 3 * 3;
  for (; i < n; i += 3) {
    final v = (src[i] << 16) | (src[i + 1] << 8) | src[i + 2];
    dst.add(_b64.codeUnitAt(v >> 18 & 0x3f));
    dst.add(_b64.codeUnitAt(v >> 12 & 0x3f));
    dst.add(_b64.codeUnitAt(v >> 6 & 0x3f));
    dst.add(_b64.codeUnitAt(v & 0x3f));
  }
  final rem = src.length - i;
  if (rem == 0) return;
  var v = src[i] << 16;
  if (rem == 2) v |= src[i + 1] << 8;
  dst.add(_b64.codeUnitAt(v >> 18 & 0x3f));
  dst.add(_b64.codeUnitAt(v >> 12 & 0x3f));
  if (rem == 2) {
    dst.add(_b64.codeUnitAt(v >> 6 & 0x3f));
  } else {
    dst.add(0x3d);
  }
  dst.add(0x3d);
}

/// `base64.CorruptInputError`.
final class _CorruptInputError implements GoError, Golang.GoTyped {
  _CorruptInputError(this.offset);
  final int offset;

  @override
  Golang.String error() => _gs('illegal base64 data at input byte $offset');

  @override
  String get $goType => 'base64.CorruptInputError';

  @override
  List<String> get $methods => const ['Error'];
}

/// `base64.StdEncoding.Decode`: os bytes decodificados, ou o erro.
(List<int>, GoError?) _base64DecodeAll(List<int> src) {
  final out = <int>[];
  var si = 0;
  while (si < src.length) {
    final dbuf = [0, 0, 0, 0];
    var dlen = 4;
    GoError? err;
    var j = 0;
    var done = false;
    for (; j < 4; j++) {
      if (src.length == si) {
        if (j == 0) return (out, null);
        // j == 1 ou com padding: falta entrada.
        return (out, _CorruptInputError(si - j));
      }
      final inb = src[si];
      si++;
      final o = _b64Decode[inb];
      if (o != 0xff) {
        dbuf[j] = o;
        continue;
      }
      if (inb == 0x0a || inb == 0x0d) {
        j--;
        continue;
      }
      if (inb != 0x3d) return (out, _CorruptInputError(si - 1));
      // Padding: fim dos dados.
      switch (j) {
        case 0 || 1:
          return (out, _CorruptInputError(si - 1));
        case 2:
          while (si < src.length && (src[si] == 0x0a || src[si] == 0x0d)) {
            si++;
          }
          if (si == src.length) return (out, _CorruptInputError(src.length));
          if (src[si] != 0x3d) return (out, _CorruptInputError(si - 1));
          si++;
      }
      while (si < src.length && (src[si] == 0x0a || src[si] == 0x0d)) {
        si++;
      }
      if (si < src.length) err = _CorruptInputError(si);
      dlen = j;
      done = true;
      break;
    }
    final val = dbuf[0] << 18 | dbuf[1] << 12 | dbuf[2] << 6 | dbuf[3];
    final b0 = val >> 16 & 0xff, b1 = val >> 8 & 0xff, b2 = val & 0xff;
    switch (dlen) {
      case 4:
        out.addAll([b0, b1, b2]);
      case 3:
        out.addAll([b0, b1]);
      case 2:
        out.add(b0);
    }
    if (err != null) return (out, err);
    if (done) break;
  }
  return (out, null);
}
