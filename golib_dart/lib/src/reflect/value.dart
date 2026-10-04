part of '../../reflect.dart';

const _fAddr = 1; // endereçável (veio de ponteiro, slice ou campo endereçável)
const _fStickyRO = 2; // veio de campo não exportado (passa aos campos dele)
const _fEmbedRO =
    4; // veio de struct embutida não exportada (não passa aos campos)
const _fRO = _fStickyRO | _fEmbedRO; // não pode Set nem Interface

/// `reflect.Value`: o tipo, a representação Dart do valor e, se endereçável,
/// o lugar onde ele mora (closures de leitura e escrita).
///
/// A representação segue a do código gerado: struct/array é o próprio objeto
/// (`go.GoValue`), `*T` de struct é o objeto (`null` se nil), `*T` de
/// não-struct é um `go.Ptr`, interface é o valor dinâmico como guardado
/// numa interface.
final class Value extends GoStruct<Value> implements FmtReflectValue {
  /// O `Value{}` do Go (inválido).
  Value()
    : _t = null,
      _rep = null,
      _get = null,
      _put = null,
      _flag = 0,
      _from = null;

  Value._of(RType t, Object? rep, [int flag = 0])
    : _t = t,
      _rep = rep,
      _get = null,
      _put = null,
      _flag = flag,
      _from = null;

  Value._at(
    RType t,
    Object? Function() get,
    void Function(Object?)? put,
    int flag, [
    Ptr? from,
  ]) : _t = t,
       _rep = null,
       _get = get,
       _put = put,
       _flag = flag,
       _from = from;

  static final Value $nil = Value()..$nilPtr = true;

  RType? _t;
  Object? _rep;
  Object? Function()? _get;
  void Function(Object?)? _put;
  int _flag;
  Ptr? _from;

  @override
  bool get $valid => _t != null;

  @override
  Object? get $fmtArg => $iface();

  /// O descritor (null: Value inválido).
  RType? get $t => _t;

  /// A representação Dart atual do valor.
  Object? get $rep => _get != null ? _get!() : _rep;

  @override
  String get $goType => 'reflect.Value';

  @override
  List<String> get $valueMethods => _methods;

  @override
  List<String> get $ptrMethods => _methods;

  static const _methods = [
    'Bool',
    'Bytes',
    'CanAddr',
    'CanInterface',
    'CanSet',
    'Elem',
    'Field',
    'Float',
    'Index',
    'Int',
    'Interface',
    'IsNil',
    'IsValid',
    'IsZero',
    'Kind',
    'Len',
    'MapIndex',
    'MapKeys',
    'NumField',
    'Set',
    'String',
    'Type',
    'Uint',
  ];

  @override
  Value $copy() => Value()
    .._t = _t
    .._rep = _rep
    .._get = _get
    .._put = _put
    .._flag = _flag
    .._from = _from;

  @override
  void $set(Value o) {
    _t = o._t;
    _rep = o._rep;
    _get = o._get;
    _put = o._put;
    _flag = o._flag;
    _from = o._from;
  }

  @override
  List<Object?> get $fields => [_t, _rep, _get, _flag];

  @override
  List<String> get $fieldNames => const ['typ_', 'ptr', 'get', 'flag'];

  int get _kind => _t?.$kind ?? kInvalid;

  RType _need(String m) => _t ?? _kindPanic(m, kInvalid);

  void _mustBe(int k, String m) {
    if (_kind != k) _kindPanic(m, _kind);
  }

  // ------------------------------------------------------------- consulta
  Kind kind() => Kind(_kind);

  bool isValid() => _t != null;

  RType? type() {
    if (_t == null) {
      throw Panic(
        ValueError(
          method: Golang.String.fromDart('reflect.Value.Type'),
          kind: Kind(),
        ),
      );
    }
    return _t;
  }

  bool canAddr() => _flag & _fAddr != 0;
  bool canSet() => _flag & (_fAddr | _fRO) == _fAddr;
  bool canInterface() {
    _need('reflect.Value.CanInterface');
    return _flag & _fRO == 0;
  }

  /// `Value.Interface()`: o valor como guardado numa interface.
  Object? interface() {
    _need('reflect.Value.Interface');
    if (_flag & _fRO != 0) {
      throw Panic(
        Golang.String.fromDart(
          'reflect.Value.Interface: cannot return value obtained from unexported field or method',
        ),
      );
    }
    return $iface();
  }

  /// [interface] sem a checagem de campo não exportado (fmt, json).
  Object? $iface() {
    final t = _t!;
    final r = $rep;
    switch (t.$kind) {
      case kStruct || kArray:
        return (r as GoValue).$ifaceCopy();
      case kPointer:
        return r ?? t.$elem!.$typedNil();
      case kFunc:
        return t.$name.isEmpty ? Func(r as Function?, t.$str) : r;
      default:
        return r;
    }
  }

  bool isNil$() => switch (_kind) {
    kPointer || kInterface || kFunc || kChan || kUnsafePointer => $rep == null,
    kSlice => ($rep as Slice).isNil,
    kMap => ($rep as GoMap).isNil,
    _ => _kindPanic('reflect.Value.IsNil', _kind),
  };

  bool isZero() => _isZeroRep(_need('reflect.Value.IsZero'), $rep);

  Golang.Int len() => Golang.Int(switch (_kind) {
    kSlice => ($rep as Slice).length,
    kMap => ($rep as GoMap).length,
    kString => ($rep as Golang.StringBase).$str.length,
    kArray => _t!.$len,
    kChan => ($rep as Chan?)?.len ?? 0,
    kPointer when _t!.$elem!.$kind == kArray => _t!.$elem!.$len,
    _ => _kindPanic('reflect.Value.Len', _kind),
  });

  Golang.Int cap() => Golang.Int(switch (_kind) {
    kSlice => ($rep as Slice).capacity,
    kArray => _t!.$len,
    kChan => ($rep as Chan?)?.cap ?? 0,
    kPointer when _t!.$elem!.$kind == kArray => _t!.$elem!.$len,
    _ => _kindPanic('reflect.Value.Cap', _kind),
  });

  bool bool$() {
    _mustBe(kBool, 'reflect.Value.Bool');
    final r = $rep;
    return r is GoBool ? r.$b : r as bool;
  }

  Golang.Int64 int$() {
    if (!_isIntKind(_kind)) _kindPanic('reflect.Value.Int', _kind);
    return Golang.Int64.from($rep as Golang.IntBase);
  }

  Golang.Uint64 uint() {
    if (!_isUintKind(_kind)) _kindPanic('reflect.Value.Uint', _kind);
    return Golang.Uint64.from($rep as Golang.IntBase);
  }

  Golang.Float64 float() {
    if (!_isFloatKind(_kind)) _kindPanic('reflect.Value.Float', _kind);
    return Golang.Float64(($rep as Golang.FloatBase).toDouble());
  }

  Golang.Complex128 complex() {
    if (!_isComplexKind(_kind)) _kindPanic('reflect.Value.Complex', _kind);
    final r = $rep;
    return r is Golang.Complex64
        ? Golang.Complex128.fromDoubles(r.real.toDouble(), r.imag.toDouble())
        : r as Golang.Complex128;
  }

  /// `Value.String()`: o texto de uma string; dos outros kinds, `<T Value>`.
  Golang.String string() => switch (_kind) {
    kInvalid => Golang.String.fromDart('<invalid Value>'),
    kString => ($rep as Golang.StringBase).$str,
    _ => Golang.String.fromDart('<${_t!.$str} Value>'),
  };

  Slice<Golang.Uint8> bytes() {
    final t = _need('reflect.Value.Bytes');
    if (t.$kind == kSlice && t.$elem!.$kind == kUint8)
      return $rep as Slice<Golang.Uint8>;
    if (t.$kind == kArray && t.$elem!.$kind == kUint8 && canAddr()) {
      return ($rep as GoArray<Golang.Uint8>).slice(0);
    }
    _kindPanic('reflect.Value.Bytes', t.$kind);
  }

  /// `Value.Pointer()`: um número estável por objeto (identidade).
  Golang.Uintptr pointer() {
    final r = $rep;
    return Golang.Uintptr(
      r == null ? 0 : identityHashCode(r is Slice ? r.items : r),
    );
  }

  Golang.Int numField() => _need('reflect.Value.NumField').numField();

  Golang.Int numMethod() => _need('reflect.Value.NumMethod').numMethod();

  bool comparable() => _t == null || _t!.$isComparable;

  // ---------------------------------------------------------- navegação
  /// `Value.Elem()`: o apontado por um ponteiro, ou o valor dinâmico de
  /// uma interface.
  Value elem$() {
    final t = _t;
    final r = $rep;
    if (t?.$kind == kInterface) {
      if (r == null) return Value();
      return Value._of(rtypeOf(r)!, $repOf(r), _flag & _fRO);
    }
    if (t?.$kind != kPointer) _kindPanic('reflect.Value.Elem', _kind);
    if (r == null) return Value();
    final e = t!.$elem!;
    final flag = (_flag & _fRO) | _fAddr;
    if (e.$isValueKind) return Value._at(e, () => r, null, flag);
    final p = r as Ptr;
    return Value._at(e, () => p.value, (v) => p.value = v, flag, p);
  }

  /// `Value.Field(i)`.
  Value field(Golang.Int i) => _field(i.toInt());

  Value _field(int i) {
    final t = _t;
    if (t?.$kind != kStruct) _kindPanic('reflect.Value.Field', _kind);
    final fs = t!.$fields;
    if (i < 0 || i >= fs.length) {
      throw Panic(Golang.String.fromDart('reflect: Field index out of range'));
    }
    final f = fs[i];
    final obj = $rep as Object;
    // Como o Go: o campo exportado de uma struct embutida não exportada
    // continua gravável (flagEmbedRO não passa adiante; flagStickyRO sim).
    var flag = _flag & (_fAddr | _fStickyRO);
    if (f.pkg.isNotEmpty) flag |= f.embedded ? _fEmbedRO : _fStickyRO;
    final get =
        f.get ??
        (throw Panic(
          Golang.String.fromDart(
            'reflect: campo ${f.name} de ${t.$str} sem acesso',
          ),
        ));
    final set = f.set;
    return Value._at(
      f.type,
      () => get(obj),
      set == null ? null : (v) => set(obj, v),
      flag,
    );
  }

  /// `Value.FieldByIndex(index)`.
  Value fieldByIndex(Slice<Golang.Int> index) =>
      _fieldPath([for (final i in index.items) i.toInt()]);

  Value _fieldPath(List<int> path) {
    var v = this;
    for (var n = 0; n < path.length; n++) {
      if (n > 0 && v._kind == kPointer && v._t!.$elem!.$kind == kStruct) {
        if (v.$rep == null) {
          throw Panic(
            Golang.String.fromDart(
              'reflect: indirection through nil pointer to embedded struct',
            ),
          );
        }
        v = v.elem$();
      }
      v = v._field(path[n]);
    }
    return v;
  }

  /// `Value.FieldByName(name)`: Value inválido se não há (ou é ambíguo).
  Value fieldByName(Golang.String name) {
    final t = _t;
    if (t?.$kind != kStruct) _kindPanic('reflect.Value.FieldByName', _kind);
    final r = $fieldByName(t!, name.toString());
    return r == null ? Value() : _fieldPath(r.$1);
  }

  /// `Value.Index(i)`.
  Value index(Golang.Int i) {
    final n = i.toInt();
    final t = _t;
    switch (_kind) {
      case kSlice:
        final s = $rep as Slice;
        if (n < 0 || n >= s.length) {
          throw Panic(
            Golang.String.fromDart('reflect: slice index out of range'),
          );
        }
        return Value._at(
          t!.$elem!,
          () => s[n],
          (v) => s[n] = v,
          _fAddr | (_flag & _fRO),
        );
      case kArray:
        final a = $rep as GoArray;
        if (n < 0 || n >= a.length) {
          throw Panic(
            Golang.String.fromDart('reflect: array index out of range'),
          );
        }
        return Value._at(
          t!.$elem!,
          () => a[n],
          (v) => a[n] = v,
          _flag & (_fAddr | _fRO),
        );
      case kString:
        final s = ($rep as Golang.StringBase).$str;
        if (n < 0 || n >= s.length) {
          throw Panic(
            Golang.String.fromDart('reflect: string index out of range'),
          );
        }
        return Value._of(rtUint8, Golang.Uint8(s[n]), _flag & _fRO);
    }
    _kindPanic('reflect.Value.Index', _kind);
  }

  /// `Value.Slice(i, j)`.
  Value slice$(Golang.Int i, Golang.Int j) {
    final t = _t;
    switch (_kind) {
      case kSlice:
        final s = ($rep as Slice).slice(i.toInt(), j.toInt());
        return Value._of(
          t!,
          t.$conv != null && t.$name.isNotEmpty ? t.$conv!(s) : s,
          _flag & _fRO,
        );
      case kArray:
        if (!canAddr()) {
          throw Panic(
            Golang.String.fromDart(
              'reflect.Value.Slice: slice of unaddressable array',
            ),
          );
        }
        final s = ($rep as GoArray).slice(i.toInt(), j.toInt());
        return Value._of(t!.$elem!.sliceOf(), s, _flag & _fRO);
      case kString:
        final s = ($rep as Golang.StringBase).$str.slice(i.toInt(), j.toInt());
        return Value._of(t!, t.$conv!(s), _flag & _fRO);
    }
    _kindPanic('reflect.Value.Slice', _kind);
  }

  // ---------------------------------------------------------------- maps
  /// `Value.MapIndex(key)`: Value inválido se a chave não está no map.
  Value mapIndex(Value key) {
    _mustBe(kMap, 'reflect.Value.MapIndex');
    final t = _t!;
    final k = _assignRep(key, t.$key!, 'reflect.Value.MapIndex');
    final (v, ok) = ($rep as GoMap).lookup(k);
    return ok ? Value._of(t.$elem!, v, _flag & _fRO) : Value();
  }

  /// `Value.MapKeys()` (ordem do map, não especificada no Go).
  Slice<Value> mapKeys() {
    _mustBe(kMap, 'reflect.Value.MapKeys');
    final kt = _t!.$key!;
    final m = $rep as GoMap;
    return Slice<Value>.of([
      for (final k in m.keysSnapshot()) Value._of(kt, k, _flag & _fRO),
    ], $valueElem);
  }

  /// `Value.MapRange()`.
  MapIter mapRange() {
    _mustBe(kMap, 'reflect.Value.MapRange');
    return MapIter._(this);
  }
}
