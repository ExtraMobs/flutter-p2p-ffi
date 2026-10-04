part of '../../../encoding/json.dart';

// `decode.go` (literais): `literalStore` grava um literal JSON (com as
// regras de `,string`, `Number`, base64 e `TextUnmarshaler`).

extension _Literals on _DecodeState {
  /// `convertNumber`: float64, ou `Number` com `UseNumber`.
  (Object?, GoError?) convertNumber(Golang.String s) {
    if (useNumber) return (Number(s), null);
    final (f, err) = strconv.parseFloat(s, Golang.Int(64));
    if (err != null) {
      return (
        null,
        UnmarshalTypeError(
          value: _gs('number ') + s,
          type: rtFloat64,
          offset: Golang.Int64(off),
        ),
      );
    }
    return (f, null);
  }

  GoError _badString(Uint8List item, reflect.Value v) => _errorf(
    'json: invalid use of ,string struct tag, trying to unmarshal '
    '${_q(item)} into ${v.type()!.$str}',
  );

  UnmarshalTypeError _typeErr(String what, reflect.Value v, [int? at]) =>
      UnmarshalTypeError(
        value: _gs(what),
        type: v.type(),
        offset: Golang.Int64(at ?? readIndex()),
      );

  /// `literalStore`: grava o literal [item] em [v]; [fromQuoted] é o
  /// conteúdo de uma string de campo `,string`.
  GoError? literalStore(Uint8List item, reflect.Value v, bool fromQuoted) {
    if (item.isEmpty) {
      saveError(_badString(item, v));
      return null;
    }
    final isNull = item[0] == 0x6e;
    final (u, ut, pv) = _indirect(v, isNull);
    if (u != null) return u.unmarshalJSON(_out(item));
    if (ut != null) {
      if (item[0] != 0x22) {
        if (fromQuoted) {
          saveError(_badString(item, v));
          return null;
        }
        var val = 'number';
        switch (item[0]) {
          case 0x6e:
            val = 'null';
          case 0x74 || 0x66:
            val = 'bool';
        }
        saveError(_typeErr(val, v));
        return null;
      }
      final s = _unquoteBytes(item);
      if (s == null) {
        if (fromQuoted) return _badString(item, v);
        _phasePanic();
      }
      return ut.unmarshalText(_out(s));
    }

    v = pv;
    final c = item[0];
    switch (c) {
      case 0x6e: // null
        if (fromQuoted && !_eq(item, 'null')) {
          saveError(_badString(item, v));
          break;
        }
        switch (_k(v)) {
          case reflect.kInterface ||
              reflect.kPointer ||
              reflect.kMap ||
              reflect.kSlice:
            v.setZero();
        }
      case 0x74 || 0x66: // true, false
        final value = item[0] == 0x74;
        if (fromQuoted && !_eq(item, 'true') && !_eq(item, 'false')) {
          saveError(_badString(item, v));
          break;
        }
        switch (_k(v)) {
          case reflect.kBool:
            v.setBool(value);
          case reflect.kInterface:
            if (v.numMethod().toInt() == 0) {
              v.set(reflect.valueOf$static(value, rtBool));
            } else {
              saveError(_typeErr('bool', v));
            }
          default:
            if (fromQuoted) {
              saveError(_badString(item, v));
            } else {
              saveError(_typeErr('bool', v));
            }
        }
      case 0x22: // string
        final s = _unquoteBytes(item);
        if (s == null) {
          if (fromQuoted) return _badString(item, v);
          _phasePanic();
        }
        switch (_k(v)) {
          case reflect.kSlice:
            if (v.type()!.$elem!.$kind != reflect.kUint8) {
              saveError(_typeErr('string', v));
              break;
            }
            final (b, err) = _base64DecodeAll(s);
            if (err != null) {
              saveError(err);
              break;
            }
            v.setBytes(
              Slice<Golang.Uint8>.make(
                (s.length ~/ 4) * 3,
                (s.length ~/ 4) * 3,
                _byteElem,
              ).slice(0, 0).append(_u8(b)),
            );
          case reflect.kString:
            final t = _gsb(s);
            if (identical(v.$t, Number.$rt) && !_isValidNumber(s)) {
              return _errorf(
                'json: invalid number literal, trying to unmarshal '
                '${_q(item)} into Number',
              );
            }
            v.setString(t);
          case reflect.kInterface:
            if (v.numMethod().toInt() == 0) {
              v.set(reflect.valueOf$static(_gsb(s), rtString));
            } else {
              saveError(_typeErr('string', v));
            }
          default:
            saveError(_typeErr('string', v));
        }
      default: // number
        if (c != 0x2d && (c < 0x30 || c > 0x39)) {
          if (fromQuoted) return _badString(item, v);
          _phasePanic();
        }
        final str = _gsb(item);
        switch (_k(v)) {
          case reflect.kInterface:
            final (n, err) = convertNumber(str);
            if (err != null) {
              saveError(err);
              break;
            }
            if (v.numMethod().toInt() != 0) {
              saveError(_typeErr('number', v));
              break;
            }
            v.set(reflect.valueOf(n));
          case reflect.kInt ||
              reflect.kInt8 ||
              reflect.kInt16 ||
              reflect.kInt32 ||
              reflect.kInt64:
            final (n, err) = strconv.parseInt(
              str,
              Golang.Int(10),
              Golang.Int(64),
            );
            if (err != null || reflect.TypeApi(v.type()!).overflowInt(n)) {
              saveError(_typeErr('number ${str.toString()}', v));
              break;
            }
            v.setInt(n);
          case reflect.kUint ||
              reflect.kUint8 ||
              reflect.kUint16 ||
              reflect.kUint32 ||
              reflect.kUint64 ||
              reflect.kUintptr:
            final (n, err) = strconv.parseUint(
              str,
              Golang.Int(10),
              Golang.Int(64),
            );
            if (err != null || reflect.TypeApi(v.type()!).overflowUint(n)) {
              saveError(_typeErr('number ${str.toString()}', v));
              break;
            }
            v.setUint(n);
          case reflect.kFloat32 || reflect.kFloat64:
            final bits = v.type()!.$size * 8;
            final (n, err) = strconv.parseFloat(str, Golang.Int(bits));
            if (err != null || reflect.TypeApi(v.type()!).overflowFloat(n)) {
              saveError(_typeErr('number ${str.toString()}', v));
              break;
            }
            v.setFloat(n);
          default:
            if (_k(v) == reflect.kString && identical(v.$t, Number.$rt)) {
              v.setString(str);
              break;
            }
            if (fromQuoted) return _badString(item, v);
            saveError(_typeErr('number', v));
        }
    }
    return null;
  }
}
