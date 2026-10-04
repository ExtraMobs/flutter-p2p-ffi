part of '../../reflect.dart';

/// `reflect.New(t)`: Value do ponteiro para um zero value novo de t.
Value new$(RType? t) {
  final rt = _needType(t, 'reflect.New');
  return Value._of(rt.ptrTo(), rt.$newPtr());
}

/// `reflect.Zero(t)`: o zero value (não endereçável).
Value zero(RType? t) {
  final rt = _needType(t, 'reflect.Zero');
  return Value._of(rt, rt.$zero());
}

/// `reflect.Indirect(v)`.
Value indirect(Value v) => v._kind == kPointer ? v.elem$() : v;

/// `reflect.MakeSlice(t, len, cap)`.
Value makeSlice(RType? t, Golang.Int len, Golang.Int cap) {
  final rt = _needType(t, 'reflect.MakeSlice');
  if (rt.$kind != kSlice) {
    throw Panic(Golang.String.fromDart('reflect.MakeSlice of non-slice type'));
  }
  final n = len.toInt(), c = cap.toInt();
  if (n < 0)
    throw Panic(Golang.String.fromDart('reflect.MakeSlice: negative len'));
  if (c < 0)
    throw Panic(Golang.String.fromDart('reflect.MakeSlice: negative cap'));
  if (n > c)
    throw Panic(Golang.String.fromDart('reflect.MakeSlice: len > cap'));
  final s = rt.$elem!.$makeSlice(n, c);
  return Value._of(rt, rt.$name.isEmpty ? s : rt.$conv!(s));
}

/// `reflect.MakeMap(t)`.
Value makeMap(RType? t) => makeMapWithSize(t, Golang.Int());

/// `reflect.MakeMapWithSize(t, n)`.
Value makeMapWithSize(RType? t, Golang.Int n) {
  final rt = _needType(t, 'reflect.MakeMapWithSize');
  if (rt.$kind != kMap) {
    throw Panic(
      Golang.String.fromDart('reflect.MakeMapWithSize of non-map type'),
    );
  }
  final m = rt.$elem!.$makeMapWithKey(rt.$key!);
  return Value._of(rt, rt.$name.isEmpty ? m : rt.$conv!(m));
}

/// `reflect.Append(s, x...)`.
Value append$(Value s, Slice<Value> x) {
  final t = s._t;
  if (t?.$kind != kSlice) _kindPanic('reflect.Append', s._kind);
  final e = t!.$elem!;
  final reps = [for (final v in x.items) _assignRep(v, e, 'reflect.Append')];
  return Value._of(t, _appendReps(t, s.$rep as Slice, reps));
}

/// `reflect.AppendSlice(s, t)`.
Value appendSlice$(Value s, Value t) {
  final st = s._t;
  if (st?.$kind != kSlice) _kindPanic('reflect.AppendSlice', s._kind);
  if (t._kind != kSlice) _kindPanic('reflect.AppendSlice', t._kind);
  if (!identical(st!.$elem, t._t!.$elem)) {
    throw Panic(
      Golang.String.fromDart(
        'reflect.AppendSlice: ${st.$str} != ${t._t!.$str}',
      ),
    );
  }
  final out = (s.$rep as Slice).appendSlice(t.$rep as Slice);
  return Value._of(st, st.$name.isEmpty ? out : st.$conv!(out));
}

Object _appendReps(RType t, Slice s, List<Object?> reps) {
  final out = s.append(t.$elem!.$listOf(reps));
  return t.$name.isEmpty ? out : t.$conv!(out);
}

/// `reflect.Copy(dst, src)`.
Golang.Int copy(Value dst, Value src) {
  final dk = dst._kind, sk = src._kind;
  if (dk != kSlice && dk != kArray) _kindPanic('reflect.Copy', dk);
  if (sk != kSlice && sk != kArray && sk != kString)
    _kindPanic('reflect.Copy', sk);
  if (dk == kArray && !dst.canSet()) {
    throw Panic(
      Golang.String.fromDart('reflect.Copy: unaddressable array value'),
    );
  }
  final d = dk == kArray ? (dst.$rep as GoArray).slice(0) : dst.$rep as Slice;
  if (sk == kString) {
    final bytes = (src.$rep as Golang.StringBase).$str.toBytes();
    final n = bytes.length < d.length ? bytes.length : d.length;
    for (var i = 0; i < n; i++) {
      d[i] = Golang.Uint8(bytes[i]);
    }
    return Golang.Int(n);
  }
  final s = sk == kArray ? (src.$rep as GoArray).slice(0) : src.$rep as Slice;
  return Golang.Int(d.copyFrom(s));
}

/// `reflect.Swapper(slice)`.
void Function(Golang.Int, Golang.Int) swapper(Object? slice) {
  final v = valueOf(slice);
  if (v._kind != kSlice) {
    throw Panic(
      ValueError(
        method: Golang.String.fromDart('Swapper'),
        kind: Kind(v._kind),
      ),
    );
  }
  final s = v.$rep as Slice;
  return (i, j) {
    final a = i.toInt(), b = j.toInt();
    final e = v._t!.$elem!;
    final x = s[a], y = s[b];
    if (e.$isValueKind) {
      final tmp = (x as GoValue).$copy();
      x.$setAny(y as Object);
      (y as GoValue).$setAny(tmp);
    } else {
      s[a] = y;
      s[b] = x;
    }
  };
}
