// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-ipld-prime/codec/cbor.
import '../../datamodel/node.dart';
import '../../datamodel/node_builder.dart';
import '../../multicodec/registry.dart';
import '../dagcbor/codec.dart' as dagcbor;

/// Registers standard CBOR (multicodec 0x51) in [registry].
void registerCborCodec([Registry? registry]) {
  final target = registry ?? defaultRegistry;
  target.registerEncoder(0x51, encode);
  target.registerDecoder(0x51, decode);
}

/// Decodes standard CBOR bytes from [r] into [na], rejecting IPLD links.
void decode(NodeAssembler na, Iterable<int> r) {
  const dagcbor.DecodeOptions(allowLinks: false).decode(na, r);
}

/// Alias for [decode] specific to CBOR.
void decodeCbor(NodeAssembler na, Iterable<int> r) => decode(na, r);

/// Encodes [n] as standard CBOR into [w], rejecting IPLD links.
void encode(Node n, Sink<List<int>> w) {
  const dagcbor.EncodeOptions(allowLinks: false).encode(n, w);
}

/// Alias for [encode] specific to CBOR.
void encodeCbor(Node n, Sink<List<int>> w) => encode(n, w);
