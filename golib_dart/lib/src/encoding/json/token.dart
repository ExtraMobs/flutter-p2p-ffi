part of '../../../encoding/json.dart';

// A API de tokens do `Decoder` (`stream.go`): `Token`, `More` e a máquina
// de estados que valida a sequência de delimitadores, vírgulas e dois-pontos.

/// `Decoder.Token`/`More` e os auxiliares de estado dos tokens.
extension DecoderTokens on Decoder {
  GoError? _tokenPrepareForDecode() {
    switch (_tokenState) {
      case _tokenArrayComma:
        final (c, err) = _peek();
        if (err != null) return err;
        if (c != 0x2c) {
          return SyntaxError._(
            'expected comma after array element',
            inputOffset().toInt(),
          );
        }
        _scanp++;
        _tokenState = _tokenArrayValue;
      case _tokenObjectColon:
        final (c, err) = _peek();
        if (err != null) return err;
        if (c != 0x3a) {
          return SyntaxError._(
            'expected colon after object key',
            inputOffset().toInt(),
          );
        }
        _scanp++;
        _tokenState = _tokenObjectValue;
    }
    return null;
  }

  bool _tokenValueAllowed() => switch (_tokenState) {
    _tokenTopValue ||
    _tokenArrayStart ||
    _tokenArrayValue ||
    _tokenObjectValue => true,
    _ => false,
  };

  void _tokenValueEnd() {
    switch (_tokenState) {
      case _tokenArrayStart || _tokenArrayValue:
        _tokenState = _tokenArrayComma;
      case _tokenObjectValue:
        _tokenState = _tokenObjectComma;
    }
  }

  /// Abre `[`/`{`.
  (Object?, GoError?) _open(int c, int state) {
    if (!_tokenValueAllowed()) return _tokenError(c);
    _scanp++;
    _tokenStack.add(_tokenState);
    _tokenState = state;
    return (Delim(c), null);
  }

  /// Fecha `]`/`}`.
  (Object?, GoError?) _close(int c, int start, int comma) {
    if (_tokenState != start && _tokenState != comma) return _tokenError(c);
    _scanp++;
    _tokenState = _tokenStack.removeLast();
    _tokenValueEnd();
    return (Delim(c), null);
  }

  /// `Token()`: o próximo token (`Delim`, bool, float64/`Number`, string,
  /// nil); no fim da entrada, `io.EOF`.
  (Object?, GoError?) token() {
    for (;;) {
      final (c, err) = _peek();
      if (err != null) return (null, err);
      switch (c) {
        case 0x5b:
          return _open(c, _tokenArrayStart);
        case 0x5d:
          return _close(c, _tokenArrayStart, _tokenArrayComma);
        case 0x7b:
          return _open(c, _tokenObjectStart);
        case 0x7d:
          return _close(c, _tokenObjectStart, _tokenObjectComma);
        case 0x3a:
          if (_tokenState != _tokenObjectColon) return _tokenError(c);
          _scanp++;
          _tokenState = _tokenObjectValue;
          continue;
        case 0x2c:
          if (_tokenState == _tokenArrayComma) {
            _scanp++;
            _tokenState = _tokenArrayValue;
            continue;
          }
          if (_tokenState == _tokenObjectComma) {
            _scanp++;
            _tokenState = _tokenObjectKey;
            continue;
          }
          return _tokenError(c);
        case 0x22
            when _tokenState == _tokenObjectStart ||
                _tokenState == _tokenObjectKey:
          final x = Box<Golang.String>(Golang.String());
          final old = _tokenState;
          _tokenState = _tokenTopValue;
          final derr = decode(x);
          _tokenState = old;
          if (derr != null) return (null, derr);
          _tokenState = _tokenObjectColon;
          return (x.value, null);
        default:
          if (!_tokenValueAllowed()) return _tokenError(c);
          final x = Box<Object?>(null);
          final derr = decode(x);
          if (derr != null) return (null, derr);
          return (x.value, null);
      }
    }
  }

  (Object?, GoError?) _tokenError(int c) {
    final context = switch (_tokenState) {
      _tokenTopValue ||
      _tokenArrayStart ||
      _tokenArrayValue ||
      _tokenObjectValue => ' looking for beginning of value',
      _tokenArrayComma => ' after array element',
      _tokenObjectKey => ' looking for beginning of object key string',
      _tokenObjectColon => ' after object key',
      _tokenObjectComma => ' after object key:value pair',
      _ => '',
    };
    return (
      null,
      SyntaxError._(
        'invalid character ${_quoteChar(c)}$context',
        inputOffset().toInt(),
      ),
    );
  }

  /// `More()`: há outro elemento no array/objeto atual?
  bool more() {
    final (c, err) = _peek();
    return err == null && c != 0x5d && c != 0x7d;
  }

  /// `peek`: o próximo byte que não é espaço (lendo mais se preciso).
  (int, GoError?) _peek() {
    GoError? err;
    for (;;) {
      for (var i = _scanp; i < _buf.length; i++) {
        final c = _b(i);
        if (_isSpace(c)) continue;
        _scanp = i;
        return (c, null);
      }
      if (err != null) return (0, err);
      err = _refill();
    }
  }
}
