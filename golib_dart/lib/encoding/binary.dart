/// Shim do pacote Go `encoding/binary`: `LittleEndian`/`BigEndian`/
/// `NativeEndian`, varints e `Read`/`Write` sobre valores de tamanho fixo
/// (sem reflexão: ponteiro, slice e array de inteiros, floats e bool; struct
/// no `Write`).
// ignore_for_file: library_prefixes
library;

import 'dart:typed_data';

import '../builtin.dart';
import '../fixed_types/golang.dart' as Golang;
import '../fmt.dart' as fmt;
import '../io.dart' as io;

part '../src/encoding/binary/byte_order.dart';
part '../src/encoding/binary/varint.dart';
part '../src/encoding/binary/codec.dart';

typedef _Bytes = Slice<Golang.Uint8>;
