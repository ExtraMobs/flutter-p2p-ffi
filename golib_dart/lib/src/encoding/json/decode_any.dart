part of '../../../encoding/json.dart';

// `decode.go` (interfaces): a decodificação para `any` (`map[string]any`,
// `[]any`, float64/`Number`, string, bool, nil).

extension _AnyValues on _DecodeState {
  /// `valueInterface`.
  Object? valueInterface() {
    Object? val;
    switch (opcode) {
      case _scanBeginArray:
        val = arrayInterface();
        scanNext();
      case _scanBeginObject:
        val = objectInterface();
        scanNext();
      case _scanBeginLiteral:
        val = literalInterface();
      default:
        _phasePanic();
    }
    return val;
  }

  /// `arrayInterface`: `[]any`.
  Slice<Object?> arrayInterface() {
    final items = <Object?>[];
    for (;;) {
      scanWhile(_scanSkipSpace);
      if (opcode == _scanEndArray) break;
      items.add(valueInterface());
      if (opcode == _scanSkipSpace) scanWhile(_scanSkipSpace);
      if (opcode == _scanEndArray) break;
      if (opcode != _scanArrayValue) _phasePanic();
    }
    // `make([]any, 0)` e `append` um a um: o cap do Go.
    return rtAny.$makeSlice(0, 0).append(items);
  }

  /// `objectInterface`: `map[string]any`.
  GoMap<Golang.String, Object?> objectInterface() {
    final m = rtString.$makeMapOf<Object?>(rtAny);
    for (;;) {
      scanWhile(_scanSkipSpace);
      if (opcode == _scanEndObject) break;
      if (opcode != _scanBeginLiteral) _phasePanic();

      final start = readIndex();
      rescanLiteral();
      final item = Uint8List.sublistView(data, start, readIndex());
      final key = _unquoteBytes(item) ?? _phasePanic();

      if (opcode == _scanSkipSpace) scanWhile(_scanSkipSpace);
      if (opcode != _scanObjectKey) _phasePanic();
      scanWhile(_scanSkipSpace);

      m[_gsb(key)] = valueInterface();

      if (opcode == _scanSkipSpace) scanWhile(_scanSkipSpace);
      if (opcode == _scanEndObject) break;
      if (opcode != _scanObjectValue) _phasePanic();
    }
    return m;
  }

  /// `literalInterface`.
  Object? literalInterface() {
    final start = readIndex();
    rescanLiteral();
    final item = Uint8List.sublistView(data, start, readIndex());
    final c = item[0];
    switch (c) {
      case 0x6e:
        return null;
      case 0x74 || 0x66:
        return c == 0x74;
      case 0x22:
        final s = _unquoteBytes(item) ?? _phasePanic();
        return _gsb(s);
    }
    if (c != 0x2d && (c < 0x30 || c > 0x39)) _phasePanic();
    final (n, err) = convertNumber(_gsb(item));
    if (err != null) saveError(err);
    return n;
  }
}
