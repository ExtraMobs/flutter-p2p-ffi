// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: duplicate_ignore, public_member_api_docs
// Port of go-ipld-prime/storage/{api,funcs}.go.
import 'dart:typed_data';

abstract interface class Storage {
  bool has(Object? context, String key);
}

abstract interface class ReadableStorage implements Storage {
  Uint8List get(Object? context, String key);
}

abstract interface class WritableStorage implements Storage {
  void put(Object? context, String key, Uint8List content);
}

abstract interface class StreamingReadableStorage {
  Iterable<int> getStream(Object? context, String key);
}

typedef WriteCommitter = void Function(String key);

abstract interface class StreamingWritableStorage {
  (Sink<List<int>>, WriteCommitter) putStream(Object? context);
}

abstract interface class VectorWritableStorage {
  void putVec(Object? context, String key, List<Uint8List> blobs);
}

abstract interface class PeekableStorage {
  Uint8List peek(Object? context, String key);
}

bool has(Object? context, Storage store, String key) => store.has(context, key);
Uint8List get(Object? context, ReadableStorage store, String key) =>
    store.get(context, key);
void put(
  Object? context,
  WritableStorage store,
  String key,
  Uint8List content,
) => store.put(context, key, content);
Iterable<int> getStream(Object? context, ReadableStorage store, String key) =>
    store is StreamingReadableStorage
    ? (store as StreamingReadableStorage).getStream(context, key)
    : store.get(context, key);

(Sink<List<int>>, WriteCommitter) putStream(
  Object? context,
  WritableStorage store,
) {
  if (store case final StreamingWritableStorage streamable) {
    return streamable.putStream(context);
  }
  final buffer = _ByteSink();
  var committed = false;
  return (
    buffer,
    (String key) {
      if (committed) throw StateError('WriteCommitter already used');
      committed = true;
      store.put(context, key, buffer.bytes());
    },
  );
}

void putVec(
  Object? context,
  WritableStorage store,
  String key,
  List<Uint8List> blobs,
) {
  if (store case final VectorWritableStorage vectorable) {
    return vectorable.putVec(context, key, blobs);
  }
  final (writer, commit) = putStream(context, store);
  for (final blob in blobs) {
    writer.add(blob);
  }
  commit(key);
}

Uint8List peek(Object? context, ReadableStorage store, String key) =>
    store is PeekableStorage
    ? (store as PeekableStorage).peek(context, key)
    : store.get(context, key);

final class _ByteSink implements Sink<List<int>> {
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  @override
  void add(List<int> data) => _buffer.add(data);
  @override
  void close() {}
  Uint8List bytes() => _buffer.toBytes();
}
