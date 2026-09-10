// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: duplicate_ignore, public_member_api_docs
// Port of go-ipld-prime/storage/memstore/memstore.go.
import 'dart:typed_data';
import 'storage.dart';

final class MemoryStore
    implements
        ReadableStorage,
        WritableStorage,
        StreamingReadableStorage,
        PeekableStorage {
  MemoryStore([Map<String, Uint8List>? bag])
    : bag = bag ?? <String, Uint8List>{};
  final Map<String, Uint8List> bag;
  @override
  bool has(Object? context, String key) => bag.containsKey(key);
  @override
  Uint8List get(Object? context, String key) => Uint8List.fromList(_value(key));
  @override
  Iterable<int> getStream(Object? context, String key) => _value(key);
  @override
  Uint8List peek(Object? context, String key) => _value(key);
  @override
  void put(Object? context, String key, Uint8List content) =>
      bag.putIfAbsent(key, () => Uint8List.fromList(content));
  Uint8List _value(String key) => bag[key] ?? (throw StateError('404'));
}
