part of '../../reflect.dart';

/// Tipo dinâmico do valor [x] guardado numa interface (null: interface nil).
///
/// - classes geradas e tipos de shim com descritor: [Typed] (uma struct
///   guardada por referência, sem `$isValue`, é `*T`);
/// - básicos: as classes fixas de `Golang.*` e o `bool` nativo;
/// - `[]T`, `map[K]V`, `[N]T` sem nome: pelo `go.Elem` do elemento;
/// - `*T` de não-struct: o T reificado do `go.Ptr`;
/// - o resto (shim sem descritor, genérico): um descritor opaco pelo nome Go.
RType? rtypeOf(Object? x) {
  x = unShim(x); // valor de shim numa interface gerada (D8)
  switch (x) {
    case null:
      return null;
    case bool():
      return rtBool;
    case Typed t:
      return t is GoValue && !(t as GoValue).$isValue
          ? t.$rtype.ptrTo()
          : t.$rtype;
    case Func f:
      return f.type != null ? f.type!() as RType : rtFunc(f.sig);
    case Golang.String():
      return rtString;
    case Golang.Int():
      return rtInt;
    case Golang.Int8():
      return rtInt8;
    case Golang.Int16():
      return rtInt16;
    case Golang.Int32():
      return rtInt32;
    case Golang.Int64():
      return rtInt64;
    case Golang.Uint():
      return rtUint;
    case Golang.Uint8():
      return rtUint8;
    case Golang.Uint16():
      return rtUint16;
    case Golang.Uint32():
      return rtUint32;
    case Golang.Uint64():
      return rtUint64;
    case Golang.Uintptr():
      return rtUintptr;
    case Golang.Float32():
      return rtFloat32;
    case Golang.Float64():
      return rtFloat64;
    case Golang.Complex64():
      return rtComplex64;
    case Golang.Complex128():
      return rtComplex128;
    case Slice s:
      return _elemType(s.elem).sliceOf();
    case GoMap m:
      return rtMap(_mapKeyType(m), _elemType(m.elem));
    case GoArray a:
      final t = _elemType(a.elem).arrayOf(a.length);
      return a.$isValue ? t : t.ptrTo();
    case NilPtr p when p.elem != null:
      return _elemType(p.elem!).ptrTo();
    case NilPtr p:
      return p.$withElem(<E>() => _typeFor<E>(null)).ptrTo();
    case Box p when p.elem != null:
      return _elemType(p.elem!).ptrTo();
    case Ptr p:
      return p.$withElem(<E>() => _typeFor<E>(p as Ptr<E>)).ptrTo();
    case EmptyStruct e:
      return e.$isValue ? rtEmptyStruct : rtEmptyStruct.ptrTo();
    case GoValue v:
      final t = rtOpaque(
        v.$goType.replaceFirst('*', ''),
        kStruct,
        methods: v.$valueMethods,
        ptrMethods: v.$ptrMethods,
      );
      return v.$isValue ? t : t.ptrTo();
    case GoError e when e is! Golang.GoTyped:
      return rtOpaque(e.runtimeType.toString(), kPointer);
    case Golang.GoTyped g when g.$goType.startsWith('*'):
      final t = rtOpaque(
        g.$goType.substring(1),
        kStruct,
        ptrMethods: g.$methods,
      );
      return t.ptrTo();
    case Golang.GoTyped g:
      return rtOpaque(g.$goType, _kindOfRep(g), methods: g.$methods);
    case Chan c:
      return c
          .$with(<E>() => _typeFor<E>(null, () => (c as Chan<E>).zero))
          .chanOf(3);
    case Function():
      return rtFunc('func()');
  }
  throw Panic(
    Golang.String.fromDart('reflect: tipo sem descritor: ${x.runtimeType}'),
  );
}

/// `struct {}`.
final rtEmptyStruct = rtStruct<EmptyStruct>(
  '',
  '',
  'struct {}',
  size: 0,
  align: 1,
  zero: EmptyStruct.new,
  fields: () => const [],
  nil: () => EmptyStruct.$nil,
);

int _kindOfRep(Object x) => switch (x) {
  Golang.IntBase n => n.$signed ? kInt64 : kUint64,
  Golang.FloatBase() => kFloat64,
  Golang.StringBase() => kString,
  GoBool() => kBool,
  Slice() => kSlice,
  GoMap() => kMap,
  GoArray() => kArray,
  _ => kStruct,
};

/// Representação Dart guardada num `reflect.Value` para o valor [x] de uma
/// interface: struct/array por valor fica como está (a cópia `$isValue`);
/// sentinelas de ponteiro nil viram null; `go.Func` vira a closure.
Object? $repOf(Object? x) => switch (unShim(x)) {
  GoValue v when v.$nilPtr => null,
  NilPtr() => null,
  Func f => f.value,
  final y => y,
};

/// Descritor de T a partir do dicionário `go.Elem<T>` de um genérico.
RType rtOfElem(Elem e) => _elemType(e);

/// Descritor do elemento de um `go.Elem` (o `type` gerado; sem ele, pelo T
/// reificado ou pelo zero value).
RType _elemType(Elem e) {
  final t = e.type;
  if (t != null) return t() as RType;
  return e.$with(<E>() => _typeFor<E>(null, (e as Elem<E>).zero));
}

/// Descritor da chave de um map.
RType _mapKeyType(GoMap m) {
  final k = m.$key;
  if (k != null) return _elemType(k);
  return m.$withKV(<K, V>() {
    for (final key in m.keysSnapshot()) {
      final t = _typeOfRep<K>(key);
      if (t != null) return t;
    }
    return _typeFor<K>(null);
  });
}

/// Descritor do T do Dart (o tipo apontado por um `go.Ptr<T>`, o elemento
/// de um `go.Elem<T>`): básicos e `any`/`error` pelo próprio T; os demais
/// por um valor (o apontado, ou o zero value).
RType _typeFor<T>(Ptr<T>? p, [T Function()? zero]) {
  final b = _basicFor<T>();
  if (b != null) return b;
  if (null is! T) {
    final v = p != null ? p.value : zero?.call();
    final t = v == null ? null : _typeOfRep<T>(v);
    if (t != null) return t;
  }
  throw Panic(
    Golang.String.fromDart(
      'reflect: tipo sem descritor: $T (o g2d gera descritores só num grafo que usa reflexão)',
    ),
  );
}

/// Descritor de um valor de T (não interface): a struct/array é T, não `*T`.
RType? _typeOfRep<T>(Object? v) {
  if (v is Typed) return v.$rtype;
  if (v is EmptyStruct) return rtEmptyStruct;
  return rtypeOf(v);
}

bool _exact<A, B>() => <A>[] is List<B> && <B>[] is List<A>;

RType? _basicFor<T>() {
  if (_exact<T, bool>()) return rtBool;
  if (_exact<T, Golang.String>()) return rtString;
  if (_exact<T, Golang.Int>()) return rtInt;
  if (_exact<T, Golang.Int8>()) return rtInt8;
  if (_exact<T, Golang.Int16>()) return rtInt16;
  if (_exact<T, Golang.Int32>()) return rtInt32;
  if (_exact<T, Golang.Int64>()) return rtInt64;
  if (_exact<T, Golang.Uint>()) return rtUint;
  if (_exact<T, Golang.Uint8>()) return rtUint8;
  if (_exact<T, Golang.Uint16>()) return rtUint16;
  if (_exact<T, Golang.Uint32>()) return rtUint32;
  if (_exact<T, Golang.Uint64>()) return rtUint64;
  if (_exact<T, Golang.Uintptr>()) return rtUintptr;
  if (_exact<T, Golang.Float32>()) return rtFloat32;
  if (_exact<T, Golang.Float64>()) return rtFloat64;
  if (_exact<T, Golang.Complex64>()) return rtComplex64;
  if (_exact<T, Golang.Complex128>()) return rtComplex128;
  if (_exact<T, Object?>()) return rtAny;
  if (_exact<T, GoError?>()) return rtError;
  return null;
}
