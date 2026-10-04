part of '../../../encoding/json.dart';

// `decode.go` (`indirect`): a descida por ponteiros e interfaces até o
// alvo, e os ajudantes de alocação pelo `reflect`.

/// Tipo de shim sem descritor (`go.rtOpaque`) não pode ser gravado pelo
/// reflect: panic explícito em vez de um erro de tipo do Dart.
void _checkWritable(RType t) {
  if (t.$opaque &&
      t.$kind != reflect.kInterface &&
      t.$kind != reflect.kPointer &&
      !_isRawMessage(t)) {
    throw Panic(
      _gs(
        'json: tipo ${t.$str} sem descritor de reflexão (tipo de shim): '
        'o decode não sabe gravá-lo',
      ),
    );
  }
}

/// Alvo `json.RawMessage` (por descritor) visto como `Unmarshaler`: guarda
/// uma cópia dos bytes (`*m = append((*m)[0:0], data...)`).
final class _RawTarget implements Unmarshaler {
  _RawTarget(this.v);
  final reflect.Value v;

  @override
  GoError? unmarshalJSON(_Bytes data) {
    // O zero do descritor opaco (`reflect.New` do elemento de um map) é null.
    final cur = v.$rep as Slice<Golang.Uint8>? ?? _nilBytes();
    v.set(reflect.valueOf$static(cur.slice(0, 0).appendSlice(data), v.$t!));
    return null;
  }
}

/// O `unquotedValue{}` do Go.
const Object _unquoted = _Unquoted();

final class _Unquoted {
  const _Unquoted();
}

final Uint8List _nullLiteral = Uint8List.fromList('null'.codeUnits);

/// `[]interface {}` e `map[string]interface {}`.
final RType _sliceAnyType = rtAny.sliceOf();
final RType _mapAnyType = rtMap(rtString, rtAny);

/// `Value.Grow(1)` de um slice: o `append` do Go (mesmo crescimento do
/// `cap`), com o comprimento mantido.
void _grow1(reflect.Value v) {
  final t = v.$t!;
  final s = v.$rep as Slice;
  final g = s.elem.$with(
    <E>() => s.append(<E>[s.elem.zero() as E]).slice(0, s.length),
  );
  v.set(reflect.valueOf$static(t.$name.isEmpty ? g : t.$conv!(g), t));
}

/// `v.Set(reflect.MakeSlice(v.Type(), 0, 0))`, com o T reificado do próprio
/// slice (o elemento pode ser de shim sem descritor, como `json.RawMessage`).
void _setEmptySlice(reflect.Value v) {
  final t = v.$t!;
  final s = v.$rep as Slice;
  final e = s.elem.$with(<E>() => Slice<E>.make(0, 0, s.elem as Elem<E>));
  v.set(reflect.valueOf$static(t.$name.isEmpty ? e : t.$conv!(e), t));
}

/// `v.Set(reflect.MakeMap(v.Type()))`, com K e V reificados do map nil.
void _setNewMap(reflect.Value v) {
  final t = v.$t!;
  final m = v.$rep as GoMap;
  final kt = t.$key!;
  final identity = kt.$kind == reflect.kPointer && kt.$elem!.$isValueKind;
  final n = m.$withKV(
    <K, V>() => GoMap<K, V>(
      m.elem as Elem<V>,
      identity: identity,
      key: m.$key as Elem<K>?,
    ),
  );
  v.set(reflect.valueOf$static(t.$name.isEmpty ? n : t.$conv!(n), t));
}

/// `indirect`: desce por ponteiros (alocando os nil) e interfaces até o
/// valor a gravar; para no primeiro `Unmarshaler`/`TextUnmarshaler`. Com
/// [decodingNull], para no último ponteiro gravável (o `null` o zera).
(Unmarshaler?, encoding.TextUnmarshaler?, reflect.Value) _indirect(
  reflect.Value v,
  bool decodingNull,
) {
  final v0 = v;
  var haveAddr = false;

  if (_k(v) != reflect.kPointer && v.type()!.$name.isNotEmpty && v.canAddr()) {
    haveAddr = true;
    v = v.addr$();
  }
  for (;;) {
    if (_k(v) == reflect.kInterface && !v.isNil$()) {
      final e = v.elem$();
      if (_k(e) == reflect.kPointer &&
          !e.isNil$() &&
          (!decodingNull || _k(e.elem$()) == reflect.kPointer)) {
        haveAddr = false;
        v = e;
        continue;
      }
    }

    if (_k(v) != reflect.kPointer) break;

    if (decodingNull && v.canSet()) break;

    final ve = v.elem$();
    if (_k(ve) == reflect.kInterface && ve.elem$().equal(v)) {
      v = ve;
      break;
    }
    if (v.isNil$()) {
      _checkWritable(v.type()!.$elem!);
      v.set(reflect.new$(v.type()!.$elem));
    }

    final pt = v.type()!;
    if (_isRawMessage(pt.$elem!))
      return (_RawTarget(v.elem$()), null, reflect.Value());
    if (reflect.TypeApi(pt).numMethod().toInt() > 0 && v.canInterface()) {
      if (_implements(pt, _unmarshalerType)) {
        final u = _assertIface<Unmarshaler>(v.$iface(), const [
          'UnmarshalJSON',
        ], pt);
        if (u != null) return (u, null, reflect.Value());
      }
      if (!decodingNull && _implements(pt, _textUnmarshalerType)) {
        final u = _assertIface<encoding.TextUnmarshaler>(v.$iface(), const [
          'UnmarshalText',
        ], pt);
        if (u != null) return (null, u, reflect.Value());
      }
    }

    if (haveAddr) {
      v = v0;
      haveAddr = false;
    } else {
      v = v.elem$();
    }
  }
  if (v.isValid()) _checkWritable(v.type()!);
  return (null, null, v);
}
