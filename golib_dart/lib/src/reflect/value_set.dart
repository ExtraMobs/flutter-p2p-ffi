part of '../../reflect.dart';

/// Escrita, endereço e conversão de `reflect.Value`.
extension ValueSet on Value {
  void _mustBeAssignable(String m) {
    if (_t == null) _kindPanic(m, kInvalid);
    if (_flag & _fRO != 0) {
      throw Panic(
        Golang.String.fromDart(
          'reflect: $m using value obtained using unexported field',
        ),
      );
    }
    if (_flag & _fAddr == 0) {
      throw Panic(
        Golang.String.fromDart('reflect: $m using unaddressable value'),
      );
    }
  }

  /// Escreve a representação [rep] (já do tipo deste Value) no lugar dele.
  void _store(Object? rep) {
    if (_t!.$isValueKind) {
      ($rep as GoValue).$setAny(rep as Object);
    } else {
      final put =
          _put ??
          (throw Panic(
            Golang.String.fromDart('reflect: valor sem lugar para escrita'),
          ));
      put(rep);
    }
  }

  /// `Value.Set(x)`.
  void set(Value x) {
    _mustBeAssignable('reflect.Set');
    if (x._flag & _fRO != 0) {
      throw Panic(
        Golang.String.fromDart(
          'reflect.Set: value obtained using unexported field',
        ),
      );
    }
    _store(_assignRep(x, _t!, 'reflect.Set'));
  }

  void _setKind(bool Function(int) ok, String m, Object canon) {
    _mustBeAssignable(m);
    if (!ok(_kind)) _kindPanic(m, _kind);
    _store(_t!.$conv!(canon));
  }

  void setBool(bool x) =>
      _setKind((k) => k == kBool, 'reflect.Value.SetBool', x);
  void setInt(Golang.Int64 x) =>
      _setKind(_isIntKind, 'reflect.Value.SetInt', x);
  void setUint(Golang.Uint64 x) =>
      _setKind(_isUintKind, 'reflect.Value.SetUint', x);
  void setFloat(Golang.Float64 x) =>
      _setKind(_isFloatKind, 'reflect.Value.SetFloat', x.toDouble());
  void setString(Golang.String x) =>
      _setKind((k) => k == kString, 'reflect.Value.SetString', x);
  void setComplex(Golang.Complex128 x) =>
      _setKind(_isComplexKind, 'reflect.Value.SetComplex', x);

  void setBytes(Slice<Golang.Uint8> x) {
    _mustBeAssignable('reflect.Value.SetBytes');
    final t = _t!;
    if (t.$kind != kSlice || t.$elem!.$kind != kUint8)
      _kindPanic('reflect.Value.SetBytes', t.$kind);
    _store(t.$name.isEmpty ? x : t.$conv!(x));
  }

  /// `Value.SetLen(n)`.
  void setLen(Golang.Int n) {
    _mustBeAssignable('reflect.Value.SetLen');
    _mustBe(kSlice, 'reflect.Value.SetLen');
    final s = $rep as Slice;
    final m = n.toInt();
    if (m < 0 || m > s.capacity)
      throw Panic(
        Golang.String.fromDart('reflect: slice length out of range in SetLen'),
      );
    final r = s.slice(0, m);
    _store(_t!.$name.isEmpty ? r : _t!.$conv!(r));
  }

  /// `Value.SetZero()`.
  void setZero() {
    _mustBeAssignable('reflect.Value.SetZero');
    _store(_t!.$zero());
  }

  /// `Value.SetMapIndex(key, elem)`: elem inválido apaga a chave.
  void setMapIndex(Value key, Value elem) {
    _mustBe(kMap, 'reflect.Value.SetMapIndex');
    if (_flag & _fRO != 0) {
      throw Panic(
        Golang.String.fromDart(
          'reflect: reflect.Value.SetMapIndex using value obtained using unexported field',
        ),
      );
    }
    final t = _t!;
    final m = $rep as GoMap;
    final k = _assignRep(key, t.$key!, 'reflect.Value.SetMapIndex');
    if (!elem.isValid()) {
      m.delete(k);
      return;
    }
    m[k] = _assignRep(elem, t.$elem!, 'reflect.Value.SetMapIndex');
  }

  /// `Value.Addr()`.
  Value addr$() {
    if (_flag & _fAddr == 0) {
      throw Panic(
        Golang.String.fromDart('reflect.Value.Addr of unaddressable value'),
      );
    }
    final t = _t!;
    final pt = t.ptrTo();
    if (t.$isValueKind) return Value._of(pt, $rep, _flag & _fRO);
    final from = _from;
    if (from != null) return Value._of(pt, from, _flag & _fRO);
    final get = _get!, put = _put!;
    return Value._of(pt, t.$locPtr(get, put), _flag & _fRO);
  }

  /// `Value.CanConvert(t)`.
  bool canConvert(RType? t) =>
      t != null && $convertible(_need('reflect.Value.CanConvert'), t);

  /// `Value.Convert(t)`.
  Value convert(RType? t) {
    final v = _need('reflect.Value.Convert');
    if (t == null || !$convertible(v, t)) {
      throw Panic(
        Golang.String.fromDart(
          'reflect.Value.Convert: value of type ${v.$str} cannot be converted to type ${t?.$str}',
        ),
      );
    }
    return Value._of(t, _convertRep(v, $rep, t), _flag & _fRO);
  }

  /// `Value.Equal(u)` (o `==` do Go sobre os dois valores).
  bool equal(Value u) {
    if (_t == null || u._t == null) return _t == null && u._t == null;
    if (_kind == kInterface || u._kind == kInterface)
      return elem$().equal(u.elem$());
    if (!identical(_t, u._t)) return false;
    if (!_t!.$isComparable) {
      throw Panic(
        Golang.String.fromDart(
          'reflect.Value.Equal: values of type ${_t!.$str} are not comparable',
        ),
      );
    }
    return ifaceEq($iface(), u.$iface());
  }
}

/// A representação de [x] para guardar num lugar do tipo [t] (atribuível,
/// como no Go): interface guarda o valor como numa interface; struct/array
/// vira uma cópia; nomeado × sem nome do mesmo subjacente é reembrulhado.
Object? _assignRep(Value x, RType t, String ctx) {
  final xt = x._t ?? _kindPanic(ctx, kInvalid);
  if (!$assignable(t, xt)) {
    throw Panic(
      Golang.String.fromDart(
        '$ctx: value of type ${xt.$str} is not assignable to type ${t.$str}',
      ),
    );
  }
  if (t.$kind == kInterface)
    return xt.$kind == kInterface ? x.$rep : x.$iface();
  final r = x.$rep;
  if (!identical(xt, t) && t.$conv != null) return t.$conv!(r as Object);
  if (t.$isValueKind) return (r as GoValue).$copy();
  return r;
}

/// `T(x)` em runtime (as conversões que o `$convertible` aceita).
Object? _convertRep(RType v, Object? r, RType t) {
  final vk = v.$kind, tk = t.$kind;
  if (tk == kInterface) return Value._of(v, r).$iface();
  bool isInt(int k) => _isIntKind(k) || _isUintKind(k);
  if (isInt(tk)) {
    if (isInt(vk)) return t.$conv!(r as Golang.IntBase);
    if (_isFloatKind(vk)) {
      return t.$conv!(
        (r as Golang.FloatBase).toInteger(t.$size * 8, signed: _isIntKind(tk)),
      );
    }
  }
  if (_isFloatKind(tk)) {
    if (isInt(vk)) {
      final n = r as Golang.IntBase;
      final d = n.$signed
          ? Golang.Float64.fromInt64(Golang.Int64.from(n))
          : Golang.Float64.fromUint64(Golang.Uint64.from(n));
      return t.$conv!(
        tk == kFloat32 ? Golang.Float32(d.toDouble()).toDouble() : d.toDouble(),
      );
    }
    if (_isFloatKind(vk)) return t.$conv!((r as Golang.FloatBase).toDouble());
  }
  if (_isComplexKind(tk) && _isComplexKind(vk)) {
    final c = r is Golang.Complex64
        ? Golang.Complex128.fromDoubles(r.real.toDouble(), r.imag.toDouble())
        : r as Golang.Complex128;
    return t.$conv!(c);
  }
  if (tk == kString) {
    if (isInt(vk)) {
      final n = r as Golang.IntBase;
      final cp = n.$hi != 0 && n.$hi != 0xFFFFFFFF ? 0xFFFD : n.toInt();
      return t.$conv!(
        Golang.String.fromCodePoint(cp < 0 || cp > 0x10FFFF ? 0xFFFD : cp),
      );
    }
    if (vk == kString) return t.$conv!((r as Golang.StringBase).$str);
    if (vk == kSlice && v.$elem!.$kind == kUint8) {
      return t.$conv!(
        Golang.String.fromBytes(
          Uint8List.fromList([
            for (final b in (r as Slice).items) (b as Golang.IntBase).toInt(),
          ]),
        ),
      );
    }
    if (vk == kSlice && v.$elem!.$kind == kInt32) {
      return t.$conv!(
        Golang.String.fromRunes([
          for (final c in (r as Slice).items) (c as Golang.IntBase).toInt(),
        ]),
      );
    }
  }
  if (vk == kString && tk == kSlice) {
    final s = (r as Golang.StringBase).$str;
    final e = t.$elem!;
    final items = e.$kind == kUint8
        ? [for (final b in s.toBytes()) e.$conv!(Golang.Uint8(b))]
        : [for (final c in s.runes()) e.$conv!(Golang.Int32(c))];
    final out = e.$makeSlice(0, 0).append(e.$listOf(items));
    return t.$name.isEmpty ? out : t.$conv!(out);
  }
  if (identical(v.$under, t.$under) || vk == tk) {
    if (t.$conv != null) return t.$conv!(r as Object);
    return r;
  }
  throw Panic(
    Golang.String.fromDart(
      'reflect.Value.Convert: conversão de ${v.$str} para ${t.$str} não suportada',
    ),
  );
}
