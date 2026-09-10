// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/basicnode/stream_bytes.dart
//
// Port of go-ipld-prime's node/basicnode/bytes_stream.go: a bytes-kind
// Node backed by a seekable stream instead of an in-memory Uint8List,
// avoiding a large up-front allocation.
import 'dart:typed_data';

import '../datamodel/kind.dart';
import '../datamodel/node.dart';
import 'base_node.dart';
import 'scalars.dart' show PrototypeBytes;


/// A bytes-kind [Node] backed by a [ByteReadSeeker]. Equivalent to
/// go-ipld-prime's `streamBytes`.
class StreamBytes extends BaseNode implements LargeBytesNode {
  /// Creates the node.
  const StreamBytes(this._reader);

  final ByteReadSeeker _reader;

  @override
  String get typeName => 'bytes';
  @override
  Kind kind() => Kind.bytes;
  @override
  ByteReadSeeker asLargeBytes() => _reader;

  @override
  Uint8List asBytes() {
    _reader.seek(0, SeekOrigin.start);
    final chunks = <int>[];
    final buffer = Uint8List(4096);
    while (true) {
      final n = _reader.read(buffer);
      if (n <= 0) break;
      chunks.addAll(buffer.sublist(0, n));
    }
    return Uint8List.fromList(chunks);
  }

  @override
  NodePrototype prototype() => const PrototypeBytes();
}
