// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_ipld_prime/linking.dart';
import 'package:transpiled_ipld_prime/linking_cid.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart'
    show PlainBytes, prototype;

void main() {
  final linkPrototype = CidLinkPrototype(
    Prefix(version: 1, codec: 'raw', mhType: 'sha2-256', mhLength: 32),
  );

  test('stores, loads, returns raw bytes and computes the same Cid', () {
    final system = defaultLinkSystem();
    final store = MemoryStore();
    system.setReadStorage(store);
    system.setWriteStorage(store);
    final node = PlainBytes(Uint8List.fromList(<int>[1, 2, 3]));
    final link = system.store(const LinkContext(), linkPrototype, node);

    expect(system.computeLink(linkPrototype, node).binary(), link.binary());
    expect(system.loadRaw(const LinkContext(), link), <int>[1, 2, 3]);
    final (loaded, raw) = system.loadPlusRaw(
      const LinkContext(),
      link,
      prototype.bytes,
    );
    expect(loaded.asBytes(), <int>[1, 2, 3]);
    expect(raw, <int>[1, 2, 3]);
  });

  test('hash mismatch wins over a decoder error', () {
    final system = defaultLinkSystem();
    final store = MemoryStore();
    system.setReadStorage(store);
    system.setWriteStorage(store);
    final link = system.store(
      const LinkContext(),
      linkPrototype,
      PlainBytes(Uint8List.fromList(<int>[1])),
    );
    store.bag[String.fromCharCodes(link.binary())] = Uint8List.fromList(<int>[
      2,
    ]);
    expect(
      () =>
          system.fill(const LinkContext(), link, prototype.string.newBuilder()),
      throwsA(isA<HashMismatchException>()),
    );
  });

  test('Cid memory shares content by multihash', () {
    final memory = Memory();
    final system = defaultLinkSystem()
      ..storageReadOpener = memory.openRead
      ..storageWriteOpener = memory.openWrite;
    final link = system.store(
      const LinkContext(),
      linkPrototype,
      PlainBytes(Uint8List.fromList(<int>[7])),
    );
    expect(system.loadRaw(const LinkContext(), link), <int>[7]);
  });
}
