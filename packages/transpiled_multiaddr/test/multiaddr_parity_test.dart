// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// test/multiaddr_parity_test.dart
//
// Parity vectors taken verbatim from go-multiaddr's own multiaddr_test.go
// (github.com/multiformats/go-multiaddr, at
// go-ipfs-reference/go-multiaddr/multiaddr_test.go): `good` (must parse) and
// `TestConstructFails`' `cases` (must fail to parse). This includes entries
// using base36-encoded ("k...") PeerId CIDs -- base36 support landed in
// transpiled_multibase's multibase layer alongside the go-multibase port (see
// doc/transpilation/PROGRESS.md). base58 ("Qm...", "12D3Koo...") and base32
// ("bafzbei...") PeerId CIDs are covered too, and proven to decode to the
// same PeerId as their base58 equivalent.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

const _good = [
  '/ip4/1.2.3.4',
  '/ip4/0.0.0.0',
  '/ip4/192.0.2.0/ipcidr/24',
  '/ip6/::1',
  '/ip6/2601:9:4f81:9700:803e:ca65:66e8:c21',
  '/ip6/2601:9:4f81:9700:803e:ca65:66e8:c21/udp/1234/quic',
  '/ip6/2601:9:4f81:9700:803e:ca65:66e8:c21/udp/1234/quic-v1',
  '/ip6/2001:db8::/ipcidr/32',
  '/ip6zone/x/ip6/fe80::1',
  '/ip6zone/x%y/ip6/fe80::1',
  '/ip6zone/x%y/ip6/::',
  '/ip6zone/x/ip6/fe80::1/udp/1234/quic',
  '/ip6zone/x/ip6/fe80::1/udp/1234/quic-v1',
  '/onion/timaq4ygg2iegci7:1234',
  '/onion/timaq4ygg2iegci7:80/http',
  '/onion3/vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd:1234',
  '/onion3/vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd:80/http',
  '/garlic64/jT~IyXaoauTni6N4517EG8mrFUKpy0IlgZh-EY9csMAk82Odatmzr~YTZy8Hv7u~wvkg75EFNOyqb~nAPg-khyp2TS~ObUz8WlqYAM2VlEzJ7wJB91P-cUlKF18zSzVoJFmsrcQHZCirSbWoOknS6iNmsGRh5KVZsBEfp1Dg3gwTipTRIx7Vl5Vy~1OSKQVjYiGZS9q8RL0MF~7xFiKxZDLbPxk0AK9TzGGqm~wMTI2HS0Gm4Ycy8LYPVmLvGonIBYndg2bJC7WLuF6tVjVquiokSVDKFwq70BCUU5AU-EvdOD5KEOAM7mPfw-gJUG4tm1TtvcobrObqoRnmhXPTBTN5H7qDD12AvlwFGnfAlBXjuP4xOUAISL5SRLiulrsMSiT4GcugSI80mF6sdB0zWRgL1yyvoVWeTBn1TqjO27alr95DGTluuSqrNAxgpQzCKEWAyzrQkBfo2avGAmmz2NaHaAvYbOg0QSJz1PLjv2jdPW~ofiQmrGWM1cd~1cCqAAAA',
  '/garlic64/jT~IyXaoauTni6N4517EG8mrFUKpy0IlgZh-EY9csMAk82Odatmzr~YTZy8Hv7u~wvkg75EFNOyqb~nAPg-khyp2TS~ObUz8WlqYAM2VlEzJ7wJB91P-cUlKF18zSzVoJFmsrcQHZCirSbWoOknS6iNmsGRh5KVZsBEfp1Dg3gwTipTRIx7Vl5Vy~1OSKQVjYiGZS9q8RL0MF~7xFiKxZDLbPxk0AK9TzGGqm~wMTI2HS0Gm4Ycy8LYPVmLvGonIBYndg2bJC7WLuF6tVjVquiokSVDKFwq70BCUU5AU-EvdOD5KEOAM7mPfw-gJUG4tm1TtvcobrObqoRnmhXPTBTN5H7qDD12AvlwFGnfAlBXjuP4xOUAISL5SRLiulrsMSiT4GcugSI80mF6sdB0zWRgL1yyvoVWeTBn1TqjO27alr95DGTluuSqrNAxgpQzCKEWAyzrQkBfo2avGAmmz2NaHaAvYbOg0QSJz1PLjv2jdPW~ofiQmrGWM1cd~1cCqAAAA/http',
  '/garlic64/jT~IyXaoauTni6N4517EG8mrFUKpy0IlgZh-EY9csMAk82Odatmzr~YTZy8Hv7u~wvkg75EFNOyqb~nAPg-khyp2TS~ObUz8WlqYAM2VlEzJ7wJB91P-cUlKF18zSzVoJFmsrcQHZCirSbWoOknS6iNmsGRh5KVZsBEfp1Dg3gwTipTRIx7Vl5Vy~1OSKQVjYiGZS9q8RL0MF~7xFiKxZDLbPxk0AK9TzGGqm~wMTI2HS0Gm4Ycy8LYPVmLvGonIBYndg2bJC7WLuF6tVjVquiokSVDKFwq70BCUU5AU-EvdOD5KEOAM7mPfw-gJUG4tm1TtvcobrObqoRnmhXPTBTN5H7qDD12AvlwFGnfAlBXjuP4xOUAISL5SRLiulrsMSiT4GcugSI80mF6sdB0zWRgL1yyvoVWeTBn1TqjO27alr95DGTluuSqrNAxgpQzCKEWAyzrQkBfo2avGAmmz2NaHaAvYbOg0QSJz1PLjv2jdPW~ofiQmrGWM1cd~1cCqAAAA/udp/8080',
  '/garlic64/jT~IyXaoauTni6N4517EG8mrFUKpy0IlgZh-EY9csMAk82Odatmzr~YTZy8Hv7u~wvkg75EFNOyqb~nAPg-khyp2TS~ObUz8WlqYAM2VlEzJ7wJB91P-cUlKF18zSzVoJFmsrcQHZCirSbWoOknS6iNmsGRh5KVZsBEfp1Dg3gwTipTRIx7Vl5Vy~1OSKQVjYiGZS9q8RL0MF~7xFiKxZDLbPxk0AK9TzGGqm~wMTI2HS0Gm4Ycy8LYPVmLvGonIBYndg2bJC7WLuF6tVjVquiokSVDKFwq70BCUU5AU-EvdOD5KEOAM7mPfw-gJUG4tm1TtvcobrObqoRnmhXPTBTN5H7qDD12AvlwFGnfAlBXjuP4xOUAISL5SRLiulrsMSiT4GcugSI80mF6sdB0zWRgL1yyvoVWeTBn1TqjO27alr95DGTluuSqrNAxgpQzCKEWAyzrQkBfo2avGAmmz2NaHaAvYbOg0QSJz1PLjv2jdPW~ofiQmrGWM1cd~1cCqAAAA/tcp/8080',
  '/garlic32/566niximlxdzpanmn4qouucvua3k7neniwss47li5r6ugoertzuq',
  '/garlic32/566niximlxdzpanmn4qouucvua3k7neniwss47li5r6ugoertzuqzwas',
  '/garlic32/566niximlxdzpanmn4qouucvua3k7neniwss47li5r6ugoertzuqzwassw',
  '/garlic32/566niximlxdzpanmn4qouucvua3k7neniwss47li5r6ugoertzuq/http',
  '/garlic32/566niximlxdzpanmn4qouucvua3k7neniwss47li5r6ugoertzuq/tcp/8080',
  '/garlic32/566niximlxdzpanmn4qouucvua3k7neniwss47li5r6ugoertzuq/udp/8080',
  '/udp/0',
  '/tcp/0',
  '/sctp/0',
  '/udp/1234',
  '/tcp/1234',
  '/sctp/1234',
  '/udp/65535',
  '/tcp/65535',
  '/ipfs/QmcgpsyWgH8Y8ajJz1Cu72KnS5uo2Aa2LpzU7kinSupNKC',
  '/p2p/QmcgpsyWgH8Y8ajJz1Cu72KnS5uo2Aa2LpzU7kinSupNKC',
  '/p2p/bafzbeigvf25ytwc3akrijfecaotc74udrhcxzh2cx3we5qqnw5vgrei4bm',
  '/p2p/12D3KooWCryG7Mon9orvQxcS1rYZjotPgpwoJNHHKcLLfE4Hf5mV',
  '/p2p/bafzaajaiaejcalj543iwv2d7pkjt7ykvefrkfu7qjfi6sduakhso4lay6abn2d5u',
  '/udp/1234/sctp/1234',
  '/udp/1234/udt',
  '/udp/1234/utp',
  '/tcp/1234/http',
  '/tcp/1234/tls/http',
  '/tcp/1234/https',
  '/ipfs/QmcgpsyWgH8Y8ajJz1Cu72KnS5uo2Aa2LpzU7kinSupNKC/tcp/1234',
  '/p2p/QmcgpsyWgH8Y8ajJz1Cu72KnS5uo2Aa2LpzU7kinSupNKC/tcp/1234',
  '/ip4/127.0.0.1/udp/1234',
  '/ip4/127.0.0.1/udp/0',
  '/ip4/127.0.0.1/tcp/1234',
  '/ip4/127.0.0.1/tcp/1234/',
  '/ip4/127.0.0.1/udp/1234/quic',
  '/ip4/127.0.0.1/udp/1234/quic-v1',
  '/ip4/127.0.0.1/udp/1234/quic-v1/webtransport',
  '/ip4/127.0.0.1/udp/1234/quic-v1/webtransport/certhash/b2uaraocy6yrdblb4sfptaddgimjmmpy',
  '/ip4/127.0.0.1/udp/1234/quic-v1/webtransport/certhash/b2uaraocy6yrdblb4sfptaddgimjmmpy/certhash/zQmbWTwYGcmdyK9CYfNBcfs9nhZs17a6FQ4Y8oea278xx41',
  '/ip4/127.0.0.1/ipfs/QmcgpsyWgH8Y8ajJz1Cu72KnS5uo2Aa2LpzU7kinSupNKC',
  '/ip4/127.0.0.1/ipfs/QmcgpsyWgH8Y8ajJz1Cu72KnS5uo2Aa2LpzU7kinSupNKC/tcp/1234',
  '/ip4/127.0.0.1/p2p/QmcgpsyWgH8Y8ajJz1Cu72KnS5uo2Aa2LpzU7kinSupNKC',
  '/ip4/127.0.0.1/p2p/QmcgpsyWgH8Y8ajJz1Cu72KnS5uo2Aa2LpzU7kinSupNKC/tcp/1234',
  '/unix/a/b/c/d/e',
  '/unix/stdio',
  '/ip4/1.2.3.4/tcp/80/unix/a/b/c/d/e/f',
  '/ip4/127.0.0.1/ipfs/QmcgpsyWgH8Y8ajJz1Cu72KnS5uo2Aa2LpzU7kinSupNKC/tcp/1234/unix/stdio',
  '/ip4/127.0.0.1/p2p/QmcgpsyWgH8Y8ajJz1Cu72KnS5uo2Aa2LpzU7kinSupNKC/tcp/1234/unix/stdio',
  '/ip4/127.0.0.1/tcp/9090/http/p2p-webrtc-direct',
  '/ip4/127.0.0.1/tcp/127/ws',
  '/ip4/127.0.0.1/tcp/127/tls',
  '/ip4/127.0.0.1/tcp/127/tls/ws',
  '/ip4/127.0.0.1/tcp/127/noise',
  '/ip4/127.0.0.1/tcp/127/wss',
  '/ip4/127.0.0.1/tcp/127/webrtc-direct',
  '/ip4/127.0.0.1/tcp/127/webrtc',
  '/http-path/tmp%2Fbar',
  '/http-path/tmp%2Fbar%2Fbaz',
  '/http-path/foo',
  '/ip4/127.0.0.1/tcp/0/p2p/12D3KooWCryG7Mon9orvQxcS1rYZjotPgpwoJNHHKcLLfE4Hf5mV/http-path/foo',
  '/ip4/127.0.0.1/tcp/443/tls/sni/example.com/http/http-path/foo',
  '/memory/4',
  '/ipfs/k2k4r8oqamigqdo6o7hsbfwd45y70oyynp98usk7zmyfrzpqxh1pohl7',
  '/p2p/k2k4r8oqamigqdo6o7hsbfwd45y70oyynp98usk7zmyfrzpqxh1pohl7',
  '/p2p/k51qzi5uqu5dhb6l8spkdx7yxafegfkee5by8h7lmjh2ehc2sgg34z7c15vzqs',
  '/ipfs/k2k4r8oqamigqdo6o7hsbfwd45y70oyynp98usk7zmyfrzpqxh1pohl7/tcp/1234',
  '/p2p/k2k4r8oqamigqdo6o7hsbfwd45y70oyynp98usk7zmyfrzpqxh1pohl7/tcp/1234',
  '/ip4/127.0.0.1/ipfs/k2k4r8oqamigqdo6o7hsbfwd45y70oyynp98usk7zmyfrzpqxh1pohl7',
  '/ip4/127.0.0.1/ipfs/k2k4r8oqamigqdo6o7hsbfwd45y70oyynp98usk7zmyfrzpqxh1pohl7/tcp/1234',
  '/ip4/127.0.0.1/p2p/k2k4r8oqamigqdo6o7hsbfwd45y70oyynp98usk7zmyfrzpqxh1pohl7',
  '/ip4/127.0.0.1/p2p/k2k4r8oqamigqdo6o7hsbfwd45y70oyynp98usk7zmyfrzpqxh1pohl7/tcp/1234',
  '/ip4/127.0.0.1/ipfs/k2k4r8oqamigqdo6o7hsbfwd45y70oyynp98usk7zmyfrzpqxh1pohl7/tcp/1234/unix/stdio',
  '/ip4/127.0.0.1/p2p/k2k4r8oqamigqdo6o7hsbfwd45y70oyynp98usk7zmyfrzpqxh1pohl7/tcp/1234/unix/stdio',
];

const _bad = [
  '/ip4',
  '/ip4/::1',
  '/ip4/fdpsofodsajfdoisa',
  '/ip4/::/ipcidr/256',
  '/ip6/::/ipcidr/1026',
  '/ip6',
  '/ip6zone',
  '/ip6zone/',
  '/ip6zone//ip6/fe80::1',
  '/udp',
  '/tcp',
  '/sctp',
  '/udp/65536',
  '/tcp/65536',
  '/quic/65536',
  '/quic-v1/65536',
  '/onion/9imaq4ygg2iegci7:80',
  '/onion/aaimaq4ygg2iegci7:80',
  '/onion/timaq4ygg2iegci7:0',
  '/onion/timaq4ygg2iegci7:-1',
  '/onion/timaq4ygg2iegci7',
  '/onion/timaq4ygg2iegci@:666',
  '/onion3/9ww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd:80',
  '/onion3/vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd7:80',
  '/onion3/vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd:0',
  '/onion3/vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd:-1',
  '/onion3/vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd',
  '/onion3/vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyy@:666',
  '/garlic32/566niximlxdzpanmn4qouucvua3k7neniwss47li5r6ugoertzu',
  '/garlic32/566niximlxdzpanmn4qouucvua3k7neniwss47li5r6ugoertzu77',
  '/garlic32/566niximlxdzpanmn4qouucvua3k7neniwss47li5r6ugoertzu:80',
  '/garlic32/566niximlxdzpanmn4qouucvua3k7neniwss47li5r6ugoertzuq:-1',
  '/garlic32/566niximlxdzpanmn4qouucvua3k7neniwss47li5r6ugoertzu@',
  '/udp/1234/sctp',
  '/udp/1234/udt/1234',
  '/udp/1234/utp/1234',
  '/ip4/127.0.0.1/udp/jfodsajfidosajfoidsa',
  '/ip4/127.0.0.1/udp',
  '/ip4/127.0.0.1/tcp/jfodsajfidosajfoidsa',
  '/ip4/127.0.0.1/tcp',
  '/ip4/127.0.0.1/quic/1234',
  '/ip4/127.0.0.1/quic-v1/1234',
  '/ip4/127.0.0.1/udp/1234/quic-v1/webtransport/certhash',
  // 1 character missing from certhash.
  '/ip4/127.0.0.1/udp/1234/quic-v1/webtransport/certhash/b2uaraocy6yrdblb4sfptaddgimjmmp',
  '/ip4/127.0.0.1/ipfs',
  '/ip4/127.0.0.1/ipfs/tcp',
  '/ip4/127.0.0.1/p2p',
  '/ip4/127.0.0.1/p2p/tcp',
  '/unix',
  '/ip4/1.2.3.4/tcp/80/unix',
  '/ip4/1.2.3.4/tcp/-1',
  '/ip4/127.0.0.1/tcp/9090/http/p2p-webcrt-direct',
  '/memory/92233720368547758081', // 2^63 with a stray trailing digit, unparseable as u64
  '/',
  '',
  // sha256 multihash with digest len > 32.
  '/p2p/QmxoHT6iViN5xAjoz1VZ553cL31U9F94ht3QvWR1FrEbZY',
];

void main() {
  group('Multiaddr.parse -- must succeed (go-multiaddr `good`)', () {
    for (final s in _good) {
      test(s, () {
        final m = Multiaddr.parse(s);
        // Round-trips through the binary wire form losslessly.
        final back = Multiaddr.fromBytes(m.toBytes());
        expect(back, equals(m));
      });
    }
  });

  group('Multiaddr.parse -- must fail (go-multiaddr TestConstructFails)', () {
    for (final s in _bad) {
      test(s.isEmpty ? '(empty string)' : s, () {
        expect(() => Multiaddr.parse(s), throwsA(anything));
      });
    }
  });

  group('Multiaddr.fromBytes', () {
    test('rejects an empty byte sequence', () {
      expect(() => Multiaddr.fromBytes(Uint8List(0)), throwsA(anything));
    });
  });

  group('p2p transcoder cross-base parity', () {
    test('base58, base32, and base36 Cid PeerIds decode to the same value', () {
      final fromB58 = Multiaddr.parse(
        '/p2p/QmcgpsyWgH8Y8ajJz1Cu72KnS5uo2Aa2LpzU7kinSupNKC',
      );
      final fromB32 = Multiaddr.parse(
        '/p2p/bafzbeigvf25ytwc3akrijfecaotc74udrhcxzh2cx3we5qqnw5vgrei4bm',
      );
      final fromB36 = Multiaddr.parse(
        '/p2p/k2k4r8oqamigqdo6o7hsbfwd45y70oyynp98usk7zmyfrzpqxh1pohl7',
      );
      expect(fromB32.toBytes(), equals(fromB58.toBytes()));
      expect(fromB36.toBytes(), equals(fromB58.toBytes()));
    });
  });

  group('encapsulate / decapsulate', () {
    test('decapsulate removes the matched suffix', () {
      final a = Multiaddr.parse('/ip4/1.2.3.4/tcp/1234');
      final b = a.decapsulate(Multiaddr.parse('/ip4/1.2.3.4'));
      expect(b, equals(Multiaddr.empty));
    });

    test('encapsulate then decapsulate round-trips', () {
      final base = Multiaddr.parse('/ip4/1.2.3.4');
      final tail = Multiaddr.parse('/tcp/1234');
      final joined = base.encapsulate(tail);
      expect(joined.toAddrString(), '/ip4/1.2.3.4/tcp/1234');
      expect(joined.decapsulate(tail), equals(base));
    });
  });

  group('valueForProtocol', () {
    test('finds the first matching component', () {
      final m = Multiaddr.parse('/ip4/1.2.3.4/tcp/1234');
      expect(m.valueForProtocol(Protocols.ip4), '1.2.3.4');
      expect(m.valueForProtocol(Protocols.tcp), '1234');
      expect(m.valueForProtocol(Protocols.udp), isNull);
    });
  });

  group('splitLast', () {
    // Vectors from go-multiaddr's own TestSplitFirstLast
    // (util_test.go), for the addresses built by progressively
    // appending /ip4, /tcp, /quic, /ipfs.
    const ip = '/ip4/0.0.0.0';
    const tcp = '/tcp/123';
    const quic = '/quic';
    const ipfs = '/ipfs/QmPSQnBKM9g7BaUcZCvswUJVscQ1ipjmwxN5PXCjkp9EQ7';

    test('splits the last component off a multi-component address', () {
      final m = Multiaddr.parse('$ip$tcp$quic$ipfs');
      final (prefix, last) = m.splitLast();
      expect(prefix, equals(Multiaddr.parse('$ip$tcp$quic')));
      expect(last, equals(Multiaddr.parse(ipfs).components.single));
    });

    test('a single-component address has a null prefix', () {
      final m = Multiaddr.parse(ip);
      final (prefix, last) = m.splitLast();
      expect(prefix, isNull);
      expect(last, equals(Multiaddr.parse(ip).components.single));
    });

    test('the empty address has a null prefix and last component', () {
      final (prefix, last) = Multiaddr.empty.splitLast();
      expect(prefix, isNull);
      expect(last, isNull);
    });
  });
}
