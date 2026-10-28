// Lesson 02 · What is a CID?
//
// Question: everything in IPFS is addressed by a CID (`bafkrei...`,
// `Qm...`). What is in it, and why can I trust what comes back for it?
//
// Answer: a CID is the name of some bytes, computed from the bytes
// themselves. It packs three things:
//   - the hash of the bytes (a multihash: which hash function, the length
//     and the digest);
//   - the codec: how to read the bytes (raw bytes, a dag-pb node of a file,
//     dag-cbor, ...);
//   - the version: v0 (`Qm...`, only sha2-256 + dag-pb, base58) or v1
//     (any hash, any codec, any text base).
// Whoever receives the bytes hashes them again and compares: if it matches,
// the bytes are the right ones, whoever sent them. That is what lets IPFS
// fetch from strangers (lesson 16).
//
// Needs: lesson 01 (the service). No repo, no network: a CID is pure
// computation.
//
//   dart run example/en_us/02_what_is_a_cid.dart
//
// Next question: "A CID names some bytes; how does a whole file, too big for
// one block, get a CID?" → lesson 03.
import 'dart:convert';
import 'dart:typed_data';

import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/multibase.dart' as multibase;
import 'package:p2p_ffi/go/multicodec.dart' as multicodec;
import 'package:p2p_ffi/go/multihash.dart' as multihash;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  try {
    // 1. From bytes to a CID. The prefix says which version, codec and hash
    //    to use; Sum hashes the bytes and builds the CID.
    //    Go:  p := cid.NewPrefixV1(cid.Raw, multihash.SHA2_256)
    //         c, _ := p.Sum(data)
    final raw = cid.newPrefixV1(cid.raw, multihash.sha2256);
    final hello = raw.sum(utf8.encode('hello'));
    say('"hello" as raw bytes:  $hello');
    say('  the same bytes again: ${raw.sum(utf8.encode('hello'))} '
        '(always the same name)');
    say('  one byte different:   ${raw.sum(utf8.encode('hellO'))}');

    // 2. What is inside: the binary form of the CID, field by field.
    final b = hello.bytes();
    final mh = hello.hash(); // the multihash: function, length, digest
    say('\nthe ${b.length} bytes of the CID: ${hex(b)}');
    say('  ${hex(b.sublist(0, 1))}      version ${hello.version()}');
    say('  ${hex(b.sublist(1, 2))}      codec 0x${hello.type().toRadixString(16)} (raw)');
    say('  ${hex(mh.sublist(0, 1))}      hash function 0x12 (sha2-256)');
    say('  ${hex(mh.sublist(1, 2))}      digest length ${mh[1]} bytes');
    say('  ${hex(mh.sublist(2, 6))}…  the digest itself');
    // The same fields without the digest: what Sum needs to make a CID.
    final p = hello.prefix();
    say('  as a Prefix: version ${p.version}, codec 0x'
        '${p.codec.toRadixString(16)}, hash 0x${p.mhType.toRadixString(16)}, '
        'length ${p.mhLength}');

    // 3. The text is only a base: the same CID written three ways.
    say('\nthe same CID in three bases:');
    for (final (name, base) in [
      ('base32', multibase.base32), // 'b', the default of CIDv1
      ('base58btc', multibase.base58btc), // 'z', the only base of CIDv0
      (
        'base36',
        multibase.base36
      ), // 'k', for subdomains (case-insensitive, short)
    ]) {
      final text = hello.stringOfBase(base);
      say('  ${name.padRight(9)} $text  (decodes to the same: '
          '${cid.decode(text).equals(hello)})');
    }

    // 4. The codec is part of the name: the same bytes read as raw or as
    //    dag-pb are different CIDs with the same hash.
    final asDagPb = cid.newCidV1(multicodec.dagPb, mh);
    say('\nthe same hash with codec dag-pb: $asDagPb');
    say('  same hash: ${hex(asDagPb.hash()) == hex(mh)}, same CID: '
        '${asDagPb.equals(hello)}');

    // 5. CIDv0: the old `Qm...`, sha2-256 + dag-pb, base58, no prefix
    //    bytes. It converts to v1 losslessly (same codec, same hash).
    //    Go:  v0 := cid.NewCidV0(mh); v1 := cid.NewCidV1(cid.DagProtobuf, v0.Hash())
    final v0 = cid.newCidV0(mh);
    final v1 = cid.newCidV1(multicodec.dagPb, v0.hash());
    say('\nCIDv0 $v0 (${v0.bytes().length} bytes: only the multihash)');
    say('  as CIDv1:       $v1 (the same as the dag-pb one: '
        '${v1.equals(asDagPb)})');

    // 6. Other hash functions, and identity: the "hash" is the data itself,
    //    for bytes so small that hashing them would make the name longer.
    final sha512 = cid.newPrefixV1(multicodec.raw, multihash.sha2512);
    say('\nwith sha2-512: ${sha512.sum(utf8.encode('hello'))}');
    final identity = cid.newPrefixV1(multicodec.raw, multihash.identity);
    final inline = identity.sum(utf8.encode('hi'));
    say('with identity: $inline (the bytes "hi" are inside: '
        '${utf8.decode(inline.hash().sublist(2))})');
    say('  the empty identity CID, used in lesson 01: '
        '${identity.sum(Uint8List(0))}');

    // 7. Verifying: rebuild the CID from the bytes received and compare.
    //    This is what every IPFS node does with each block it gets.
    bool verify(cid.Cid c, Uint8List data) => c.prefix().sum(data).equals(c);
    say('\nverify("hello"): ${verify(hello, utf8.encode('hello'))}, '
        'verify("HELLO"): ${verify(hello, utf8.encode('HELLO'))}');

    say('\n== Common mistakes\n');
    await silentlyWrong('comparing two CIDs by their text',
        why: 'one CID has many texts (base, and v0 vs v1 for dag-pb)',
        instead: 'compare with equals(), or compare the hashes for v0 vs v1',
        wrong: () => '$hello' == hello.stringOfBase(multibase.base58btc),
        right: () =>
            hello.equals(cid.decode(hello.stringOfBase(multibase.base58btc))));
    await mistake('a CIDv0 with a hash other than sha2-256',
        why: 'v0 has no prefix bytes: sha2-256 and dag-pb are implied',
        instead: 'cid.newPrefixV1(codec, hash) for anything else',
        action: () => cid.newPrefixV0(multihash.sha2512).sum(Uint8List(3)));
    await mistake('decoding text cut in the middle',
        why: 'the length of the digest is inside the CID; a short one fails',
        instead: 'decode the whole text (copying from a URL, mind the end)',
        action: () => cid.decode('$hello'.substring(0, 30)));
  } finally {
    await P2pService.stop();
  }
}
