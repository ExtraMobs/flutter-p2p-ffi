part of '../../../encoding/json.dart';

// Porta de `scanner.go`: a máquina de estados byte a byte do Go (os mesmos
// opcodes, a mesma profundidade máxima e as mesmas mensagens de erro).

/// `checkValid`: o JSON inteiro é válido? Devolve o `*SyntaxError`.
GoError? _checkValid(List<int> data, _Scanner scan) {
  scan.reset();
  for (final c in data) {
    scan.bytes++;
    if (scan.step(scan, c) == _scanError) return scan.err;
  }
  if (scan.eof() == _scanError) return scan.err;
  return null;
}

typedef _Step = int Function(_Scanner s, int c);

const _scanContinue = 0,
    _scanBeginLiteral = 1,
    _scanBeginObject = 2,
    _scanObjectKey = 3,
    _scanObjectValue = 4,
    _scanEndObject = 5,
    _scanBeginArray = 6,
    _scanArrayValue = 7,
    _scanEndArray = 8,
    _scanSkipSpace = 9,
    _scanEnd = 10,
    _scanError = 11;

const _parseObjectKey = 0, _parseObjectValue = 1, _parseArrayValue = 2;

const _maxNestingDepth = 10000;

/// `scanner`.
final class _Scanner {
  _Step step = _stateBeginValue;
  bool endTop = false;
  final List<int> parseState = [];
  GoError? err;
  int bytes = 0;

  void reset() {
    step = _stateBeginValue;
    parseState.clear();
    err = null;
    endTop = false;
  }

  int eof() {
    if (err != null) return _scanError;
    if (endTop) return _scanEnd;
    step(this, 0x20);
    if (endTop) return _scanEnd;
    err ??= SyntaxError._('unexpected end of JSON input', bytes);
    return _scanError;
  }

  int pushParseState(int c, int newParseState, int successState) {
    parseState.add(newParseState);
    if (parseState.length <= _maxNestingDepth) return successState;
    return error(c, 'exceeded max depth');
  }

  void popParseState() {
    parseState.removeLast();
    if (parseState.isEmpty) {
      step = _stateEndTop;
      endTop = true;
    } else {
      step = _stateEndValue;
    }
  }

  int error(int c, String context) {
    step = _stateError;
    err = SyntaxError._('invalid character ${_quoteChar(c)} $context', bytes);
    return _scanError;
  }
}

bool _isSpace(int c) =>
    c <= 0x20 && (c == 0x20 || c == 0x09 || c == 0x0d || c == 0x0a);

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

bool _isHex(int c) =>
    _isDigit(c) || (c >= 0x61 && c <= 0x66) || (c >= 0x41 && c <= 0x46);

int _stateBeginValueOrEmpty(_Scanner s, int c) {
  if (_isSpace(c)) return _scanSkipSpace;
  if (c == 0x5d) return _stateEndValue(s, c);
  return _stateBeginValue(s, c);
}

int _stateBeginValue(_Scanner s, int c) {
  if (_isSpace(c)) return _scanSkipSpace;
  switch (c) {
    case 0x7b: // {
      s.step = _stateBeginStringOrEmpty;
      return s.pushParseState(c, _parseObjectKey, _scanBeginObject);
    case 0x5b: // [
      s.step = _stateBeginValueOrEmpty;
      return s.pushParseState(c, _parseArrayValue, _scanBeginArray);
    case 0x22: // "
      s.step = _stateInString;
      return _scanBeginLiteral;
    case 0x2d: // -
      s.step = _stateNeg;
      return _scanBeginLiteral;
    case 0x30: // 0
      s.step = _state0;
      return _scanBeginLiteral;
    case 0x74: // t
      s.step = _stateT;
      return _scanBeginLiteral;
    case 0x66: // f
      s.step = _stateF;
      return _scanBeginLiteral;
    case 0x6e: // n
      s.step = _stateN;
      return _scanBeginLiteral;
  }
  if (c >= 0x31 && c <= 0x39) {
    s.step = _state1;
    return _scanBeginLiteral;
  }
  return s.error(c, 'looking for beginning of value');
}

int _stateBeginStringOrEmpty(_Scanner s, int c) {
  if (_isSpace(c)) return _scanSkipSpace;
  if (c == 0x7d) {
    s.parseState[s.parseState.length - 1] = _parseObjectValue;
    return _stateEndValue(s, c);
  }
  return _stateBeginString(s, c);
}

int _stateBeginString(_Scanner s, int c) {
  if (_isSpace(c)) return _scanSkipSpace;
  if (c == 0x22) {
    s.step = _stateInString;
    return _scanBeginLiteral;
  }
  return s.error(c, 'looking for beginning of object key string');
}

int _stateEndValue(_Scanner s, int c) {
  final n = s.parseState.length;
  if (n == 0) {
    s.step = _stateEndTop;
    s.endTop = true;
    return _stateEndTop(s, c);
  }
  if (_isSpace(c)) {
    s.step = _stateEndValue;
    return _scanSkipSpace;
  }
  switch (s.parseState[n - 1]) {
    case _parseObjectKey:
      if (c == 0x3a) {
        s.parseState[n - 1] = _parseObjectValue;
        s.step = _stateBeginValue;
        return _scanObjectKey;
      }
      return s.error(c, 'after object key');
    case _parseObjectValue:
      if (c == 0x2c) {
        s.parseState[n - 1] = _parseObjectKey;
        s.step = _stateBeginString;
        return _scanObjectValue;
      }
      if (c == 0x7d) {
        s.popParseState();
        return _scanEndObject;
      }
      return s.error(c, 'after object key:value pair');
    case _parseArrayValue:
      if (c == 0x2c) {
        s.step = _stateBeginValue;
        return _scanArrayValue;
      }
      if (c == 0x5d) {
        s.popParseState();
        return _scanEndArray;
      }
      return s.error(c, 'after array element');
  }
  return s.error(c, '');
}

int _stateEndTop(_Scanner s, int c) {
  if (!_isSpace(c)) s.error(c, 'after top-level value');
  return _scanEnd;
}

int _stateInString(_Scanner s, int c) {
  if (c == 0x22) {
    s.step = _stateEndValue;
    return _scanContinue;
  }
  if (c == 0x5c) {
    s.step = _stateInStringEsc;
    return _scanContinue;
  }
  if (c < 0x20) return s.error(c, 'in string literal');
  return _scanContinue;
}

int _stateInStringEsc(_Scanner s, int c) {
  switch (c) {
    case 0x62 || 0x66 || 0x6e || 0x72 || 0x74 || 0x5c || 0x2f || 0x22:
      s.step = _stateInString;
      return _scanContinue;
    case 0x75:
      s.step = _stateInStringEscU;
      return _scanContinue;
  }
  return s.error(c, 'in string escape code');
}

int _escU(_Scanner s, int c, _Step next) {
  if (_isHex(c)) {
    s.step = next;
    return _scanContinue;
  }
  return s.error(c, 'in \\u hexadecimal character escape');
}

int _stateInStringEscU(_Scanner s, int c) => _escU(s, c, _stateInStringEscU1);
int _stateInStringEscU1(_Scanner s, int c) => _escU(s, c, _stateInStringEscU12);
int _stateInStringEscU12(_Scanner s, int c) =>
    _escU(s, c, _stateInStringEscU123);
int _stateInStringEscU123(_Scanner s, int c) => _escU(s, c, _stateInString);

int _stateNeg(_Scanner s, int c) {
  if (c == 0x30) {
    s.step = _state0;
    return _scanContinue;
  }
  if (c >= 0x31 && c <= 0x39) {
    s.step = _state1;
    return _scanContinue;
  }
  return s.error(c, 'in numeric literal');
}

int _state1(_Scanner s, int c) {
  if (_isDigit(c)) {
    s.step = _state1;
    return _scanContinue;
  }
  return _state0(s, c);
}

int _state0(_Scanner s, int c) {
  if (c == 0x2e) {
    s.step = _stateDot;
    return _scanContinue;
  }
  if (c == 0x65 || c == 0x45) {
    s.step = _stateE;
    return _scanContinue;
  }
  return _stateEndValue(s, c);
}

int _stateDot(_Scanner s, int c) {
  if (_isDigit(c)) {
    s.step = _stateDot0;
    return _scanContinue;
  }
  return s.error(c, 'after decimal point in numeric literal');
}

int _stateDot0(_Scanner s, int c) {
  if (_isDigit(c)) return _scanContinue;
  if (c == 0x65 || c == 0x45) {
    s.step = _stateE;
    return _scanContinue;
  }
  return _stateEndValue(s, c);
}

int _stateE(_Scanner s, int c) {
  if (c == 0x2b || c == 0x2d) {
    s.step = _stateESign;
    return _scanContinue;
  }
  return _stateESign(s, c);
}

int _stateESign(_Scanner s, int c) {
  if (_isDigit(c)) {
    s.step = _stateE0;
    return _scanContinue;
  }
  return s.error(c, 'in exponent of numeric literal');
}

int _stateE0(_Scanner s, int c) {
  if (_isDigit(c)) return _scanContinue;
  return _stateEndValue(s, c);
}

/// Um passo de literal (`true`, `false`, `null`): espera [want], senão o
/// erro do Go com o literal e a letra esperada.
int _lit(_Scanner s, int c, int want, _Step next, String lit) {
  if (c == want) {
    s.step = next;
    return _scanContinue;
  }
  return s.error(
    c,
    "in literal $lit (expecting '${String.fromCharCode(want)}')",
  );
}

int _stateT(_Scanner s, int c) => _lit(s, c, 0x72, _stateTr, 'true');
int _stateTr(_Scanner s, int c) => _lit(s, c, 0x75, _stateTru, 'true');
int _stateTru(_Scanner s, int c) => _lit(s, c, 0x65, _stateEndValue, 'true');
int _stateF(_Scanner s, int c) => _lit(s, c, 0x61, _stateFa, 'false');
int _stateFa(_Scanner s, int c) => _lit(s, c, 0x6c, _stateFal, 'false');
int _stateFal(_Scanner s, int c) => _lit(s, c, 0x73, _stateFals, 'false');
int _stateFals(_Scanner s, int c) => _lit(s, c, 0x65, _stateEndValue, 'false');
int _stateN(_Scanner s, int c) => _lit(s, c, 0x75, _stateNu, 'null');
int _stateNu(_Scanner s, int c) => _lit(s, c, 0x6c, _stateNul, 'null');
int _stateNul(_Scanner s, int c) => _lit(s, c, 0x6c, _stateEndValue, 'null');

int _stateError(_Scanner s, int c) => _scanError;

/// `quoteChar`: o byte entre aspas simples, como o Go
/// (`strconv.Quote(string(c))`, isto é, a runa U+00XX).
String _quoteChar(int c) {
  if (c == 0x27) return r"'\''";
  if (c == 0x22) return '\'"\'';
  final s = strconv.quote(Golang.String.fromCodePoint(c)).toString();
  return "'${s.substring(1, s.length - 1)}'";
}
