part of '../../fmt.dart';

/// O `fmt` do Go (`fmt/format.go`): flags, largura e precisão do verbo
/// corrente e a formatação de inteiros, floats e strings com padding,
/// escrita no buffer do [_Printer] dono dele.
final class _Fmt {
  _Fmt(this._b);

  final BytesBuilder _b;

  bool minus = false, plus = false, sharp = false, space = false, zero = false;
  bool plusV = false, sharpV = false;
  int wid = 0, prec = 0;
  bool widPresent = false, precPresent = false;

  void clearFlags() {
    minus = plus = sharp = space = zero = false;
    plusV = sharpV = false;
    wid = prec = 0;
    widPresent = precPresent = false;
  }

  // -------------------------------------------------------------- padding
  void writePadding(int n) {
    if (n <= 0) return;
    _b.add(List.filled(n, zero && !minus ? 0x30 : 0x20));
  }

  /// Largura em runas, à esquerda (ou à direita com `-`).
  void pad(List<int> s) {
    if (!widPresent || wid == 0) {
      _b.add(s);
      return;
    }
    final width = wid - runeCount(s);
    if (!minus) {
      writePadding(width);
      _b.add(s);
    } else {
      _b.add(s);
      writePadding(width);
    }
  }

  // -------------------------------------------------------------- inteiros
  void fmtInteger(BigInt v, int base, int verb, String digitSet) {
    final negative = v.isNegative;
    final u = v.abs();
    var p = 0;
    if (precPresent) {
      p = prec;
      if (p == 0 && u == BigInt.zero) {
        final oldZero = zero;
        zero = false;
        writePadding(wid);
        zero = oldZero;
        return;
      }
    } else if (zero && !minus && widPresent) {
      p = wid;
      if (negative || plus || space) p--;
    }
    var digits = u.toRadixString(base);
    if (identical(digitSet, _hexUpper)) digits = digits.toUpperCase();
    if (digits.length < p) digits = '0' * (p - digits.length) + digits;
    if (sharp) {
      switch (base) {
        case 2:
          digits = '0b$digits';
        case 8:
          if (!digits.startsWith('0')) digits = '0$digits';
        case 16:
          digits = '0${identical(digitSet, _hexUpper) ? 'X' : 'x'}$digits';
      }
    }
    if (verb == 0x4f) digits = '0o$digits';
    if (negative) {
      digits = '-$digits';
    } else if (plus) {
      digits = '+$digits';
    } else if (space) {
      digits = ' $digits';
    }
    final oldZero = zero;
    zero = false;
    pad(_ascii(digits));
    zero = oldZero;
  }

  void fmtUnicode(BigInt v) {
    var hex = v.toUnsigned(64).toRadixString(16).toUpperCase();
    final p = precPresent && prec > 4 ? prec : 4;
    if (hex.length < p) hex = '0' * (p - hex.length) + hex;
    var s = 'U+$hex';
    if (sharp && !v.isNegative && v <= BigInt.from(0x10ffff)) {
      final r = v.toInt();
      if (isPrint(r)) s = "$s '${String.fromCharCode(r)}'";
    }
    final oldZero = zero;
    zero = false;
    pad(utf8.encode(s));
    zero = oldZero;
  }

  // -------------------------------------------------------------- floats
  void fmtFloat(double v, int bits, String fmt, int p) {
    if (precPresent) p = prec;
    final s = formatGoFloatFmt(v, fmt, p, bits);
    var num = s.startsWith('-') || s.startsWith('+') ? s : '+$s';
    if (space && num[0] == '+' && !plus) num = ' ${num.substring(1)}';
    if (num[1] == 'I' || num[1] == 'N') {
      final oldZero = zero;
      zero = false;
      if (num[1] == 'N' && !space && !plus) num = num.substring(1);
      pad(_ascii(num));
      zero = oldZero;
      return;
    }
    if (sharp && fmt != 'b') num = _sharpFloat(num, fmt, p);
    if (plus || num[0] != '+') {
      if (zero && !minus && widPresent && wid > num.length) {
        _b.addByte(num.codeUnitAt(0));
        writePadding(wid - num.length);
        _b.add(_ascii(num.substring(1)));
        return;
      }
      pad(_ascii(num));
      return;
    }
    pad(_ascii(num.substring(1)));
  }

  /// `#` em float (`fmt.fmtFloat` do Go): sempre com ponto decimal e, em
  /// `g`/`G`/`x`, zeros até [prec] dígitos significativos (6 sem precisão).
  /// `num` tem o sinal em `num[0]`.
  static String _sharpFloat(String num, String verb, int prec) {
    final hex = verb == 'x' || verb == 'X';
    var digits = verb == 'g' || verb == 'G' || hex ? (prec < 0 ? 6 : prec) : 0;
    var head = num, tail = '';
    var hasDecimalPoint = false, sawNonzeroDigit = false;
    for (var i = 1; i < num.length; i++) {
      final c = num[i];
      if (c == '.') {
        hasDecimalPoint = true;
      } else if (c == 'p' || c == 'P' || (!hex && (c == 'e' || c == 'E'))) {
        head = num.substring(0, i);
        tail = num.substring(i);
        break;
      } else {
        if (c != '0') sawNonzeroDigit = true;
        if (sawNonzeroDigit) digits--;
      }
    }
    if (!hasDecimalPoint) {
      if (head.length == 2 && head[1] == '0') digits--; // o 0 conta uma vez
      head += '.';
    }
    if (digits > 0) head += '0' * digits;
    return head + tail;
  }

  // -------------------------------------------------------------- strings
  /// Precisão em runas.
  List<int> truncate(Uint8List s) {
    if (!precPresent) return s;
    var n = prec;
    for (var i = 0; i < s.length; i += decodeRune(s, i).$2) {
      if (n-- <= 0) return Uint8List.sublistView(s, 0, i);
    }
    return s;
  }

  void fmtSbx(Uint8List s, String digits) {
    var length = s.length;
    if (precPresent && prec < length) length = prec;
    var width = 2 * length;
    if (width > 0) {
      if (space) {
        if (sharp) width *= 2;
        width += length - 1;
      } else if (sharp) {
        width += 2;
      }
    } else {
      if (widPresent) writePadding(wid);
      return;
    }
    if (widPresent && wid > width && !minus) writePadding(wid - width);
    final x = identical(digits, _hexUpper) ? 0x58 : 0x78;
    if (sharp) _b.add([0x30, x]);
    for (var i = 0; i < length; i++) {
      if (space && i > 0) {
        _b.addByte(0x20);
        if (sharp) _b.add([0x30, x]);
      }
      _b.add([digits.codeUnitAt(s[i] >> 4), digits.codeUnitAt(s[i] & 0xf)]);
    }
    if (widPresent && wid > width && minus) writePadding(wid - width);
  }
}
