// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// test/multibase_parity_test.dart
//
// Parity vectors taken verbatim from go-multibase's own test suite
// (github.com/multiformats/go-multibase, at
// go-ipfs-reference/go-multibase/): `encodedSamples` in multibase_test.go
// (byte string "Decentralize everything!!!" encoded in all 21 supported
// encodings), plus the official multibase spec's CSV fixtures
// (spec/tests/*.csv, cloned from the multiformats/multibase submodule that
// the shallow go-multibase clone doesn't pull by default) covering a
// leading-space case, one and two leading zero bytes, and mixed-case
// ("non-canonical") decode inputs.
//
// go-multibase itself declares base8/base10/base45/base32z as encoding
// names but does NOT implement base8/base10/base45 (its own Encode/Decode
// switch has no case for them -- ErrUnsupportedEncoding), and base32z is a
// spec-fixture-only entry not registered in go-multibase's Encodings map at
// all. None of the four are tested here, matching go-multibase's own
// TestSpecVectors, which skips any encoding name that
// EncoderByName can't resolve.
import 'dart:convert';
import 'dart:typed_data';

import 'package:transpiled_multibase/transpiled_multibase.dart';
import 'package:test/test.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('MultibaseUtils parity with go-multibase (sampleBytes)', () {
    final sample = _bytes('Decentralize everything!!!');
    final identityExpected =
        '${String.fromCharCode(0x00)}Decentralize everything!!!';

    final cases = <(String name, String expected)>[
      ('identity', identityExpected),
      (
        'base2',
        '00100010001100101011000110110010101101110011101000111001001100001'
            '011011000110100101111010011001010010000001100101011101100110010'
            '101110010011110010111010001101000011010010110111001100111001000'
            '010010000100100001',
      ),
      ('base16', 'f446563656e7472616c697a652065766572797468696e67212121'),
      ('base16upper', 'F446563656E7472616C697A652065766572797468696E67212121'),
      ('base32', 'birswgzloorzgc3djpjssazlwmvzhs5dinfxgoijbee'),
      ('base32upper', 'BIRSWGZLOORZGC3DJPJSSAZLWMVZHS5DINFXGOIJBEE'),
      ('base32pad', 'cirswgzloorzgc3djpjssazlwmvzhs5dinfxgoijbee======'),
      ('base32padupper', 'CIRSWGZLOORZGC3DJPJSSAZLWMVZHS5DINFXGOIJBEE======'),
      ('base32hex', 'v8him6pbeehp62r39f9ii0pbmclp7it38d5n6e89144'),
      ('base32hexupper', 'V8HIM6PBEEHP62R39F9II0PBMCLP7IT38D5N6E89144'),
      ('base32hexpad', 't8him6pbeehp62r39f9ii0pbmclp7it38d5n6e89144======'),
      ('base32hexpadupper', 'T8HIM6PBEEHP62R39F9II0PBMCLP7IT38D5N6E89144======'),
      ('base36', 'km552ng4dabi4neu1oo8l4i5mndwmpc3mkukwtxy9'),
      ('base36upper', 'KM552NG4DABI4NEU1OO8L4I5MNDWMPC3MKUKWTXY9'),
      ('base58btc', 'z36UQrhJq9fNDS7DiAHM9YXqDHMPfr4EMArvt'),
      ('base58flickr', 'Z36tpRGiQ9Endr7dHahm9xwQdhmoER4emaRVT'),
      ('base64', 'mRGVjZW50cmFsaXplIGV2ZXJ5dGhpbmchISE'),
      ('base64url', 'uRGVjZW50cmFsaXplIGV2ZXJ5dGhpbmchISE'),
      ('base64pad', 'MRGVjZW50cmFsaXplIGV2ZXJ5dGhpbmchISE='),
      ('base64urlpad', 'URGVjZW50cmFsaXplIGV2ZXJ5dGhpbmchISE='),
      (
        'base256emoji',
        '🚀💛✋💃✋😻😈🥺🤤🍀🌟💐✋😅✋💦✋🥺🏃😈😴🌟😻😝👏👏👏',
      ),
    ];

    for (final (name, expected) in cases) {
      test('encode $name', () {
        expect(MultibaseUtils.encodeWithName(name, sample), equals(expected));
      });
      test('decode $name', () {
        expect(MultibaseUtils.decode(expected), equals(sample));
      });
    }
  });

  group('MultibaseUtils parity with go-multibase spec CSVs', () {
    void checkRow(String plaintext, Map<String, String> row) {
      final data = _bytes(plaintext);
      for (final entry in row.entries) {
        test('${entry.key} -- ${plaintext.length} byte(s)', () {
          expect(
            MultibaseUtils.encodeWithName(entry.key, data),
            equals(entry.value),
          );
          expect(MultibaseUtils.decode(entry.value), equals(data));
        });
      }
    }

    checkRow('yes mani !', {
      'base2': '0'
          '01111001011001010111001100100000011011010110000101101110011'
          '010010010000000100001',
      'base16': 'f796573206d616e692021',
      'base16upper': 'F796573206D616E692021',
      'base32': 'bpfsxgidnmfxgsibb',
      'base32upper': 'BPFSXGIDNMFXGSIBB',
      'base32hex': 'vf5in683dc5n6i811',
      'base32hexupper': 'VF5IN683DC5N6I811',
      'base32pad': 'cpfsxgidnmfxgsibb',
      'base32padupper': 'CPFSXGIDNMFXGSIBB',
      'base32hexpad': 'tf5in683dc5n6i811',
      'base32hexpadupper': 'TF5IN683DC5N6I811',
      'base36': 'k2lcpzo5yikidynfl',
      'base36upper': 'K2LCPZO5YIKIDYNFL',
      'base58flickr': 'Z7Pznk19XTTzBtx',
      'base58btc': 'z7paNL19xttacUY',
      'base64': 'meWVzIG1hbmkgIQ',
      'base64pad': 'MeWVzIG1hbmkgIQ==',
      'base64url': 'ueWVzIG1hbmkgIQ',
      'base64urlpad': 'UeWVzIG1hbmkgIQ==',
      'base256emoji': '🚀🏃✋🌈😅🌷🤤😻🌟😅👏',
    });

    checkRow('\x00yes mani !', {
      'base2': '0'
          '0000000001111001011001010111001100100000011011010110000101'
          '101110011010010010000000100001',
      'base16': 'f00796573206d616e692021',
      'base16upper': 'F00796573206D616E692021',
      'base32': 'bab4wk4zanvqw42jaee',
      'base32upper': 'BAB4WK4ZANVQW42JAEE',
      'base32hex': 'v01smasp0dlgmsq9044',
      'base32hexupper': 'V01SMASP0DLGMSQ9044',
      'base32pad': 'cab4wk4zanvqw42jaee======',
      'base32padupper': 'CAB4WK4ZANVQW42JAEE======',
      'base32hexpad': 't01smasp0dlgmsq9044======',
      'base32hexpadupper': 'T01SMASP0DLGMSQ9044======',
      'base36': 'k02lcpzo5yikidynfl',
      'base36upper': 'K02LCPZO5YIKIDYNFL',
      'base58flickr': 'Z17Pznk19XTTzBtx',
      'base58btc': 'z17paNL19xttacUY',
      'base64': 'mAHllcyBtYW5pICE',
      'base64pad': 'MAHllcyBtYW5pICE=',
      'base64url': 'uAHllcyBtYW5pICE',
      'base64urlpad': 'UAHllcyBtYW5pICE=',
      'base256emoji': '🚀🚀🏃✋🌈😅🌷🤤😻🌟😅👏',
    });

    checkRow('\x00\x00yes mani !', {
      'base2': '0'
          '000000000000000001111001011001010111001100100000011011010'
          '110000101101110011010010010000000100001',
      'base16': 'f0000796573206d616e692021',
      'base16upper': 'F0000796573206D616E692021',
      'base32': 'baaahszltebwwc3tjeaqq',
      'base32upper': 'BAAAHSZLTEBWWC3TJEAQQ',
      'base32hex': 'v0007ipbj41mm2rj940gg',
      'base32hexupper': 'V0007IPBJ41MM2RJ940GG',
      'base32pad': 'caaahszltebwwc3tjeaqq====',
      'base32padupper': 'CAAAHSZLTEBWWC3TJEAQQ====',
      'base32hexpad': 't0007ipbj41mm2rj940gg====',
      'base32hexpadupper': 'T0007IPBJ41MM2RJ940GG====',
      'base36': 'k002lcpzo5yikidynfl',
      'base36upper': 'K002LCPZO5YIKIDYNFL',
      'base58flickr': 'Z117Pznk19XTTzBtx',
      'base58btc': 'z117paNL19xttacUY',
      // Exact multiple of 3 bytes -> no base64 padding either way.
      'base64': 'mAAB5ZXMgbWFuaSAh',
      'base64pad': 'MAAB5ZXMgbWFuaSAh',
      'base64url': 'uAAB5ZXMgbWFuaSAh',
      'base64urlpad': 'UAAB5ZXMgbWFuaSAh',
      'base256emoji': '🚀🚀🚀🏃✋🌈😅🌷🤤😻🌟😅👏',
    });
  });

  group('MultibaseUtils.decode -- case-insensitive (non-canonical inputs)', () {
    final expected = _bytes('hello world');
    final cases = <(String label, String input)>[
      ('base16 mixed case', 'f68656c6c6f20776F726C64'),
      ('base16upper mixed case', 'F68656c6c6f20776F726C64'),
      ('base32 mixed case', 'bnbswy3dpeB3W64TMMQ'),
      ('base32upper mixed case', 'Bnbswy3dpeB3W64TMMQ'),
      ('base32hex mixed case', 'vd1imor3f41RMUSJCCG'),
      ('base32hexupper mixed case', 'Vd1imor3f41RMUSJCCG'),
      ('base32pad mixed case', 'cnbswy3dpeB3W64TMMQ======'),
      ('base32padupper mixed case', 'Cnbswy3dpeB3W64TMMQ======'),
      ('base32hexpad mixed case', 'td1imor3f41RMUSJCCG======'),
      ('base32hexpadupper mixed case', 'Td1imor3f41RMUSJCCG======'),
      ('base36 mixed case', 'kfUvrsIvVnfRbjWaJo'),
      ('base36upper mixed case', 'KfUVrSIVVnFRbJWAJo'),
    ];
    for (final (label, input) in cases) {
      test(label, () {
        expect(MultibaseUtils.decode(input), equals(expected));
      });
    }
  });

  group('MultibaseUtils -- unsupported encodings match go-multibase', () {
    test('base8/base10/base45 are not implemented (matches upstream)', () {
      // go-multibase declares these constants but its own Encode() falls
      // through to ErrUnsupportedEncoding for all three.
      for (final name in ['base8', 'base10', 'base45']) {
        expect(
          () => MultibaseUtils.encodeWithName(name, Uint8List(0)),
          throwsUnsupportedError,
        );
      }
    });

    test('empty string is rejected on decode', () {
      expect(() => MultibaseUtils.decode(''), throwsFormatException);
    });
  });
}
