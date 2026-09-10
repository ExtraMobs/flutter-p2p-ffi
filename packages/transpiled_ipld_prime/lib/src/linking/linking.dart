// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: duplicate_ignore, public_member_api_docs
// Port of go-ipld-prime/linking/{types,errors,functions,setup}.go.
import 'dart:typed_data';
import '../codec/api.dart';
import '../datamodel/link.dart';
import '../datamodel/node.dart';
import '../datamodel/node_builder.dart';
import '../datamodel/path.dart';
import '../storage/storage.dart' as storage;

typedef EncoderChooser = Encoder Function(LinkPrototype prototype);
typedef DecoderChooser = Decoder Function(Link link);
typedef HasherChooser =
    Uint8List Function(LinkPrototype prototype, Uint8List bytes);
typedef BlockReadOpener =
    Iterable<int> Function(LinkContext context, Link link);
typedef BlockWriteCommitter = void Function(Link link);
typedef BlockWriteOpener =
    (Sink<List<int>>, BlockWriteCommitter) Function(LinkContext context);
typedef NodeReifier =
    Node Function(LinkContext context, Node node, LinkSystem system);

final class LinkContext {
  const LinkContext({
    this.context,
    this.linkPath = Path.empty,
    this.linkNode,
    this.linkNodeAssembler,
    this.parentNode,
  });
  final Object? context;
  final Path linkPath;
  final Node? linkNode;
  final NodeAssembler? linkNodeAssembler;
  final Node? parentNode;
}

final class LinkingSetupException implements Exception {
  const LinkingSetupException(this.detail, this.cause);
  final String detail;
  final Object cause;
  @override
  String toString() => '$detail: $cause';
}

final class HashMismatchException implements Exception {
  const HashMismatchException(this.actual, this.expected);
  final Link actual;
  final Link expected;
  @override
  String toString() =>
      'hash mismatch!  $actual (actual) != $expected (expected)';
}

final class LinkSystem {
  LinkSystem({
    required this.encoderChooser,
    required this.decoderChooser,
    required this.hasherChooser,
    this.storageWriteOpener,
    this.storageReadOpener,
    this.trustedStorage = false,
    this.nodeReifier,
    Map<String, NodeReifier>? knownReifiers,
  }) : knownReifiers = knownReifiers ?? <String, NodeReifier>{};
  final EncoderChooser encoderChooser;
  final DecoderChooser decoderChooser;
  final HasherChooser hasherChooser;
  BlockWriteOpener? storageWriteOpener;
  BlockReadOpener? storageReadOpener;
  bool trustedStorage;
  NodeReifier? nodeReifier;
  Map<String, NodeReifier> knownReifiers;

  void setReadStorage(storage.ReadableStorage store) =>
      storageReadOpener = (context, link) =>
          storage.getStream(context.context, store, _key(link));
  void setWriteStorage(storage.WritableStorage store) =>
      storageWriteOpener = (context) {
        final (writer, commit) = storage.putStream(context.context, store);
        return (writer, (link) => commit(_key(link)));
      };

  Node load(LinkContext context, Link link, NodePrototype prototype) {
    final builder = prototype.newBuilder();
    fill(context, link, builder);
    final node = builder.build();
    return nodeReifier?.call(context, node, this) ?? node;
  }

  Node mustLoad(LinkContext context, Link link, NodePrototype prototype) =>
      load(context, link, prototype);

  (Node node, Uint8List raw) loadPlusRaw(
    LinkContext context,
    Link link,
    NodePrototype prototype,
  ) {
    final raw = loadRaw(context, link);
    final builder = prototype.newBuilder();
    decoderChooser(link)(builder, raw);
    final node = builder.build();
    return (nodeReifier?.call(context, node, this) ?? node, raw);
  }

  Uint8List loadRaw(LinkContext context, Link link) {
    final raw = _read(context, link);
    _verify(link, raw);
    return raw;
  }

  void fill(LinkContext context, Link link, NodeAssembler assembler) {
    final raw = _read(context, link);
    Object? decodeError;
    try {
      decoderChooser(link)(assembler, raw);
    } catch (error) {
      decodeError = error;
    }
    if (!trustedStorage) {
      _verify(link, raw);
    }
    if (decodeError != null) {
      throw decodeError;
    }
  }

  void mustFill(LinkContext context, Link link, NodeAssembler assembler) =>
      fill(context, link, assembler);

  Link store(LinkContext context, LinkPrototype prototype, Node node) {
    final opener = storageWriteOpener;
    if (opener == null) {
      throw LinkingSetupException(
        'no storage configured for writing',
        StateError('closed'),
      );
    }
    final (writer, commit) = opener(context);
    final raw = _encode(prototype, node);
    writer.add(raw);
    final link = prototype.buildLink(hasherChooser(prototype, raw));
    commit(link);
    return link;
  }

  Link mustStore(LinkContext context, LinkPrototype prototype, Node node) =>
      store(context, prototype, node);

  Link computeLink(LinkPrototype prototype, Node node) {
    final raw = _encode(prototype, node);
    return prototype.buildLink(hasherChooser(prototype, raw));
  }

  Link mustComputeLink(LinkPrototype prototype, Node node) =>
      computeLink(prototype, node);

  Uint8List _read(LinkContext context, Link link) {
    final opener = storageReadOpener;
    if (opener == null) {
      throw LinkingSetupException(
        'no storage configured for reading',
        StateError('closed'),
      );
    }
    return Uint8List.fromList(opener(context, link).toList(growable: false));
  }

  Uint8List _encode(LinkPrototype prototype, Node node) {
    final buffer = _ByteSink();
    encoderChooser(prototype)(node, buffer);
    return buffer.bytes();
  }

  void _verify(Link link, Uint8List raw) {
    final actual = link.prototype().buildLink(
      hasherChooser(link.prototype(), raw),
    );
    if (!_sameBytes(actual.binary(), link.binary())) {
      throw HashMismatchException(actual, link);
    }
  }
}

String _key(Link link) => String.fromCharCodes(link.binary());
bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

final class _ByteSink implements Sink<List<int>> {
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  @override
  void add(List<int> data) => _buffer.add(data);
  @override
  void close() {}
  Uint8List bytes() => _buffer.toBytes();
}
