// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Tests for lib/src/timecache/util.dart's `sweep` -- a pure function, so
// its expiry logic can be tested deterministically with controlled
// DateTime values instead of waiting on a real or virtual clock (Go's own
// tests use `testing/synctest` to fake time for exactly this reason; here
// the pure-function extraction gives the same determinism for free).
import 'package:test/test.dart';
import 'package:transpiled_libp2p_pubsub/transpiled_libp2p_pubsub.dart';

void main() {
  test('sweep removes only entries whose expiry is before now', () {
    final now = DateTime(2026, 1, 1, 12);
    final m = {
      'expired-1': now.subtract(const Duration(seconds: 1)),
      'expired-2': now.subtract(const Duration(minutes: 5)),
      'still-valid': now.add(const Duration(seconds: 1)),
      'exactly-now': now,
    };

    sweep(m, now);

    expect(m.keys, containsAll(['still-valid', 'exactly-now']));
    expect(m.containsKey('expired-1'), isFalse);
    expect(m.containsKey('expired-2'), isFalse);
  });

  test('sweep on an empty map does nothing', () {
    final m = <String, DateTime>{};
    sweep(m, DateTime.now());
    expect(m, isEmpty);
  });
}
