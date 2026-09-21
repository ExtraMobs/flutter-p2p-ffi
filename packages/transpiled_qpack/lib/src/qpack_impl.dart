/// Library grouping for the Dart port of the Go package `qpack`
/// (github.com/quic-go/qpack, commit
/// c415cad59091662a20b7b1c4505fbb177dbda0e3).
///
/// Go's unexported (lowercase) package-level symbols are visible to every
/// file within the same package. Dart's equivalent unit of shared privacy
/// is the library, not the file, so this file plus its `part`s reproduce
/// that boundary: [_appendVarInt], [_readVarInt], the static table, the
/// encoder map and the Huffman codec all stay `_`-prefixed and private to
/// this library, exactly as they are unexported in Go, while still being
/// shared between the encoder and decoder implementation files.
library;

import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;

import 'header_field.dart';

part 'varint.dart';
part 'static_table.dart';
part 'huffman.dart';
part 'encoder.dart';
part 'decoder.dart';
