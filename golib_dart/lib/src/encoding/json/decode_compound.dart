part of '../../../encoding/json.dart';

// `decode.go` (compostos): `array` e `object` gravam pelo `reflect` em
// slice, array, map, struct ou interface.

extension _Compound on _DecodeState {
  GoError? array(reflect.Value v) {
    final (u, ut, pv) = _indirect(v, false);
    if (u != null) {
      final start = readIndex();
      skip();
      return u.unmarshalJSON(sub(start, off));
    }
    if (ut != null) {
      saveError(
        UnmarshalTypeError(
          value: _gs('array'),
          type: v.type(),
          offset: Golang.Int64(off),
        ),
      );
      skip();
      return null;
    }
    v = pv;
    final t = v.type()!;
    switch (t.$kind) {
      case reflect.kInterface:
        if (v.numMethod().toInt() == 0) {
          final ai = this.arrayInterface();
          v.set(reflect.valueOf$static(ai, _sliceAnyType));
          return null;
        }
        saveError(
          UnmarshalTypeError(
            value: _gs('array'),
            type: t,
            offset: Golang.Int64(off),
          ),
        );
        skip();
        return null;
      case reflect.kArray || reflect.kSlice:
        _checkWritable(t);
      default:
        saveError(
          UnmarshalTypeError(
            value: _gs('array'),
            type: t,
            offset: Golang.Int64(off),
          ),
        );
        skip();
        return null;
    }

    final isSlice = t.$kind == reflect.kSlice;
    var i = 0;
    for (;;) {
      scanWhile(_scanSkipSpace);
      if (opcode == _scanEndArray) break;

      if (isSlice) {
        if (i >= v.cap().toInt()) _grow1(v);
        if (i >= v.len().toInt()) v.setLen(Golang.Int(i + 1));
      }

      if (i < v.len().toInt()) {
        final err = value(v.index(Golang.Int(i)));
        if (err != null) return err;
      } else {
        final err = value(reflect.Value());
        if (err != null) return err;
      }
      i++;

      if (opcode == _scanSkipSpace) scanWhile(_scanSkipSpace);
      if (opcode == _scanEndArray) break;
      if (opcode != _scanArrayValue) _phasePanic();
    }

    if (i < v.len().toInt()) {
      if (!isSlice) {
        for (; i < v.len().toInt(); i++) {
          v.index(Golang.Int(i)).setZero();
        }
      } else {
        v.setLen(Golang.Int(i));
      }
    }
    if (i == 0 && isSlice) {
      _setEmptySlice(v);
    }
    return null;
  }

  GoError? object(reflect.Value v) {
    final (u, ut, pv) = _indirect(v, false);
    if (u != null) {
      final start = readIndex();
      skip();
      return u.unmarshalJSON(sub(start, off));
    }
    if (ut != null) {
      saveError(
        UnmarshalTypeError(
          value: _gs('object'),
          type: v.type(),
          offset: Golang.Int64(off),
        ),
      );
      skip();
      return null;
    }
    v = pv;
    final t = v.type()!;

    if (t.$kind == reflect.kInterface && v.numMethod().toInt() == 0) {
      final oi = this.objectInterface();
      v.set(reflect.valueOf$static(oi, _mapAnyType));
      return null;
    }

    _StructFields? fields;
    switch (t.$kind) {
      case reflect.kMap:
        final kt = t.$key!;
        switch (kt.$kind) {
          case reflect.kString ||
              reflect.kInt ||
              reflect.kInt8 ||
              reflect.kInt16 ||
              reflect.kInt32 ||
              reflect.kInt64 ||
              reflect.kUint ||
              reflect.kUint8 ||
              reflect.kUint16 ||
              reflect.kUint32 ||
              reflect.kUint64 ||
              reflect.kUintptr:
            break;
          default:
            if (!_implements(kt.ptrTo(), _textUnmarshalerType)) {
              saveError(
                UnmarshalTypeError(
                  value: _gs('object'),
                  type: t,
                  offset: Golang.Int64(off),
                ),
              );
              skip();
              return null;
            }
        }
        _checkWritable(t);
        if (v.isNil$()) _setNewMap(v);
      case reflect.kStruct:
        fields = _cachedTypeFields(t);
      default:
        saveError(
          UnmarshalTypeError(
            value: _gs('object'),
            type: t,
            offset: Golang.Int64(off),
          ),
        );
        skip();
        return null;
    }

    reflect.Value? mapElem;
    final origStruct = errorContext?.struct;
    final origStackLen = errorContext?.fieldStack.length ?? 0;

    for (;;) {
      scanWhile(_scanSkipSpace);
      if (opcode == _scanEndObject) break;
      if (opcode != _scanBeginLiteral) _phasePanic();

      final start = readIndex();
      rescanLiteral();
      final item = Uint8List.sublistView(data, start, readIndex());
      final key = _unquoteBytes(item) ?? _phasePanic();

      var subv = reflect.Value();
      var destring = false;

      if (t.$kind == reflect.kMap) {
        final elemType = t.$elem!;
        if (mapElem == null) {
          mapElem = reflect.new$(elemType).elem$();
        } else {
          mapElem.setZero();
        }
        subv = mapElem;
      } else {
        var f = fields!.byExactName[_key(key)];
        f ??= fields.byFoldedName[_foldName(key)];
        if (f != null) {
          subv = v;
          destring = f.quoted;
          final ec = errorContext ??= _ErrorContext();
          for (var i = 0; i < f.index.length; i++) {
            final ind = f.index[i];
            if (_k(subv) == reflect.kPointer) {
              if (subv.isNil$()) {
                if (!subv.canSet()) {
                  saveError(
                    _errorf(
                      'json: cannot set embedded pointer to unexported struct: '
                      '${subv.type()!.$elem!.$str}',
                    ),
                  );
                  subv = reflect.Value();
                  destring = false;
                  break;
                }
                subv.set(reflect.new$(subv.type()!.$elem));
              }
              subv = subv.elem$();
            }
            if (i < f.index.length - 1) {
              ec.fieldStack.add(subv.type()!.$fields[ind].name);
            }
            subv = subv.field(Golang.Int(ind));
          }
          ec.struct = t;
          ec.fieldStack.add(_gsb(f.name).toString());
        } else if (disallowUnknownFields) {
          saveError(_errorf('json: unknown field ${_q(key)}'));
        }
      }

      if (opcode == _scanSkipSpace) scanWhile(_scanSkipSpace);
      if (opcode != _scanObjectKey) _phasePanic();
      scanWhile(_scanSkipSpace);

      if (destring) {
        final qv = valueQuoted();
        if (qv == null) {
          final err = this.literalStore(_nullLiteral, subv, false);
          if (err != null) return err;
        } else if (qv is Golang.String) {
          final err = this.literalStore(qv.toBytes(), subv, true);
          if (err != null) return err;
        } else {
          saveError(
            _errorf(
              'json: invalid use of ,string struct tag, trying to unmarshal '
              'unquoted value into ${subv.type()!.$str}',
            ),
          );
        }
      } else {
        final err = value(subv);
        if (err != null) return err;
      }

      if (t.$kind == reflect.kMap) {
        final kt = t.$key!;
        reflect.Value? kv;
        if (_implements(kt.ptrTo(), _textUnmarshalerType)) {
          kv = reflect.new$(kt);
          final err = this.literalStore(item, kv, true);
          if (err != null) return err;
          kv = kv.elem$();
        } else {
          switch (kt.$kind) {
            case reflect.kString:
              _checkWritable(kt);
              kv = reflect.new$(kt).elem$();
              kv.setString(_gsb(key));
            case reflect.kInt ||
                reflect.kInt8 ||
                reflect.kInt16 ||
                reflect.kInt32 ||
                reflect.kInt64:
              final s = _gsb(key);
              final (n, err) = strconv.parseInt(
                s,
                Golang.Int(10),
                Golang.Int(64),
              );
              if (err != null || reflect.TypeApi(kt).overflowInt(n)) {
                saveError(
                  UnmarshalTypeError(
                    value: _gs('number ') + s,
                    type: kt,
                    offset: Golang.Int64(start + 1),
                  ),
                );
                break;
              }
              _checkWritable(kt);
              kv = reflect.new$(kt).elem$();
              kv.setInt(n);
            case reflect.kUint ||
                reflect.kUint8 ||
                reflect.kUint16 ||
                reflect.kUint32 ||
                reflect.kUint64 ||
                reflect.kUintptr:
              final s = _gsb(key);
              final (n, err) = strconv.parseUint(
                s,
                Golang.Int(10),
                Golang.Int(64),
              );
              if (err != null || reflect.TypeApi(kt).overflowUint(n)) {
                saveError(
                  UnmarshalTypeError(
                    value: _gs('number ') + s,
                    type: kt,
                    offset: Golang.Int64(start + 1),
                  ),
                );
                break;
              }
              _checkWritable(kt);
              kv = reflect.new$(kt).elem$();
              kv.setUint(n);
            default:
              throw Panic(_gs('json: Unexpected key type'));
          }
        }
        if (kv != null && kv.isValid()) v.setMapIndex(kv, subv);
      }

      if (opcode == _scanSkipSpace) scanWhile(_scanSkipSpace);
      final ec = errorContext;
      if (ec != null) {
        ec.fieldStack.length = origStackLen;
        ec.struct = origStruct;
      }
      if (opcode == _scanEndObject) break;
      if (opcode != _scanObjectValue) _phasePanic();
    }
    return null;
  }
}
