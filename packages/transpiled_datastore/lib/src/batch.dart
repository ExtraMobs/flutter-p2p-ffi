// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/batch.dart
//
// Port of go-datastore's batch.go: a naive Batch implementation for
// datastores with no underlying transactional support.
import 'datastore.dart';
import 'key.dart';

class _Op {
  const _Op({this.delete = false, this.value});
  final bool delete;
  final List<int>? value;
}

/// A [Batch] implemented by simply replaying its recorded operations
/// against [target] on [commit]. Equivalent to go-datastore's
/// `basicBatch`/`NewBasicBatch`.
class BasicBatch implements Batch {
  /// Creates a batch that will replay its operations against [target].
  BasicBatch(this._target);

  final Datastore _target;
  final Map<Key, _Op> _ops = {};

  @override
  Future<void> put(Key key, List<int> value) async {
    _ops[key] = _Op(value: value);
  }

  @override
  Future<void> delete(Key key) async {
    _ops[key] = const _Op(delete: true);
  }

  @override
  Future<void> commit() async {
    for (final entry in _ops.entries) {
      if (entry.value.delete) {
        await _target.delete(entry.key);
      } else {
        await _target.put(entry.key, entry.value.value!);
      }
    }
  }
}
