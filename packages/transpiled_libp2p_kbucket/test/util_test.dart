// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p-kbucket's util_test.go (TestCloser): confirms `closer`
// agrees with a direct XOR-distance comparison between two random peers
// and a search-target key, for both the "Pa is closer" and "Pb is closer"
// cases.
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

int _compareDhtId(DhtId a, DhtId b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) return a[i] - b[i];
  }
  return a.length - b.length;
}

void main() {
  test('closer agrees with direct XOR-distance comparison', () {
    final pa = _randPeerId();
    final pb = _randPeerId();
    final random = Random.secure();
    String randomKey() =>
        String.fromCharCodes(List.generate(16, (_) => random.nextInt(256)));

    late String x;
    while (true) {
      x = randomKey();
      final da = xor(convertPeerId(pa), convertKey(x));
      final db = xor(convertPeerId(pb), convertKey(x));
      if (_compareDhtId(da, db) < 0) break;
    }
    expect(closer(pa, pb, x), isTrue);

    while (true) {
      x = randomKey();
      final da = xor(convertPeerId(pb), convertKey(x));
      final db = xor(convertPeerId(pa), convertKey(x));
      if (_compareDhtId(da, db) < 0) break;
    }
    expect(closer(pa, pb, x), isFalse);
  });
}
