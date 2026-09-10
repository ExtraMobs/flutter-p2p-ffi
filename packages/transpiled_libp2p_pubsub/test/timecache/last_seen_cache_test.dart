// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p-pubsub's timecache/last_seen_cache_test.go:
// TestLastSeenCacheFound, TestLastSeenCacheExpire,
// TestLastSeenCacheSlideForward, TestLastSeenCacheNotFoundAfterExpire.
// See first_seen_cache_test.dart's header for why real (short) delays are
// used here instead of Go's `testing/synctest` virtual time.
import 'package:test/test.dart';
import 'package:transpiled_libp2p_pubsub/transpiled_libp2p_pubsub.dart';

void main() {
  test('TestLastSeenCacheFound', () {
    final tc = TimeCache.lastSeenWithSweepInterval(const Duration(minutes: 1), const Duration(minutes: 1));
    addTearDown(tc.done);

    tc.add('test');
    expect(tc.has('test'), isTrue, reason: 'should have this key');
  });

  test('TestLastSeenCacheExpire', () async {
    final tc = TimeCache.lastSeenWithSweepInterval(
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

  test('TestLastSeenCacheSlideForward', () async {
    final tc = TimeCache.lastSeenWithSweepInterval(
      const Duration(milliseconds: 300),
      const Duration(milliseconds: 100),
    );
    addTearDown(tc.done);

    tc.add('0');
    tc.add('1');

    // Before natural expiry: touching '0' via has() should slide its
    // expiry forward by a fresh 300ms from *now*, while '1' is untouched.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(tc.has('0'), isTrue, reason: 'should have this key');

    // '1' was added at T0 with a 300ms ttl and never touched again, so by
    // T450ms it's well past expiry and the sweep (every 100ms) should
    // have removed it; '0' was slid forward at ~T200ms, so its fresh
    // 300ms window runs to ~T500ms -- still alive at T450ms.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(tc.has('1'), isFalse, reason: 'should have dropped this from the cache already');
    expect(tc.has('0'), isTrue, reason: 'should still have this key'); // slides '0' forward again.

    // '0' was just slid forward at ~T450ms; wait well past that window.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(tc.has('0'), isFalse, reason: 'should have dropped this from the cache already');
  });

  test('TestLastSeenCacheNotFoundAfterExpire', () async {
    final tc = TimeCache.lastSeenWithSweepInterval(
      const Duration(milliseconds: 150),
      const Duration(milliseconds: 100),
    );
    addTearDown(tc.done);

    tc.add('0');

    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(tc.has('0'), isFalse, reason: 'should have dropped this from the cache already');
  });
}
