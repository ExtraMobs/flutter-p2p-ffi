part of '../../../encoding/json.dart';

// Porta de `indent.go`: `appendHTMLEscape`, `appendCompact`, `appendIndent`.

const _hex = '0123456789abcdef';

const _indentGrowthFactor = 2;

void _escapeHTMLByte(List<int> dst, int c) {
  dst.addAll([0x5c, 0x75, 0x30, 0x30]);
  dst.add(_hex.codeUnitAt(c >> 4));
  dst.add(_hex.codeUnitAt(c & 0xf));
}

/// U+2028/U+2029 (`E2 80 A8`/`E2 80 A9`) começam em src[i]?
bool _isLineSep(List<int> src, int i) =>
    src[i] == 0xe2 &&
    i + 2 < src.length &&
    src[i + 1] == 0x80 &&
    src[i + 2] & ~1 == 0xa8;

void _escapeLineSep(List<int> dst, int last) {
  dst.addAll([0x5c, 0x75, 0x32, 0x30, 0x32]);
  dst.add(_hex.codeUnitAt(last & 0xf));
}

/// `appendHTMLEscape`: `<`, `>`, `&`, U+2028 e U+2029 viram `\uXXXX`.
void _appendHTMLEscape(List<int> dst, List<int> src) {
  var start = 0;
  for (var i = 0; i < src.length; i++) {
    final c = src[i];
    if (c == 0x3c || c == 0x3e || c == 0x26) {
      dst.addAll(src.sublist(start, i));
      _escapeHTMLByte(dst, c);
      start = i + 1;
    }
    if (_isLineSep(src, i)) {
      dst.addAll(src.sublist(start, i));
      _escapeLineSep(dst, src[i + 2]);
      start = i + 3;
    }
  }
  dst.addAll(src.sublist(start));
}

/// `appendCompact`: tira o espaço insignificante; com [escape], o escape
/// HTML. Erro de sintaxe: [dst] volta ao tamanho original.
GoError? _appendCompact(List<int> dst, List<int> src, bool escape) {
  final origLen = dst.length;
  final scan = _Scanner();
  var start = 0;
  for (var i = 0; i < src.length; i++) {
    final c = src[i];
    if (escape && (c == 0x3c || c == 0x3e || c == 0x26)) {
      if (start < i) dst.addAll(src.sublist(start, i));
      _escapeHTMLByte(dst, c);
      start = i + 1;
    }
    if (escape && _isLineSep(src, i)) {
      if (start < i) dst.addAll(src.sublist(start, i));
      _escapeLineSep(dst, src[i + 2]);
      start = i + 3;
    }
    final v = scan.step(scan, c);
    if (v >= _scanSkipSpace) {
      if (v == _scanError) break;
      if (start < i) dst.addAll(src.sublist(start, i));
      start = i + 1;
    }
  }
  if (scan.eof() == _scanError) {
    dst.length = origLen;
    return scan.err;
  }
  if (start < src.length) dst.addAll(src.sublist(start));
  return null;
}

void _appendNewline(
  List<int> dst,
  List<int> prefix,
  List<int> indent,
  int depth,
) {
  dst.add(0x0a);
  dst.addAll(prefix);
  for (var i = 0; i < depth; i++) {
    dst.addAll(indent);
  }
}

/// `appendIndent`. Erro de sintaxe: [dst] volta ao tamanho original.
GoError? _appendIndent(
  List<int> dst,
  List<int> src,
  List<int> prefix,
  List<int> indent,
) {
  final origLen = dst.length;
  final scan = _Scanner();
  var needIndent = false;
  var depth = 0;
  for (final c in src) {
    scan.bytes++;
    final v = scan.step(scan, c);
    if (v == _scanSkipSpace) continue;
    if (v == _scanError) break;
    if (needIndent && v != _scanEndObject && v != _scanEndArray) {
      needIndent = false;
      depth++;
      _appendNewline(dst, prefix, indent, depth);
    }
    if (v == _scanContinue) {
      dst.add(c);
      continue;
    }
    switch (c) {
      case 0x7b || 0x5b:
        needIndent = true;
        dst.add(c);
      case 0x2c:
        dst.add(c);
        _appendNewline(dst, prefix, indent, depth);
      case 0x3a:
        dst.add(c);
        dst.add(0x20);
      case 0x7d || 0x5d:
        if (needIndent) {
          needIndent = false;
        } else {
          depth--;
          _appendNewline(dst, prefix, indent, depth);
        }
        dst.add(c);
      default:
        dst.add(c);
    }
  }
  if (scan.eof() == _scanError) {
    dst.length = origLen;
    return scan.err;
  }
  return null;
}
