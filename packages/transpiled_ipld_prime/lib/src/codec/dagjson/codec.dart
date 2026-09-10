// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: duplicate_ignore, public_member_api_docs

import 'dart:convert';
import 'dart:typed_data';

import 'package:transpiled_cid/transpiled_cid.dart';

import '../../datamodel/kind.dart';
import '../../datamodel/node.dart';
import '../../datamodel/node_builder.dart';
import '../../linking/cid/cid_link.dart';
import '../../multicodec/registry.dart';

/// Encoding options matching go-ipld-prime's dagjson.EncodeOptions.
final class DagJsonEncodeOptions {
  const DagJsonEncodeOptions({
    this.encodeLinks = true,
    this.encodeBytes = true,
    this.sortMaps = true,
  });
  final bool encodeLinks;
  final bool encodeBytes;
  final bool sortMaps;
}

/// Registers DAG-JSON (multicodec 0x0129) in [registry].
void registerDagJsonCodec([Registry? registry]) {
  final target = registry ?? defaultRegistry;
  target.registerEncoder(0x0129, encodeDagJson);
  target.registerDecoder(0x0129, decodeDagJson);
}

/// Encode an IPLD node using the default DAG-JSON representation.
void encodeDagJson(Node node, Sink<List<int>> writer) {
  encodeDagJsonWithOptions(node, writer, const DagJsonEncodeOptions());
}

/// Encode an IPLD node with explicit DAG-JSON options.
void encodeDagJsonWithOptions(
  Node node,
  Sink<List<int>> writer,
  DagJsonEncodeOptions options,
) {
  writer.add(utf8.encode(jsonEncode(_value(node, options: options))));
}

/// Decode a DAG-JSON value into an assembler.
void decodeDagJson(NodeAssembler assembler, Iterable<int> reader) {
  decodeDagJsonWithOptions(assembler, reader, const DagJsonDecodeOptions());
}

final class DagJsonDecodeOptions {
  const DagJsonDecodeOptions({
    this.parseLinks = true,
    this.parseBytes = true,
    this.maxDepth = 0,
  });
  final bool parseLinks;
  final bool parseBytes;
  final int maxDepth;
}

void decodeDagJsonWithOptions(
  NodeAssembler assembler,
  Iterable<int> reader,
  DagJsonDecodeOptions options,
) {
  _assign(
    assembler,
    jsonDecode(utf8.decode(reader.toList(growable: false))),
    options: options,
  );
}

Object? _value(
  Node node, {
  DagJsonEncodeOptions options = const DagJsonEncodeOptions(),
}) => switch (node.kind()) {
  Kind.null_ => null,
  Kind.bool_ => node.asBool(),
  Kind.int_ => node.asInt(),
  Kind.float => node.asFloat(),
  Kind.string => node.asString(),
  Kind.bytes =>
    options.encodeBytes
        ? {
            '/': {'bytes': base64Encode(node.asBytes()).replaceAll('=', '')},
          }
        : throw const FormatException(
            'cannot marshal IPLD bytes to this codec',
          ),
  Kind.link =>
    options.encodeLinks
        ? {'/': node.asLink().toString()}
        : throw const FormatException(
            'cannot marshal IPLD links to this codec',
          ),
  Kind.map => {
    for (final entry
        in (_entries(node).toList()..sort(
          (a, b) =>
              options.sortMaps ? a.$1.asString().compareTo(b.$1.asString()) : 0,
        )))
      entry.$1.asString(): _value(entry.$2, options: options),
  },
  Kind.list => [
    for (final value in _values(node)) _value(value, options: options),
  ],
  Kind.invalid => throw const FormatException('cannot encode absent node'),
};

Iterable<(Node, Node)> _entries(Node node) sync* {
  final iterator = node.mapIterator()!;
  while (!iterator.done()) yield iterator.next();
}

Iterable<Node> _values(Node node) sync* {
  final iterator = node.listIterator()!;
  while (!iterator.done()) yield iterator.next().$2;
}

void _assign(
  NodeAssembler assembler,
  Object? value, {
  required DagJsonDecodeOptions options,
  int depth = 0,
}) {
  if (options.maxDepth > 0 && depth > options.maxDepth) {
    throw const FormatException('dag-json maximum depth exceeded');
  }
  switch (value) {
    case null:
      assembler.assignNull();
    case bool v:
      assembler.assignBool(v);
    case int v:
      assembler.assignInt(v);
    case double v:
      assembler.assignFloat(v);
    case String v:
      assembler.assignString(v);
    case List<Object?> v:
      final list = assembler.beginList(v.length);
      for (final item in v)
        _assign(list.assembleValue(), item, options: options, depth: depth + 1);
      list.finish();
    case Map<String, Object?> v
        when v.length == 1 && v.containsKey('/') && v['/'] is Map:
      final bytes = (v['/']! as Map)['bytes'];
      if (bytes is! String)
        throw const FormatException('invalid DAG-JSON bytes');
      if (!options.parseBytes)
        throw const FormatException('DAG-JSON bytes disabled');
      assembler.assignBytes(
        Uint8List.fromList(
          base64Decode(bytes.padRight((bytes.length + 3) ~/ 4 * 4, '=')),
        ),
      );
    case Map<String, Object?> v when v.length == 1 && v.containsKey('/'):
      final marker = v['/'];
      if (marker is! String)
        throw const FormatException('invalid DAG-JSON link');
      if (!options.parseLinks && !marker.startsWith('base64')) {
        throw const FormatException('DAG-JSON links disabled');
      }
      if (marker.startsWith('base64')) {
        assembler.assignBytes(
          Uint8List.fromList(base64Decode(marker.substring(6))),
        );
      } else {
        assembler.assignLink(CidLink(Cid.decode(marker)));
      }
    case Map<String, Object?> v:
      final map = assembler.beginMap(v.length);
      for (final entry in v.entries)
        _assign(
          map.assembleEntry(entry.key),
          entry.value,
          options: options,
          depth: depth + 1,
        );
      map.finish();
    default:
      throw const FormatException('unsupported DAG-JSON value');
  }
}
