/// Shim do pacote Go `fmt`.
// ignore_for_file: library_prefixes
library;

import 'dart:convert';
import 'dart:typed_data';

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;
import 'src/runtime/output.dart';

/// `fmt.Stringer`.
abstract interface class Stringer {
  Golang.String string();
}

/// `fmt.Println`: operandos em `%v` separados por espaço, mais newline.
/// Escreve os bytes exatos (strings Go podem não ser UTF-8 válido).
(Golang.Int, GoError?) println(Slice<Object?> args) {
  final a = args.items.toList();
  final b = BytesBuilder(copy: false);
  for (var i = 0; i < a.length; i++) {
    if (i > 0) b.addByte(0x20);
    _appendV(b, a[i]);
  }
  b.addByte(0x0a);
  final bytes = b.takeBytes();
  writeStdout(bytes);
  return (Golang.Int(bytes.length), null);
}

/// `fmt.Print`: como [sprint], escrito na saída padrão.
(Golang.Int, GoError?) print(Slice<Object?> args) {
  final bytes = _sprint(args);
  writeStdout(bytes);
  return (Golang.Int(bytes.length), null);
}

/// `fmt.Sprint`: espaço entre operandos quando nenhum dos dois é string.
Golang.String sprint(Slice<Object?> args) =>
    Golang.String.fromBytes(_sprint(args));

Uint8List _sprint(Slice<Object?> args) {
  final a = args.items.toList();
  final b = BytesBuilder(copy: false);
  for (var i = 0; i < a.length; i++) {
    if (i > 0 && a[i] is! Golang.String && a[i - 1] is! Golang.String) {
      b.addByte(0x20);
    }
    _appendV(b, a[i]);
  }
  return b.takeBytes();
}

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
        if (o is GoError) {
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
    case GoError e:
      b.add(e.error().toBytes());
    case Stringer s:
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
      b.add(utf8.encode('0x${identityHashCode(target).toRadixString(16)}'));
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

/// Ordem do internal/fmtsort.compare: nil primeiro; números por valor (NaN
/// antes); strings por bytes; false antes de true; complex pela parte real e
/// depois a imaginária; structs e arrays campo a campo.
///
/// Dois casos o Go ordena por endereço de memória, que não é reproduzível:
/// ponteiros (aqui empatam e ficam na ordem de inserção, que costuma ser a
/// de alocação) e o tipo dinâmico de chaves interface de tipos diferentes.
int _compareKeys(Object? a, Object? b) {
  if (a == null || b == null) return a == null ? (b == null ? 0 : -1) : 1;
  final ta = _keyType(a), tb = _keyType(b);
  // Limite (⚠️ em docs/mapping-spec.md): o Go compara os endereços dos
  // descritores de tipo, que seguem o layout do linker (nomeados de main,
  // depois string, int8, int64, int, uint, ... no gc 1.25) e mudam com os
  // pacotes linkados; o nome do tipo só dá uma ordem determinística.
  if (ta != tb) return ta.compareTo(tb);
  switch ((a, b)) {
    case (GoValue($nilPtr: true), _) || (_, GoValue($nilPtr: true)):
      return 0;
    case (final bool x, final bool y):
      return x == y ? 0 : (x ? 1 : -1);
    case (final Golang.Complex128 x, final Golang.Complex128 y):
      final c = x.real.compareTo(y.real);
      return c != 0 ? c : x.imag.compareTo(y.imag);
    case (final Golang.Complex64 x, final Golang.Complex64 y):
      final c = x.real.compareTo(y.real);
      return c != 0 ? c : x.imag.compareTo(y.imag);
    case (final GoStruct x, final GoStruct y):
      return _compareAll(x.$fields, y.$fields);
    case (final GoArray x, final GoArray y):
      return _compareAll(x.items, y.items);
    case (final Comparable x, final Comparable y):
      return x.compareTo(y);
  }
  return 0; // ponteiros (Addr, Ptr): ordem de inserção
}

int _compareAll(Iterable<Object?> a, Iterable<Object?> b) {
  final ib = b.iterator;
  for (final x in a) {
    ib.moveNext();
    final c = _compareKeys(x, ib.current);
    if (c != 0) return c;
  }
  return 0;
}

String _keyType(Object k) => switch (k) {
  Golang.GoTyped t => t.$goType,
  bool() => 'bool',
  Golang.Complex128() => 'complex128',
  Golang.Complex64() => 'complex64',
  _ => '',
};

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
