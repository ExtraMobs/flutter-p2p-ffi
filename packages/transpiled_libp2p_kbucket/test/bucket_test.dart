// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p-kbucket's bucket_test.go: TestBucketMinimum,
// TestUpdateAllWith.
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_kbucket/transpiled_libp2p_kbucket.dart';

PeerId _randPeerId() {
  final random = Random.secure();
  final bytes = Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
  return PeerId(value: bytes);
}

PeerInfo _peerInfo(PeerId id, {DateTime? lastUsefulAt}) => PeerInfo(
  id: id,
  dhtId: convertPeerId(id),
  lastUsefulAt: lastUsefulAt,
);

void main() {
  test('min: returns null for an empty bucket, then tracks the actual minimum', () {
    final b = Bucket();
    expect(b.min((first, second) => true), isNull);

    final pid1 = _randPeerId();
    final pid2 = _randPeerId();
    final pid3 = _randPeerId();

    b.pushFront(_peerInfo(pid1, lastUsefulAt: DateTime.now().toUtc()));
    expect(
      b.min((first, second) => first.lastUsefulAt.isBefore(second.lastUsefulAt))?.id,
      equals(pid1),
    );

    b.pushFront(
      _peerInfo(pid2, lastUsefulAt: DateTime.now().toUtc().add(const Duration(days: 366))),
    );
    expect(
      b.min((first, second) => first.lastUsefulAt.isBefore(second.lastUsefulAt))?.id,
      equals(pid1),
    );

    b.pushFront(
      _peerInfo(pid3, lastUsefulAt: DateTime.now().toUtc().subtract(const Duration(days: 366))),
    );
    expect(
      b.min((first, second) => first.lastUsefulAt.isBefore(second.lastUsefulAt))?.id,
      equals(pid3),
    );
  });

  test('updateAllWith: applies the update function to every peer in the bucket', () {
    final b = Bucket();
    b.updateAllWith((p) {}); // Must not crash on an empty bucket.

    final pid1 = _randPeerId();
    final pid2 = _randPeerId();
    final pid3 = _randPeerId();

    b.pushFront(_peerInfo(pid1));
    b.updateAllWith((p) => p.replaceable = true);
    expect(b.getPeer(pid1)!.replaceable, isTrue);

    b.pushFront(_peerInfo(pid2));
    b.updateAllWith((p) => p.replaceable = p.id != pid1);
    expect(b.getPeer(pid2)!.replaceable, isTrue);
    expect(b.getPeer(pid1)!.replaceable, isFalse);

    b.pushFront(_peerInfo(pid3));
    expect(b.getPeer(pid3)!.replaceable, isFalse);
    b.updateAllWith((p) => p.replaceable = true);
    expect(b.getPeer(pid1)!.replaceable, isTrue);
    expect(b.getPeer(pid2)!.replaceable, isTrue);
    expect(b.getPeer(pid3)!.replaceable, isTrue);
  });
}
