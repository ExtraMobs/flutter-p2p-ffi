/// Tipos e funções do universo Go (importado como `go` pelo código gerado;
/// `go` é palavra-chave em Go, então o prefixo nunca colide).
// ignore_for_file: library_prefixes
library;

import 'dart:typed_data';

import 'fixed_types/golang.dart' as Golang;

import 'src/runtime/elem.dart';
import 'src/runtime/panic.dart';
import 'src/runtime/slice.dart';

export 'src/runtime/array.dart';
export 'src/runtime/async_fn.dart';
export 'src/runtime/chan.dart';
export 'src/runtime/defer.dart';
export 'src/runtime/elem.dart';
export 'src/runtime/errors.dart';
export 'src/runtime/iface.dart';
export 'src/runtime/map.dart';
export 'src/runtime/named_bool.dart';
export 'src/runtime/order.dart';
export 'src/runtime/panic.dart';
export 'src/runtime/ptr.dart';
export 'src/runtime/sched.dart';
export 'src/runtime/select.dart';
export 'src/runtime/slice.dart';
export 'src/runtime/struct.dart';
export 'src/runtime/tag.dart';
// Descritores de reflexão (M5): o código gerado os constrói sem importar o
// shim `reflect`.
export 'reflect.dart'
    show
        RType,
        RField,
        Typed,
        rtBool,
        rtInt,
        rtInt8,
        rtInt16,
        rtInt32,
        rtInt64,
        rtUint,
        rtUint8,
        rtUint16,
        rtUint32,
        rtUint64,
        rtUintptr,
        rtFloat32,
        rtFloat64,
        rtComplex64,
        rtComplex128,
        rtString,
        rtUnsafePointer,
        rtAny,
        rtError,
        rtPtr,
        rtSlice,
        rtArray,
        rtMap,
        rtChan,
        rtFunc,
        rtIface,
        rtNamedIface,
        rtStruct,
        rtNamed,
        rtField,
        rtOpaque,
        rtGeneric,
        rtEmptyStruct,
        rtOfElem,
        kInvalid,
        kBool,
        kInt,
        kInt8,
        kInt16,
        kInt32,
        kInt64,
        kUint,
        kUint8,
        kUint16,
        kUint32,
        kUint64,
        kUintptr,
        kFloat32,
        kFloat64,
        kComplex64,
        kComplex128,
        kArray,
        kChan,
        kFunc,
        kInterface,
        kMap,
        kPointer,
        kSlice,
        kString,
        kStruct,
        kUnsafePointer;

/// Constante string Go que não é UTF-8 válido (bytes exatos).
Golang.String stringOfBytes(List<int> bytes) =>
    Golang.String.fromBytes(Uint8List.fromList(bytes));

/// `[]byte(s)`: cópia independente dos bytes.
Slice<Golang.Uint8> bytesOf(Golang.String s, Elem<Golang.Uint8> elem) =>
    Slice.of([for (final b in s.toBytes()) Golang.Uint8(b)], elem);

/// `string(b)` com b `[]byte`: bytes copiados sem validar UTF-8.
Golang.String stringOfByteSlice(Slice<Golang.Uint8> b) =>
    Golang.String.fromBytes(
      Uint8List.fromList([for (final x in b.items) x.toInt()]),
    );

/// `[]rune(s)`: decodificação UTF-8 do Go (inválido vira U+FFFD).
Slice<Golang.Rune> runesOf(Golang.String s, Elem<Golang.Rune> elem) =>
    Slice.of([for (final r in s.runes()) Golang.Rune(r)], elem);

/// `string(rs)` com rs `[]rune`.
Golang.String stringOfRunes(Slice<Golang.Rune> rs) =>
    Golang.String.fromRunes([for (final r in rs.items) r.toInt()]);

/// Contagem de shift com tipo inteiro Go → `int` Dart. Negativa: panic
/// (spec Go). Qualquer contagem >= 64 dá o mesmo resultado; satura para caber.
int shiftCount(Golang.IntBase count) {
  if (count.$signed && count.$hi >= 0x80000000) {
    throw Panic(const RuntimeError('runtime error: negative shift amount'));
  }
  return count.$hi != 0 || count.$lo > 64 ? 64 : count.$lo;
}
