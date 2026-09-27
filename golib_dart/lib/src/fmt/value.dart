part of '../../fmt.dart';

/// O método está no method set do valor impresso? Struct por valor (na
/// interface ou campo aninhado) só tem os de receptor valor: `String()` de
/// `*T` não vale para `T`, como no Go.
bool _hasMethod(Object v, String name, bool nested) {
  if (v is GoStruct) {
    return (nested || v.$isValue ? v.$valueMethods : v.$ptrMethods).contains(
      name,
    );
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
  Function f => identityHashCode(f),
  _ => null,
};

/// Hex do endereço na forma do Go (`c0` + 8 dígitos, como 0xc00000a0a8).
String _hexAddr(int a) =>
    a == 0 ? '0' : 'c0${(a & 0x7fffffff).toRadixString(16).padLeft(8, '0')}';

/// Formatação `%v` do Go. Os wrappers de `fixed_types` já formatam como o Go
/// no `toString` (floats: `strconv.FormatFloat(x, 'g', -1, bits)`).
void _appendV(BytesBuilder b, Object? v, {bool nested = false}) {
  switch (v) {
    case null:
      b.add(utf8.encode('<nil>'));
    // Ponteiro nil tipado: o fmt chama String()/Error() (o método pode
    // tratar nil); se ele entrar em panic, imprime <nil> (handleMethods).
    case GoValue s when s.$nilPtr:
      try {
        final Object o = s;
        if (o is Formatter) {
          final p = _Printer(const []);
          p._printArg(o, 0x76, nested ? 1 : 0);
          b.add(p._b.takeBytes());
        } else if (o is GoError) {
          b.add(o.error().toBytes());
        } else if (o is Stringer) {
          b.add(o.string().toBytes());
        } else {
          b.add(utf8.encode('<nil>'));
        }
      } catch (_) {
        b.add(utf8.encode('<nil>'));
      }
    case NilPtr():
      b.add(utf8.encode('<nil>'));
    // Como o fmt do Go: error, depois Stringer, antes da forma estrutural.
    case Formatter _ when _hasMethod(v, 'Format', nested):
      final p = _Printer(const []);
      p._printArg(v, 0x76, nested ? 1 : 0);
      b.add(p._b.takeBytes());
    case GoError e when _hasMethod(e, 'Error', nested):
      b.add(e.error().toBytes());
    case Stringer s when _hasMethod(s, 'String', nested):
      b.add(s.string().toBytes());
    case GoStruct s:
      // Ponteiro para struct no nível de topo: &{...}; aninhado ou por valor: {...}.
      if (!nested && !s.$isValue) b.addByte(0x26);
      b.addByte(0x7b);
      final fields = s.$fields;
      for (var i = 0; i < fields.length; i++) {
        if (i > 0) b.addByte(0x20);
        _appendV(b, fields[i], nested: true);
      }
      b.addByte(0x7d);
    case GoArray a:
      _appendList(b, a.items);
    case Slice s:
      _appendList(b, s.items);
    case GoMap m:
      // Go ordena as chaves ao imprimir (internal/fmtsort).
      // Ordenação estável: empates (ponteiros) ficam na ordem de inserção.
      final all = m.entries.toList();
      final entries = [
        for (final i
            in List.generate(all.length, (i) => i)..sort((x, y) {
              final c = m.identity ? 0 : _compareKeys(all[x].key, all[y].key);
              return c != 0 ? c : x - y;
            }))
          all[i],
      ];
      b.add(utf8.encode('map['));
      for (var i = 0; i < entries.length; i++) {
        if (i > 0) b.addByte(0x20);
        _appendV(b, entries[i].key, nested: true);
        b.addByte(0x3a); // :
        _appendV(b, entries[i].value, nested: true);
      }
      b.addByte(0x5d);
    case Addr(target: null):
      b.add(utf8.encode('<nil>'));
    case Addr(:final target) when !nested && target is GoStruct:
      b.addByte(0x26); // &{...} no nível de topo
      _appendV(b, target);
    case Addr(:final target):
      // Ponteiro aninhado: o Go imprime o endereço.
      b.add(utf8.encode('0x${_hexAddr(identityHashCode(target))}'));
    // *T (T não-struct) e func: o endereço, como o Go.
    case Ptr() || Function():
      final a = _pointerOf(v)!;
      b.add(utf8.encode(a == 0 ? '<nil>' : '0x${_hexAddr(a)}'));
    case Golang.StringBase s:
      b.add(s.toBytes());
    default:
      b.add(utf8.encode(v.toString()));
  }
}

/// `%v` de um único valor, como bytes.
Uint8List formatV(Object? v) {
  final b = BytesBuilder(copy: false);
  _appendV(b, v);
  return b.takeBytes();
}

void _appendList(BytesBuilder b, Iterable<Object?> items) {
  b.addByte(0x5b); // [
  var first = true;
  for (final e in items) {
    if (!first) b.addByte(0x20);
    first = false;
    _appendV(b, e, nested: true);
  }
  b.addByte(0x5d); // ]
}
