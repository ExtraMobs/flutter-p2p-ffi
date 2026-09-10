// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p-pubsub's timecache/first_seen_cache_test.go:
// TestFirstSeenCacheFound, TestFirstSeenCacheExpire,
// TestFirstSeenCacheNotFoundAfterExpire.
//
// Go's version uses `testing/synctest` to fake time inside a "bubble" so
// `time.Sleep` advances instantly; this port isn't wired up to Dart's
// `fake_async` package (a new dependency this small utility doesn't
// otherwise need), so it uses real, short (sub-second) delays instead --
// slower than Go's instant virtual time, but the same real behavior under
// test, with generous margins to avoid flakiness.
import 'package:test/test.dart';
import 'package:transpiled_libp2p_pubsub/transpiled_libp2p_pubsub.dart';

void main() {
  test('TestFirstSeenCacheFound', () {
    final tc = TimeCache.firstSeenWithSweepInterval(const Duration(minutes: 1), const Duration(minutes: 1));
    addTearDown(tc.done);

    tc.add('test');
    expect(tc.has('test'), isTrue, reason: 'should have this key');
  });

  test('TestFirstSeenCacheExpire', () async {
    final tc = TimeCache.firstSeenWithSweepInterval(
      const Duration(milliseconds: 150),
      const Duration(milliseconds: 100),
    );
    addTearDown(tc.done);

    for (var i = 0; i < 5; i++) {
      tc.add('$i');
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));

    for (var i = 0; i < 5; i++) {
      expect(tc.has('$i'), isFalse, reason: 'should have dropped key $i from the cache already');
    }
  });

  test('TestFirstSeenCacheNotFoundAfterExpire', () async {
    final tc = TimeCache.firstSeenWithSweepInterval(
      const Duration(milliseconds: 150),
      const Duration(milliseconds: 100),
    );
    addTearDown(tc.done);

    tc.add('0');

    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(tc.has('0'), isFalse, reason: 'should have dropped this from the cache already');
  });
}
