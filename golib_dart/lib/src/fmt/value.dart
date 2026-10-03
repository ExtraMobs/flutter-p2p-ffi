part of '../../fmt.dart';

/// O método está no method set do operando? A classe Dart de uma
/// struct/array é a mesma para T e *T: [ptr] diz qual dos dois o operando é
/// (`String()` de `*T` não vale para `T`, como no Go). Os demais tipos têm
/// classes próprias para N e *N (`N$Ptr`), então o `is` já basta.
bool _hasMethod(Object v, String name, bool ptr) {
  if (v is GoValue) {
    return (ptr ? v.$ptrMethods : v.$valueMethods).contains(name);
  }
  return true;
}

/// Endereço de um valor com endereço no Go (ponteiro, slice, map, func), 0
/// para nil, ou null se v não tem endereço. ⚠️ Estável por objeto, não o
/// endereço do Go (que nem o Go reproduz entre execuções).
int? _pointerOf(Object? v) => switch (v) {
  NilPtr() => 0,
  PtrView(:final $p) when $p is NilPtr => 0,
  Ptr p => p.hashCode, // Box: identidade; ElemPtr/FieldPtr: dono + posição
  Addr(target: null) => 0,
  Addr(:final target) => identityHashCode(target),
  GoValue s when s.$nilPtr => 0,
  GoValue s when !s.$isValue => identityHashCode(s), // *T de struct/array
  Slice s => sliceAddr(s),
  GoMap m => m.isNil ? 0 : identityHashCode(m),
  Func(:final value) => value == null ? 0 : identityHashCode(value),
  Function f => identityHashCode(f),
  _ => null,
};

/// Hex do endereço na forma do Go (`c0` + 8 dígitos, como 0xc00000a0a8).
String _hexAddr(int a) =>
    a == 0 ? '0' : 'c0${(a & 0x7fffffff).toRadixString(16).padLeft(8, '0')}';

/// `%v` das folhas que o [_Printer] não formata por tipo: ponteiro para
/// não-struct e func (o endereço, como o Go) e o `toString` dos wrappers de
/// `fixed_types` (já formatam como o Go: floats com
/// `strconv.FormatFloat(x, 'g', -1, bits)`).
List<int> _leafV(Object v) {
  switch (v) {
    case NilPtr():
      return _ascii('<nil>');
    case Ptr() || Function() || Func():
      final a = _pointerOf(v)!;
      return _ascii(a == 0 ? '<nil>' : '0x${_hexAddr(a)}');
    case Golang.StringBase s:
      return s.toBytes();
    default:
      return utf8.encode(v.toString());
  }
}

/// `%v` de um único valor, como bytes.
Uint8List formatV(Object? v) =>
    (_Printer(const []).._printArg(v, 0x76, 0))._b.takeBytes();
