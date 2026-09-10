// test/transport/dns/dns_message_test.dart
//
// Parity/correctness tests for the hand-rolled RFC 1035 DNS codec (see
// doc/transpilation/PROGRESS.md's go-multiaddr-dns row for why this
// exists: `dart:io` has no TXT lookup API). The response fixtures below
// are real bytes captured from a live UDP exchange with 1.1.1.1 (query IDs
// chosen by the capture script, not meaningful otherwise) -- this exercises
// genuine wire behavior (name compression, multiple answer records, an
// NXDOMAIN with an authority-section SOA record) rather than only
// hand-constructed edge cases. The TXT values were independently verified
// against Windows' `Resolve-DnsName -Type TXT` for the same name.
import 'dart:typed_data';

import 'package:transpiled_ipfs/src/transport/dns/dns_message.dart';
import 'package:test/test.dart';

Uint8List _fromHex(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

const _txtResponseHex =
    'beef81800001000400000000085f646e736164647209626f6f74737472617006'
    '6c696270327002696f0000100001c00c00100001000000ce005c5b646e736164'
    '64723d2f646e73616464722f616d362e626f6f7473747261702e6c6962703270'
    '2e696f2f7032702f516d624c48416e4d6f4a5057534352355a6874783642484a'
    '58394b694b4e4e3674707662556371616e6a37354e62c00c00100001000000ce'
    '005c5b646e73616464723d2f646e73616464722f6e79352e626f6f7473747261'
    '702e6c69627032702e696f2f7032702f516d5143553245634d71417151505232'
    '69396243684474474e4a6368546271355462584a4a3136753139754c5461c00c'
    '00100001000000ce005c5b646e73616464723d2f646e73616464722f7367312e'
    '626f6f7473747261702e6c69627032702e696f2f7032702f516d635a66353962'
    '57774b355846693736435a583863624a344268547a7a41336755315a6a595a63'
    '595733647774c00c00100001000000ce005d5c646e73616464723d2f646e7361'
    '6464722f737631352e626f6f7473747261702e6c69627032702e696f2f703270'
    '2f516d4e6e6f6f44753762666a50466f545a59784d4e4c5755514a7972567774'
    '625a673567424d6a54657a47414a4e';

const _aResponseHex =
    'cafe8180000100020000000003646e7306676f6f676c650000010001c00c0001'
    '0001000002c1000408080808c00c00010001000002c1000408080404';

const _aaaaResponseHex =
    'f00d8180000100020000000003646e7306676f6f676c6500001c0001c00c001c'
    '00010000031c001020014860486000000000000000008844c00c001c00010000'
    '031c001020014860486000000000000000008888';

const _nxdomainResponseHex =
    '11118183000100000001000022746869732d646f6d61696e2d73686f756c642d'
    '6e6f742d65786973742d313233343507696e76616c6964000001000100000600'
    '0100015180004001610c726f6f742d73657276657273036e657400056e73746c'
    '640c766572697369676e2d67727303636f6d0078c39061000007080000038400'
    '093a8000015180';

void main() {
  group('encodeDnsQuery', () {
    test('matches the real query bytes sent for a TXT lookup', () {
      final bytes = encodeDnsQuery(
        id: 0x1234,
        name: '_dnsaddr.bootstrap.libp2p.io',
        type: DnsRecordType.txt,
      );
      expect(
        bytes,
        equals(
          _fromHex(
            '123401000001000000000000085f646e736164647209626f6f74737472617006'
            '6c696270327002696f0000100001',
          ),
        ),
      );
    });

    test('rejects a label over 63 bytes', () {
      final tooLong = 'a' * 64;
      expect(
        () => encodeDnsQuery(id: 1, name: '$tooLong.com', type: DnsRecordType.a),
        throwsFormatException,
      );
    });
  });

  group('decodeDnsMessage -- real captured responses', () {
    test('TXT: parses 4 dnsaddr records via name-compressed answers', () {
      final response = decodeDnsMessage(_fromHex(_txtResponseHex));
      expect(response.id, equals(0xbeef));
      expect(response.rcode, equals(0));
      final txt = response.records.where((r) => r.type == DnsRecordType.txt).toList();
      expect(txt, hasLength(4));
      expect(
        txt.map((r) => r.data),
        equals([
          'dnsaddr=/dnsaddr/am6.bootstrap.libp2p.io/p2p/QmbLHAnMoJPWSCR5Zhtx6BHJX9KiKNN6tpvbUcqanj75Nb',
          'dnsaddr=/dnsaddr/ny5.bootstrap.libp2p.io/p2p/QmQCU2EcMqAqQPR2i9bChDtGNJchTbq5TbXJJ16u19uLTa',
          'dnsaddr=/dnsaddr/sg1.bootstrap.libp2p.io/p2p/QmcZf59bWwK5XFi76CZX8cbJ4BhTzzA3gU1ZjYZcYW3dwt',
          'dnsaddr=/dnsaddr/sv15.bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN',
        ]),
      );
    });

    test('A: parses two IPv4 addresses', () {
      final response = decodeDnsMessage(_fromHex(_aResponseHex));
      expect(response.rcode, equals(0));
      final a = response.records.where((r) => r.type == DnsRecordType.a).toList();
      expect(a.map((r) => r.data), equals(['8.8.8.8', '8.8.4.4']));
    });

    test('AAAA: parses two IPv6 addresses in canonical compressed form', () {
      final response = decodeDnsMessage(_fromHex(_aaaaResponseHex));
      expect(response.rcode, equals(0));
      final aaaa = response.records.where((r) => r.type == DnsRecordType.aaaa).toList();
      expect(
        aaaa.map((r) => r.data),
        equals(['2001:4860:4860::8844', '2001:4860:4860::8888']),
      );
    });

    test('NXDOMAIN: rcode is 3 with no answer records (SOA is authority-only)', () {
      // ANCOUNT=0, NSCOUNT=1 (an SOA record this client doesn't need to
      // parse, since it only walks the answer section).
      final response = decodeDnsMessage(_fromHex(_nxdomainResponseHex));
      expect(response.rcode, equals(3));
      expect(response.records, isEmpty);
    });
  });

  group('decodeDnsMessage -- structural validation', () {
    test('rejects a message shorter than the 12-byte header', () {
      expect(() => decodeDnsMessage(Uint8List(11)), throwsFormatException);
    });

    test('rejects a forward-pointing compression pointer', () {
      // Header (12 bytes, QDCOUNT=0, ANCOUNT=1) followed by an answer whose
      // NAME is a pointer to an offset past itself.
      final bytes = Uint8List.fromList([
        0, 0, 0x81, 0x80, 0, 0, 0, 1, 0, 0, 0, 0, // header
        0xc0, 0x20, // NAME: pointer to offset 0x20 (forward -- past this record)
        0, 16, 0, 1, 0, 0, 0, 0, 0, 1, 0, // TYPE=TXT CLASS=IN TTL RDLENGTH=1
        0, // RDATA (1 empty character-string)
      ]);
      expect(() => decodeDnsMessage(bytes), throwsFormatException);
    });

    test('rejects RDATA that overruns the message', () {
      final bytes = Uint8List.fromList([
        0, 0, 0x81, 0x80, 0, 0, 0, 1, 0, 0, 0, 0, // header
        0, // NAME: root
        0, 16, 0, 1, 0, 0, 0, 0, 0, 200, // RDLENGTH=200, but no data follows
      ]);
      expect(() => decodeDnsMessage(bytes), throwsFormatException);
    });
  });
}
