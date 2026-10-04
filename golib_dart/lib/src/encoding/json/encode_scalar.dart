part of '../../../encoding/json.dart';

// `encode.go` (escalares): bool, inteiros, floats, strings, `Number`,
// interfaces e os tipos sem codificação.

void _mayQuote(_EncodeState e, int opts) {
  if (opts & _optQuoted != 0) e.writeByte(0x22);
}

void _boolEncoder(_EncodeState e, reflect.Value v, int opts) {
  _mayQuote(e, opts);
  e.writeString(v.bool$() ? 'true' : 'false');
  _mayQuote(e, opts);
}

void _intEncoder(_EncodeState e, reflect.Value v, int opts) {
  _mayQuote(e, opts);
  e.buf.addAll(strconv.formatInt(v.int$(), Golang.Int(10)).toBytes());
  _mayQuote(e, opts);
}

void _uintEncoder(_EncodeState e, reflect.Value v, int opts) {
  _mayQuote(e, opts);
  e.buf.addAll(strconv.formatUint(v.uint(), Golang.Int(10)).toBytes());
  _mayQuote(e, opts);
}

final double _f32Small = Golang.Float32(1e-6).toDouble();
final double _f32Big = Golang.Float32(1e21).toDouble();

/// `floatEncoder.encode`: `'f'` entre 1e-6 e 1e21, senão `'e'` com o
/// expoente de dois dígitos encurtado (`1e-07` → `1e-7`), como o ES6.
_EncFn _floatEncoder(int bits) => (e, v, opts) {
  final f = v.float().toDouble();
  if (f.isInfinite || f.isNaN) {
    e.error(
      UnsupportedValueError(
        value: v,
        str: strconv.formatFloat(
          Golang.Float64(f),
          Golang.Uint8(0x67),
          Golang.Int(-1),
          Golang.Int(bits),
        ),
      ),
    );
  }
  _mayQuote(e, opts);
  final abs = f.abs();
  var fmtc = 0x66;
  if (abs != 0) {
    if (bits == 64 && (abs < 1e-6 || abs >= 1e21) ||
        bits == 32 && (abs < _f32Small || abs >= _f32Big)) {
      fmtc = 0x65;
    }
  }
  final b = strconv
      .formatFloat(
        Golang.Float64(f),
        Golang.Uint8(fmtc),
        Golang.Int(-1),
        Golang.Int(bits),
      )
      .toBytes()
      .toList();
  if (fmtc == 0x65) {
    final n = b.length;
    if (n >= 4 && b[n - 4] == 0x65 && b[n - 3] == 0x2d && b[n - 2] == 0x30) {
      b[n - 2] = b[n - 1];
      b.removeLast();
    }
  }
  e.buf.addAll(b);
  _mayQuote(e, opts);
};

final _EncFn _float32Encoder = _floatEncoder(32);
final _EncFn _float64Encoder = _floatEncoder(64);

void _stringEncoder(_EncodeState e, reflect.Value v, int opts) {
  if (identical(v.$t, Number.$rt)) {
    var numStr = v.string().toBytes();
    if (numStr.isEmpty) numStr = Uint8List.fromList([0x30]);
    if (!_isValidNumber(numStr)) {
      e.error(_errorf('json: invalid number literal ${_q(numStr)}'));
    }
    _mayQuote(e, opts);
    e.buf.addAll(numStr);
    _mayQuote(e, opts);
    return;
  }
  final html = opts & _optEscapeHTML != 0;
  if (opts & _optQuoted != 0) {
    final b = <int>[];
    _appendString(b, v.string().toBytes(), html);
    _appendString(e.buf, b, false);
  } else {
    _appendString(e.buf, v.string().toBytes(), html);
  }
}

/// `isValidNumber`: a gramática de número do JSON.
bool _isValidNumber(List<int> s) {
  var i = 0;
  final n = s.length;
  if (n == 0) return false;
  if (s[0] == 0x2d) {
    i++;
    if (i == n) return false;
  }
  if (s[i] == 0x30) {
    i++;
  } else if (s[i] >= 0x31 && s[i] <= 0x39) {
    i++;
    while (i < n && _isDigit(s[i])) {
      i++;
    }
  } else {
    return false;
  }
  if (n - i >= 2 && s[i] == 0x2e && _isDigit(s[i + 1])) {
    i += 2;
    while (i < n && _isDigit(s[i])) {
      i++;
    }
  }
  if (n - i >= 2 && (s[i] == 0x65 || s[i] == 0x45)) {
    i++;
    if (s[i] == 0x2b || s[i] == 0x2d) {
      i++;
      if (i == n) return false;
    }
    while (i < n && _isDigit(s[i])) {
      i++;
    }
  }
  return i == n;
}

void _interfaceEncoder(_EncodeState e, reflect.Value v, int opts) {
  if (v.isNil$()) {
    e.writeString('null');
    return;
  }
  e.reflectValue(v.elem$(), opts);
}

void _unsupportedTypeEncoder(_EncodeState e, reflect.Value v, int opts) =>
    e.error(UnsupportedTypeError(type: v.type()));
