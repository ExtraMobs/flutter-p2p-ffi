part of '../../reflect.dart';

/// Os métodos Go de `reflect.Type` sobre o descritor.
extension TypeApi on RType {
  Kind kind() => Kind($kind);
  Golang.String name() => Golang.String.fromDart($name);
  Golang.String pkgPath() => Golang.String.fromDart($pkg);
  Golang.Uintptr size() => Golang.Uintptr($size);
  Golang.Int align() => Golang.Int($align);
  Golang.Int fieldAlign() => Golang.Int($align);
  bool comparable() => $isComparable;

  /// `Type.Bits()`: tamanho em bits de inteiros, floats e complexos.
  Golang.Int bits() {
    final k = $kind;
    if (!(_isIntKind(k) ||
        _isUintKind(k) ||
        _isFloatKind(k) ||
        _isComplexKind(k))) {
      throw Panic(
        Golang.String.fromDart('reflect: Bits of non-arithmetic Type ${$str}'),
      );
    }
    return Golang.Int($size * 8);
  }

  /// `Type.Elem()`.
  RType? elem$() => switch ($kind) {
    kArray || kChan || kMap || kPointer || kSlice => $elem,
    _ => throw Panic(
      Golang.String.fromDart('reflect: Elem of invalid type ${$str}'),
    ),
  };

  /// `Type.Key()`.
  RType? key() => $kind == kMap
      ? $key
      : throw Panic(
          Golang.String.fromDart('reflect: Key of non-map type ${$str}'),
        );

  /// `Type.Len()`.
  Golang.Int len() => $kind == kArray
      ? Golang.Int($len)
      : throw Panic(
          Golang.String.fromDart('reflect: Len of non-array type ${$str}'),
        );

  /// `Type.ChanDir()`.
  ChanDir chanDir() => $kind == kChan
      ? ChanDir($dir)
      : throw Panic(
          Golang.String.fromDart('reflect: ChanDir of non-chan type ${$str}'),
        );

  RType _struct(String m) => $kind == kStruct
      ? this
      : throw Panic(
          Golang.String.fromDart('reflect: $m of non-struct type ${$str}'),
        );

  /// `Type.NumField()`.
  Golang.Int numField() => Golang.Int(_struct('NumField').$fields.length);

  /// `Type.Field(i)`.
  StructField field(Golang.Int i) {
    final fs = _struct('Field').$fields;
    final n = i.toInt();
    if (n < 0 || n >= fs.length) {
      throw Panic(Golang.String.fromDart('reflect: Field index out of bounds'));
    }
    return _structField(fs[n], [n]);
  }

  /// `Type.FieldByIndex(index)`.
  StructField fieldByIndex(Slice<Golang.Int> index) {
    RType t = this;
    var f = StructField();
    final path = <int>[];
    for (final i in index.items) {
      if (t.$kind == kPointer && t.$elem!.$kind == kStruct) t = t.$elem!;
      f = t.field(i);
      path.add(i.toInt());
      t = f.type!;
    }
    return f
      ..index = Slice<Golang.Int>.of([
        for (final i in path) Golang.Int(i),
      ], _intElem);
  }

  /// `Type.FieldByName(name)`: com promoção pelos campos embutidos (o mais
  /// raso vence; dois no mesmo nível se anulam), como o Go.
  (StructField, bool) fieldByName(Golang.String name) {
    final r = $fieldByName(_struct('FieldByName'), name.toString());
    if (r == null) return (StructField(), false);
    return (_structField(r.$2, r.$1), true);
  }

  /// `Type.NumMethod()`: métodos exportados (de uma interface, todos).
  Golang.Int numMethod() => Golang.Int(_methodNames(this).length);

  /// `Type.Method(i)`: fora de interface, `Type` e `Func` com o receptor
  /// como primeiro parâmetro.
  Method method(Golang.Int i) {
    final ms = _methodNames(this);
    final n = i.toInt();
    if (n < 0 || n >= ms.length) {
      throw Panic(Golang.String.fromDart('reflect: Method index out of range'));
    }
    return _methodAt(this, ms[n], n);
  }

  /// `Type.MethodByName(name)`.
  (Method, bool) methodByName(Golang.String name) {
    final ms = _methodNames(this);
    final n = ms.indexOf(name.toString());
    if (n < 0) return (Method(), false);
    return (_methodAt(this, ms[n], n), true);
  }

  /// `Type.Implements(u)`.
  bool implements(RType? u) {
    if (u == null)
      throw Panic(
        Golang.String.fromDart('reflect: nil type passed to Type.Implements'),
      );
    if (u.$kind != kInterface) {
      throw Panic(
        Golang.String.fromDart(
          'reflect: non-interface type passed to Type.Implements',
        ),
      );
    }
    return $implements(this, u);
  }

  /// `Type.AssignableTo(u)`.
  bool assignableTo(RType? u) {
    if (u == null)
      throw Panic(
        Golang.String.fromDart('reflect: nil type passed to Type.AssignableTo'),
      );
    return $assignable(u, this);
  }

  /// `Type.ConvertibleTo(u)`.
  bool convertibleTo(RType? u) {
    if (u == null)
      throw Panic(
        Golang.String.fromDart(
          'reflect: nil type passed to Type.ConvertibleTo',
        ),
      );
    return $convertible(this, u);
  }

  /// `Type.OverflowInt(x)`.
  bool overflowInt(Golang.Int64 x) {
    if (!_isIntKind($kind))
      throw Panic(
        Golang.String.fromDart('reflect: OverflowInt of non-int type ${$str}'),
      );
    final bits = $size * 8;
    final v = x.toBigInt();
    return v < -(BigInt.one << (bits - 1)) || v >= (BigInt.one << (bits - 1));
  }

  /// `Type.OverflowUint(x)`.
  bool overflowUint(Golang.Uint64 x) {
    if (!_isUintKind($kind))
      throw Panic(
        Golang.String.fromDart(
          'reflect: OverflowUint of non-uint type ${$str}',
        ),
      );
    return x.toBigInt() >= (BigInt.one << ($size * 8));
  }

  /// `Type.OverflowFloat(x)`.
  bool overflowFloat(Golang.Float64 x) {
    if (!_isFloatKind($kind))
      throw Panic(
        Golang.String.fromDart(
          'reflect: OverflowFloat of non-float type ${$str}',
        ),
      );
    if ($kind == kFloat64) return false;
    final d = x.toDouble().abs();
    return d > 3.4028234663852886e38 && !d.isInfinite;
  }
}

/// Method set Go de t (nomes): o de `*T` para ponteiro para nomeado.
List<String> _methodSet(RType t) {
  if (t.$kind == kInterface) return t.$methods;
  if (t.$kind == kPointer && t.$name.isEmpty) {
    final e = t.$elem!;
    if (e.$name.isNotEmpty || e.$kind == kStruct) return e.$ptrMethods;
    return const [];
  }
  return t.$methods;
}

/// `Method` de [t] (`Type.Method`/`MethodByName`).
Method _methodAt(RType t, String name, int i) {
  final sig = _methodSig(t, name);
  if (t.$kind == kInterface || sig == null) {
    return Method(
      name: Golang.String.fromDart(name),
      type: sig,
      index: Golang.Int(i),
    );
  }
  final fn = sig.$fn!;
  final mt = rtFuncOf<Object?>(
    '',
    () => [t, ...fn.ins()],
    fn.outs,
    variadic: fn.variadic,
    async: fn.async,
  );
  return Method(
    name: Golang.String.fromDart(name),
    type: mt,
    func: Value._of(mt, _MethodExpr(t, name)),
    index: Golang.Int(i),
  );
}

/// Descritor da assinatura do método [name] de [t] (sem o receptor).
RType? _methodSig(RType t, String name) {
  if (t.$kind == kInterface) return t.$sigs[name]?.call();
  final owner = t.$kind == kPointer && t.$name.isEmpty ? t.$elem! : t;
  return owner.$sigs[name]?.call();
}

/// Métodos que o `NumMethod` conta: de interface, todos; senão, os exportados.
List<String> _methodNames(RType t) {
  final ms = _methodSet(t);
  if (t.$kind == kInterface) return ms;
  return [
    for (final m in ms)
      if (m.isNotEmpty &&
          m[0].toUpperCase() == m[0] &&
          m[0].toLowerCase() != m[0])
        m,
  ];
}

/// t implementa a interface u (por nome dos métodos).
bool $implements(RType t, RType u) {
  final ms = _methodSet(t);
  return u.$methods.every(ms.contains);
}

/// Um valor do tipo [v] é atribuível a [t]?
bool $assignable(RType t, RType v) {
  if (identical(t, v)) return true;
  if (t.$kind == kInterface) return $implements(v, t);
  if (t.$name.isNotEmpty && v.$name.isNotEmpty) return false;
  return identical(t.$under, v.$under) && t.$kind != kInterface;
}

/// `T(x)` com x do tipo [v] é válido para [t]?
bool $convertible(RType v, RType t) {
  if ($assignable(t, v)) return true;
  if (identical(t.$under, v.$under)) return true;
  final vk = v.$kind, tk = t.$kind;
  bool num(int k) => _isIntKind(k) || _isUintKind(k) || _isFloatKind(k);
  if (num(vk) && num(tk)) return true;
  if (_isComplexKind(vk) && _isComplexKind(tk)) return true;
  if (tk == kString && (_isIntKind(vk) || _isUintKind(vk))) return true;
  bool bytesOrRunes(RType s) =>
      s.$kind == kSlice &&
      (s.$elem!.$kind == kUint8 || s.$elem!.$kind == kInt32);
  if (tk == kString && bytesOrRunes(v)) return true;
  if (vk == kString && bytesOrRunes(t)) return true;
  if (vk == kSlice) {
    if (tk == kArray && identical(t.$elem, v.$elem)) return true;
    if (tk == kPointer &&
        t.$elem!.$kind == kArray &&
        identical(t.$elem!.$elem, v.$elem))
      return true;
  }
  if (vk == kPointer && tk == kPointer && v.$name.isEmpty && t.$name.isEmpty) {
    return identical(v.$elem!.$under, t.$elem!.$under);
  }
  return false;
}

/// Campo `name` de uma struct, com promoção: (caminho, campo) ou null.
(List<int>, RField)? $fieldByName(RType t, String name) {
  var level = <(RType, List<int>)>[(t, const [])];
  final visited = <RType>{};
  while (level.isNotEmpty) {
    (List<int>, RField)? found;
    var count = 0;
    final next = <(RType, List<int>)>[];
    for (final (st, path) in level) {
      if (!visited.add(st)) continue;
      final fs = st.$fields;
      for (var i = 0; i < fs.length; i++) {
        final f = fs[i];
        if (f.name == name) {
          count++;
          found ??= ([...path, i], f);
        } else if (f.embedded) {
          var ft = f.type;
          if (ft.$kind == kPointer) ft = ft.$elem!;
          if (ft.$kind == kStruct && !ft.$opaque) next.add((ft, [...path, i]));
        }
      }
    }
    if (count == 1) return found;
    if (count > 1) return null;
    level = next;
  }
  return null;
}
