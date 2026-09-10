// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-ipld-prime's codec/raw/codec.go.
import 'dart:typed_data';

import 'package:transpiled_multicodec/transpiled_multicodec.dart';

import '../../datamodel/node.dart';
import '../../datamodel/node_builder.dart';
import '../../multicodec/registry.dart';

/// Registers raw (multicodec 0x55) in [registry].
void registerRawCodec([Registry? registry]) {
  final code = Multicodec.code('raw');
  (registry ?? defaultRegistry).registerEncoder(code, encode);
  (registry ?? defaultRegistry).registerDecoder(code, decode);
}

/// Decodes all bytes from [reader] into [assembler].
///
/// A [Uint8List] is assigned directly, matching the Go codec's no-copy
/// shortcut for readers which expose their backing bytes.
void decode(NodeAssembler assembler, Iterable<int> reader) {
  late final Uint8List data;
  try {
    data = reader is Uint8List
        ? reader
        : Uint8List.fromList(reader.toList(growable: false));
  } catch (error) {
    throw _RawDecodeException(error);
  }
  assembler.assignBytes(data);
}

/// Encodes the bytes represented by [node] into [writer].
void encode(Node node, Sink<List<int>> writer) => writer.add(node.asBytes());

final class _RawDecodeException implements Exception {
  const _RawDecodeException(this.cause);

  final Object cause;

  @override
  String toString() => 'could not decode raw node: $cause';
}
