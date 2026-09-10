// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-ipld-prime/codec/json.  This is ordinary JSON: IPLD links and
// bytes are intentionally rejected (unlike dag-json).
import 'dart:convert';

import 'package:transpiled_multicodec/transpiled_multicodec.dart';

import '../../datamodel/kind.dart';
import '../../datamodel/node.dart';
import '../../datamodel/node_builder.dart';
import '../../multicodec/registry.dart';

/// Registers ordinary JSON (multicodec 0x0200) in [registry].
void registerJsonCodec([Registry? registry]) {
  final code = Multicodec.code('json');
  (registry ?? defaultRegistry).registerEncoder(code, encode);
  (registry ?? defaultRegistry).registerDecoder(code, decode);
}

/// Decodes UTF-8 JSON from [reader] into [assembler].
void decode(NodeAssembler assembler, Iterable<int> reader) {
  final value = jsonDecode(utf8.decode(reader.toList(growable: false)));
  _assign(assembler, value);
}

/// Encodes [node] as indented JSON, matching the refmt encoder used by Go.
void encode(Node node, Sink<List<int>> writer) {
  final value = _jsonValue(node);
  writer.add(
    utf8.encode('${const JsonEncoder.withIndent('\t').convert(value)}\n'),
  );
}

void _assign(NodeAssembler assembler, Object? value) {
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
      for (final item in v) {
        _assign(list.assembleValue(), item);
      }
      list.finish();
    case Map<String, Object?> v:
      final map = assembler.beginMap(v.length);
      for (final entry in v.entries) {
        _assign(map.assembleEntry(entry.key), entry.value);
      }
      map.finish();
    default:
      throw FormatException('unsupported JSON value: ${value.runtimeType}');
  }
}

Object? _jsonValue(Node node) {
  switch (node.kind()) {
    case Kind.null_:
      return null;
    case Kind.bool_:
      return node.asBool();
    case Kind.int_:
      return node.asInt();
    case Kind.float:
      return node.asFloat();
    case Kind.string:
      return node.asString();
    case Kind.map:
      final result = <String, Object?>{};
      final iterator = node.mapIterator()!;
      while (!iterator.done()) {
        final (key, value) = iterator.next();
        result[key.asString()] = _jsonValue(value);
      }
      return result;
    case Kind.list:
      final result = <Object?>[];
      final iterator = node.listIterator()!;
      while (!iterator.done()) {
        result.add(_jsonValue(iterator.next().$2));
      }
      return result;
    case Kind.bytes:
      throw const JsonCodecException('cannot marshal IPLD bytes to this codec');
    case Kind.link:
      throw const JsonCodecException('cannot marshal IPLD links to this codec');
    case Kind.invalid:
      throw const JsonCodecException('cannot traverse a node that is absent');
  }
}

/// Error reported when a node cannot be represented by ordinary JSON.
final class JsonCodecException implements Exception {
  /// Creates an exception with the Go-compatible error [message].
  const JsonCodecException(this.message);

  /// The error text.
  final String message;

  @override
  String toString() => message;
}
