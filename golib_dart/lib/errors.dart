/// Shim do pacote Go `errors` (porta de `errors/wrap.go` e `join.go` do Go
/// 1.26).
///
/// A cadeia de erros é percorrida pelas interfaces do runtime que o g2d
/// declara em todo tipo com o método correspondente (`go.Unwrapper`,
/// `go.MultiUnwrapper`, `go.ErrorIs`, `go.ErrorAs`), respeitando o method
/// set do valor dinâmico (`go.goHasMethod`).
// ignore_for_file: library_prefixes
library;

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;

/// `errors.New(text)`: um `*errorString` novo; dois `New` com o mesmo texto
/// são erros diferentes (identidade, como o ponteiro do Go).
GoError new$(Golang.String text) => ErrorString(text);

/// `errors.ErrUnsupported`.
final GoError errUnsupported = ErrorString(
  Golang.String.fromDart('unsupported operation'),
);

Never _panic(String s) => throw Panic(Golang.String.fromDart(s));

GoError? _unwrap1(Object err) => switch (err) {
  Unwrapper u when goHasMethod(u, 'Unwrap') => u.unwrap(),
  _ => null,
};

Slice<GoError?>? _unwrapN(Object err) => switch (err) {
  MultiUnwrapper m when goHasMethod(m, 'Unwrap') => m.unwrap(),
  _ => null,
};

bool _unwraps1(Object err) => err is Unwrapper && goHasMethod(err, 'Unwrap');

/// `errors.Unwrap(err)`: só `Unwrap() error` (não `[]error`).
GoError? unwrap(GoError? err) => err == null ? null : _unwrap1(err);

/// `errors.Is(err, target)`.
bool is$(GoError? err, GoError? target) {
  if (err == null || target == null) return identical(err, target);
  return _is(err, target, goComparable(target));
}

bool _is(GoError? err, GoError target, bool targetComparable) {
  for (;;) {
    if (err == null) return false;
    if (targetComparable && ifaceEq(err, target)) return true;
    if (err case final ErrorIs x when goHasMethod(x, 'Is') && x.is$(target)) {
      return true;
    }
    if (_unwraps1(err)) {
      err = _unwrap1(err);
      continue;
    }
    final many = _unwrapN(err);
    if (many != null) {
      for (final e in many.items) {
        if (_is(e, target, targetComparable)) return true;
      }
    }
    return false;
  }
}

/// `errors.As(err, target)`: target é `&v` (um `go.Ptr`, ou a própria struct
/// quando v é struct por valor).
bool as(GoError? err, Object? target) {
  if (err == null) return false;
  if (target == null) _panic('errors: target cannot be nil');
  if (target is NilPtr || (target is GoValue && target.$nilPtr)) {
    _panic('errors: target must be a non-nil pointer');
  }
  if (target is! Ptr && target is! GoValue) {
    _panic('errors: target must be a non-nil pointer');
  }
  final ok = target is Ptr ? target.$errorTargetOk() : target is GoError;
  if (!ok) _panic('errors: *target must be interface or implement error');
  return _as(err, target);
}

bool _assign(GoError err, Object target) {
  if (target is Ptr) return target.$assignIfIs(err);
  // `var v S; errors.As(err, &v)`: a struct é o próprio endereço.
  final t = target as GoValue;
  final Object e = err;
  if (e is GoValue && e.$isValue && e.runtimeType == t.runtimeType) {
    (t as dynamic).$set(err);
    return true;
  }
  return false;
}

bool _as(GoError? err, Object target) {
  for (;;) {
    if (err == null) return false;
    if (_assign(err, target)) return true;
    if (err case final ErrorAs x when goHasMethod(x, 'As') && x.as(target)) {
      return true;
    }
    if (_unwraps1(err)) {
      err = _unwrap1(err);
      continue;
    }
    final many = _unwrapN(err);
    if (many != null) {
      for (final e in many.items) {
        if (e != null && _as(e, target)) return true;
      }
    }
    return false;
  }
}

// `err.(E)` com E do dicionário: ponteiro para struct (zero nil, 8 bytes)
// não aceita struct por valor; interface (16 bytes) e valores aceitam `is E`.
bool _isE<E>(Elem<E> e, GoError err) {
  final Object v = err;
  if (v is! E) return false;
  final value = v is GoValue && v.$isValue;
  if (e.zero() == null && e.size == 8) return !value; // ponteiro
  if (e.zero() is GoValue) return value; // struct/array por valor
  return true;
}

/// `errors.AsType[E](err)` (Go 1.26).
(E, bool) asType<E>(Elem<E> $E, GoError? err) {
  if (err == null) return ($E.zero(), false);
  Box<E>? pe;
  (E, bool) walk(GoError? err) {
    for (;;) {
      if (err == null) return ($E.zero(), false);
      if (_isE($E, err)) return (err as E, true);
      if (err case final ErrorAs x when goHasMethod(x, 'As')) {
        final box = pe ??= Box<E>($E.zero());
        if (x.as(box)) return (box.value, true);
      }
      if (_unwraps1(err)) {
        err = _unwrap1(err);
        continue;
      }
      final many = _unwrapN(err);
      if (many != null) {
        for (final e in many.items) {
          if (e == null) continue;
          final r = walk(e);
          if (r.$2) return r;
        }
      }
      return ($E.zero(), false);
    }
  }

  return walk(err);
}

/// `errors.Join(errs...)`: nil se todos forem nil.
GoError? join(Slice<GoError?> errs) {
  final kept = [
    for (final e in errs.items)
      if (e != null) e,
  ];
  return kept.isEmpty ? null : JoinError(kept);
}
