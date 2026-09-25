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

/// `fmt.Sprint`: espaço entre operandos quando nenhum dos dois é string.
Golang.String sprint(Slice<Object?> args) {
  final a = args.items.toList();
  final b = BytesBuilder(copy: false);
  for (var i = 0; i < a.length; i++) {
    if (i > 0 && a[i] is! Golang.String && a[i - 1] is! Golang.String) {
      b.addByte(0x20);
    }
    _appendV(b, a[i]);
  }
  return Golang.String.fromBytes(b.takeBytes());
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
      final entries = m.entries.toList()
        ..sort((x, y) => _compareKeys(x.key, y.key));
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

/// Ordem do internal/fmtsort para chaves básicas: números por valor (NaN
/// antes), strings por bytes, false antes de true.
int _compareKeys(Object? a, Object? b) {
  if (a is Golang.Float64 && b is Golang.Float64) {
    return _compareFloat(a.toDouble(), b.toDouble());
  }
  if (a is Golang.Float32 && b is Golang.Float32) {
    return _compareFloat(a.toDouble(), b.toDouble());
  }
  if (a is bool && b is bool) return a == b ? 0 : (a ? 1 : -1);
  if (a is Comparable && b is Comparable) return a.compareTo(b);
  return 0; // ponytail: structs/ponteiros/interfaces ficam na ordem de inserção
}

int _compareFloat(double a, double b) {
  if (a.isNaN) return b.isNaN ? 0 : -1;
  if (b.isNaN) return 1;
  return a.compareTo(b);
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
