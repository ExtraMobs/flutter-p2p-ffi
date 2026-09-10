// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-ipld-prime/linking/cid/{linksystem,memorystorage}.go.
import 'dart:typed_data';

import 'package:transpiled_multicodec/transpiled_multicodec.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

import '../../datamodel/link.dart';
import '../../multicodec/registry.dart';
import '../linking.dart';
import 'cid_link.dart';

/// Creates a Cid-based link system using the default codec registry.
LinkSystem defaultLinkSystem() =>
    linkSystemUsingMulticodecRegistry(defaultRegistry);

/// Creates a Cid-based link system using [registry].
LinkSystem linkSystemUsingMulticodecRegistry(Registry registry) => LinkSystem(
  encoderChooser: (prototype) {
    if (prototype is! CidLinkPrototype) {
      throw ArgumentError(
        'this encoderChooser can only handle CidLinkPrototype',
      );
    }
    return registry.lookupEncoder(Multicodec.code(prototype.prefix.codec));
  },
  decoderChooser: (link) {
    final prototype = link.prototype();
    if (prototype is! CidLinkPrototype) {
      throw ArgumentError(
        'this decoderChooser can only handle CidLinkPrototype',
      );
    }
    return registry.lookupDecoder(Multicodec.code(prototype.prefix.codec));
  },
  hasherChooser: (prototype, bytes) {
    if (prototype is! CidLinkPrototype) {
      throw ArgumentError(
        'this hasherChooser can only handle CidLinkPrototype',
      );
    }
    return Uint8List.fromList(
      MultihashUtils.sum(prototype.prefix.mhType, bytes).digest,
    );
  },
);

/// In-memory storage keyed by multihash, like Go's `cidlink.Memory`.
final class Memory {
  /// Creates memory storage, optionally using [bag].
  Memory([Map<String, Uint8List>? bag]) : bag = bag ?? <String, Uint8List>{};

  /// Exposed backing map.
  final Map<String, Uint8List> bag;

  /// Opens [link] for reading.
  Iterable<int> openRead(LinkContext context, Link link) =>
      bag[_hashKey(_cidLink(link))] ?? (throw StateError('not found'));

  /// Opens a write which commits under the link multihash.
  (Sink<List<int>>, BlockWriteCommitter) openWrite(LinkContext context) {
    final buffer = _ByteSink();
    return (buffer, (link) => bag[_hashKey(_cidLink(link))] = buffer.bytes());
  }
}

CidLink _cidLink(Link link) => link is CidLink
    ? link
    : (throw ArgumentError('incompatible link type: ${link.runtimeType}'));

String _hashKey(CidLink link) =>
    String.fromCharCodes(link.cid.multihash.toBytes());

final class _ByteSink implements Sink<List<int>> {
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  @override
  void add(List<int> data) => _buffer.add(data);
  @override
  void close() {}
  Uint8List bytes() => _buffer.toBytes();
}
