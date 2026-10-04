part of '../../../encoding/json.dart';

// As interfaces que o codec procura nos valores (`Marshaler`,
// `TextMarshaler`, `Unmarshaler`, `TextUnmarshaler`, `isZeroer`).
//
// A decisão é a do Go: o method set do descritor (`Type.Implements`). A
// chamada usa a classe da interface quando o objeto Dart a declara; senão
// chama o método pelo nome. O g2d só declara `implements` das interfaces
// alcançáveis pelo pacote do tipo (os imports diretos): um tipo com
// `MarshalText` num pacote que não importa `encoding` tem o método
// `marshalText` mas não `implements encoding.TextMarshaler`.

/// [x] (valor dinâmico de um `Value` cujo tipo [t] tem os [methods] no
/// method set) visto como X; null para interface nil.
X? _assertIface<X>(Object? x, List<String> methods, RType t) {
  if (x == null) return null;
  if (isIface<X>(x, methods)) return x as X;
  if (x is Ptr && x is! Golang.GoTyped) {
    // `*N` (N nomeado não-struct) tirado do reflect: um `go.Ptr` sem a vista
    // `N$Ptr`, que é quem tem os métodos de receptor ponteiro. Método de
    // receptor valor: o Go desreferencia, aqui também.
    final e = t.$kind == reflect.kPointer ? t.$elem! : null;
    if (e != null && methods.every(e.$methods.contains)) {
      return _assertIface<X>(x.value, methods, e);
    }
    throw Panic(
      _gs(
        'json: ${methods.first} de ${t.$str} inalcançável no Dart '
        '(receptor ponteiro de tipo nomeado não-struct via reflect; g2d)',
      ),
    );
  }
  return _dynamicIface<X>(x);
}

X _dynamicIface<X>(Object x) {
  final Object a;
  if (<X>[] is List<Marshaler>) {
    a = _DynMarshaler(x);
  } else if (<X>[] is List<encoding.TextMarshaler>) {
    a = _DynTextMarshaler(x);
  } else if (<X>[] is List<Unmarshaler>) {
    a = _DynUnmarshaler(x);
  } else {
    a = _DynTextUnmarshaler(x);
  }
  return a as X;
}

final class _DynMarshaler implements Marshaler {
  _DynMarshaler(this.x);
  final dynamic x;
  @override
  (_Bytes, GoError?) marshalJSON() => x.marshalJSON() as (_Bytes, GoError?);
}

final class _DynTextMarshaler implements encoding.TextMarshaler {
  _DynTextMarshaler(this.x);
  final dynamic x;
  @override
  (_Bytes, GoError?) marshalText() => x.marshalText() as (_Bytes, GoError?);
}

final class _DynUnmarshaler implements Unmarshaler {
  _DynUnmarshaler(this.x);
  final dynamic x;
  @override
  GoError? unmarshalJSON(_Bytes data) => x.unmarshalJSON(data) as GoError?;
}

final class _DynTextUnmarshaler implements encoding.TextUnmarshaler {
  _DynTextUnmarshaler(this.x);
  final dynamic x;
  @override
  GoError? unmarshalText(_Bytes text) => x.unmarshalText(text) as GoError?;
}
