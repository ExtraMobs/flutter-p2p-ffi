part of '../../reflect.dart';

/// Assinatura de um tipo func: o que o g2d descreve em [rtFuncOf].
final class RFunc {
  RFunc(this.ins, this.outs, this.variadic, this.async);

  /// Tipos dos parâmetros (o variádico como `[]E`).
  final List<RType> Function() ins;

  /// Tipos dos resultados.
  final List<RType> Function() outs;

  final bool variadic;

  /// A closure Dart devolve `Future` (cor `async`, `g2d/analysis/color.py`).
  final bool async;
}

/// Método de um tipo sem receptor ligado (`Method.Func`): o receptor é o
/// primeiro argumento do `Call`.
final class _MethodExpr {
  _MethodExpr(this.recv, this.name);
  final RType recv;
  final String name;
}

RFunc _fnOf(RType t, String m) {
  if (t.$kind != kFunc) {
    throw Panic(
      Golang.String.fromDart('reflect: $m of non-func type ${t.$str}'),
    );
  }
  return t.$fn ??
      (throw Panic(
        Golang.String.fromDart(
          'reflect: $m de ${t.$str}: assinatura sem descritor (g2d)',
        ),
      ));
}

/// `Type.NumIn`/`In`/`NumOut`/`Out`/`IsVariadic`.
extension FuncTypeApi on RType {
  Golang.Int numIn() => Golang.Int(_fnOf(this, 'NumIn').ins().length);
  RType in$(Golang.Int i) => _fnOf(this, 'In').ins()[i.toInt()];
  Golang.Int numOut() => Golang.Int(_fnOf(this, 'NumOut').outs().length);
  RType out(Golang.Int i) => _fnOf(this, 'Out').outs()[i.toInt()];
  bool isVariadic() => _fnOf(this, 'IsVariadic').variadic;
}

/// `reflect.FuncOf(in, out, variadic)`.
RType funcOf(Slice<RType?> in$, Slice<RType?> out, bool variadic) {
  final ins = [for (final t in in$.items) _needType(t, 'reflect.FuncOf')];
  final outs = [for (final t in out.items) _needType(t, 'reflect.FuncOf')];
  if (variadic && (ins.isEmpty || ins.last.$kind != kSlice)) {
    throw Panic(
      Golang.String.fromDart(
        'reflect.FuncOf: last arg of variadic func must be slice',
      ),
    );
  }
  return rtFuncOf<Object?>('', () => ins, () => outs, variadic: variadic);
}

/// `reflect.MakeFunc(typ, fn)`: closure Dart do tipo de [typ] que chama
/// [fn] com os argumentos como `Value`.
Value makeFunc(RType? typ, Slice<Value> Function(Slice<Value>) fn) {
  final t = _needType(typ, 'reflect.MakeFunc');
  if (t.$kind != kFunc) {
    throw Panic(
      Golang.String.fromDart('reflect: call of MakeFunc with non-Func type'),
    );
  }
  final rf = _fnOf(t, 'MakeFunc');
  final ins = rf.ins(), outs = rf.outs();
  List<Object?> impl(List<Object?> reps) {
    final args = [
      for (var i = 0; i < ins.length; i++) Value._of(ins[i], reps[i]),
    ];
    final res = fn(Slice<Value>.of(args, $valueElem)).items.toList();
    if (res.length != outs.length) {
      throw Panic(
        Golang.String.fromDart(
          'reflect: wrong return count from function created by MakeFunc',
        ),
      );
    }
    return [for (var i = 0; i < outs.length; i++) _resultRep(res[i], outs[i])];
  }

  final f = _makeClosure(ins, outs, rf.async, impl);
  return Value._of(t, t.$name.isEmpty ? f : t.$conv!(f));
}

Object? _resultRep(Value v, RType t) {
  final vt = v._t;
  if (vt == null) {
    throw Panic(
      Golang.String.fromDart(
        'reflect: function created by MakeFunc using closure returned zero Value',
      ),
    );
  }
  if (!$assignable(t, vt)) {
    throw Panic(
      Golang.String.fromDart(
        'reflect: function created by MakeFunc using closure returned wrong type: have ${vt.$str} for ${t.$str}',
      ),
    );
  }
  return _assignRep(v, t, 'reflect.MakeFunc');
}

/// `Value.Call`/`CallSlice`/`Method`/`MethodByName`.
extension ValueCall on Value {
  /// `Value.Call(in)`. A função chamada não pode suspender: num contexto
  /// `async` o g2d chama [call$async].
  Slice<Value> call$(Slice<Value> in$) {
    final (res, outs) = _call('Call', in$.items.toList(), false);
    return _syncResults('Call', res, outs);
  }

  /// `Value.CallSlice(in)`.
  Slice<Value> callSlice(Slice<Value> in$) {
    final (res, outs) = _call('CallSlice', in$.items.toList(), true);
    return _syncResults('CallSlice', res, outs);
  }

  /// `Value.Call(in)` num contexto `async` (D2): espera a função que
  /// suspende.
  Future<Slice<Value>> call$async(Slice<Value> in$) async {
    final (res, outs) = _call('Call', in$.items.toList(), false);
    return _wrapResults(res is Future ? await res : res, outs);
  }

  /// `Value.CallSlice(in)` num contexto `async`.
  Future<Slice<Value>> callSlice$async(Slice<Value> in$) async {
    final (res, outs) = _call('CallSlice', in$.items.toList(), true);
    return _wrapResults(res is Future ? await res : res, outs);
  }

  (Object?, List<RType>) _call(String op, List<Value> args, bool isSlice) {
    final t = _t;
    if (t?.$kind != kFunc) _kindPanic('reflect.Value.$op', _kind);
    var r = $rep;
    var a = args;
    final isExpr = r is _MethodExpr;
    if (r is _MethodExpr) {
      if (a.isEmpty) {
        throw Panic(
          Golang.String.fromDart('reflect: Call with too few input arguments'),
        );
      }
      r = _bound(a[0], r.name);
      a = a.sublist(1);
    }
    final fn = _fnOf(t!, op);
    final f = r is FuncValue ? r.$f : r as Function?;
    if (f == null) {
      throw Panic(Golang.String.fromDart('reflect: call of nil function'));
    }
    var ins = fn.ins();
    if (isExpr) ins = ins.sublist(1);
    final n = ins.length;
    if (isSlice) {
      if (!fn.variadic) {
        throw Panic(
          Golang.String.fromDart('reflect: CallSlice of non-variadic function'),
        );
      }
      if (a.length < n) {
        throw Panic(
          Golang.String.fromDart(
            'reflect: CallSlice with too few input arguments',
          ),
        );
      }
      if (a.length > n) {
        throw Panic(
          Golang.String.fromDart(
            'reflect: CallSlice with too many input arguments',
          ),
        );
      }
    } else {
      final fixed = fn.variadic ? n - 1 : n;
      if (a.length < fixed) {
        throw Panic(
          Golang.String.fromDart('reflect: Call with too few input arguments'),
        );
      }
      if (!fn.variadic && a.length > n) {
        throw Panic(
          Golang.String.fromDart('reflect: Call with too many input arguments'),
        );
      }
    }
    for (final x in a) {
      if (!x.isValid()) {
        throw Panic(
          Golang.String.fromDart('reflect: $op using zero Value argument'),
        );
      }
    }
    final fixed = fn.variadic && !isSlice ? n - 1 : n;
    final reps = <Object?>[];
    for (var i = 0; i < fixed; i++) {
      final xt = a[i]._t!;
      if (!$assignable(ins[i], xt)) {
        throw Panic(
          Golang.String.fromDart(
            'reflect: $op using ${xt.$str} as type ${ins[i].$str}',
          ),
        );
      }
      reps.add(_assignRep(a[i], ins[i], 'reflect.Value.$op'));
    }
    if (fn.variadic && !isSlice) {
      final st = ins.last, e = st.$elem!;
      final extra = <Object?>[];
      for (var i = fixed; i < a.length; i++) {
        final xt = a[i]._t!;
        if (!$assignable(e, xt)) {
          throw Panic(
            Golang.String.fromDart(
              'reflect: cannot use ${xt.$str} as type ${e.$str} in $op',
            ),
          );
        }
        extra.add(_assignRep(a[i], e, 'reflect.Value.$op'));
      }
      final s = e.$makeSlice(0, 0).append(e.$listOf(extra));
      reps.add(st.$name.isEmpty ? s : st.$conv!(s));
    }
    return (Function.apply(f, reps), fn.outs());
  }

  /// `Value.NumMethod` conta; `Value.Method(i)`: o método ligado a v.
  Value method(Golang.Int i) {
    final t = _need('reflect.Value.Method');
    final ms = _methodNames(t);
    final n = i.toInt();
    if (n < 0 || n >= ms.length) {
      throw Panic(Golang.String.fromDart('reflect: Method index out of range'));
    }
    return _boundValue(ms[n]);
  }

  /// `Value.MethodByName(name)`: Value inválido se não existe.
  Value methodByName(Golang.String name) {
    final t = _need('reflect.Value.MethodByName');
    final n = name.toString();
    if (!_methodNames(t).contains(n)) return Value();
    return _boundValue(n);
  }

  Value _boundValue(String name) {
    final t = _t!;
    if (t.$kind == kInterface && $rep == null) {
      throw Panic(
        Golang.String.fromDart('reflect: Method on nil interface value'),
      );
    }
    final sig =
        _methodSig(t, name) ??
        (throw Panic(
          Golang.String.fromDart(
            'reflect: método $name de ${t.$str} sem descritor (g2d)',
          ),
        ));
    return Value._of(sig, _bound(this, name));
  }
}

Slice<Value> _syncResults(String op, Object? res, List<RType> outs) {
  if (res is Future) {
    // A chamada já começou: o Future não esperado é descartado, como o
    // `syncOfAsync` faz com o I/O que suspende num contexto síncrono.
    throw Panic(
      Golang.String.fromDart(
        'reflect: $op de função que suspende (cor `async`) num contexto síncrono',
      ),
    );
  }
  return _wrapResults(res, outs);
}

Slice<Value> _wrapResults(Object? res, List<RType> outs) => Slice<Value>.of([
  for (final (i, x) in _results(res, outs.length).indexed)
    Value._of(outs[i], x),
], $valueElem);

/// A closure do método [name] ligada ao receptor [v].
Function _bound(Value v, String name) {
  var t = v._t!;
  var r = v.$rep;
  if (t.$kind == kInterface) {
    if (r == null) {
      throw Panic(
        Golang.String.fromDart('reflect: Method on nil interface value'),
      );
    }
    final e = v.elem$();
    t = e._t!;
    r = e.$rep;
  }
  Function? f;
  if (t.$kind == kPointer && t.$name.isEmpty) {
    final e = t.$elem!;
    if (r == null) nilDeref();
    final pb = e.$pbinds[name];
    if (pb != null) {
      f = pb(r);
    } else {
      final b = e.$binds[name];
      if (b != null) f = b(e.$kind == kStruct ? r : (r as Ptr).value as Object);
    }
  } else {
    final b = t.$binds[name];
    if (b != null) f = b(r as Object);
  }
  return f ??
      (throw Panic(
        Golang.String.fromDart(
          'reflect: método $name de ${t.$str} sem descritor (g2d)',
        ),
      ));
}

/// Resultados de uma chamada Dart como lista: nenhum, um, ou um record.
List<Object?> _results(Object? r, int n) => switch (n) {
  0 => const [],
  1 => [r],
  2 => switch (r as (Object?, Object?)) {
    (final a, final b) => [a, b],
  },
  3 => switch (r as (Object?, Object?, Object?)) {
    (final a, final b, final c) => [a, b, c],
  },
  4 => switch (r as (Object?, Object?, Object?, Object?)) {
    (final a, final b, final c, final d) => [a, b, c, d],
  },
  5 => switch (r as (Object?, Object?, Object?, Object?, Object?)) {
    (final a, final b, final c, final d, final e) => [a, b, c, d, e],
  },
  _ => throw Panic(
    Golang.String.fromDart('reflect: Call com mais de 5 resultados'),
  ),
};
