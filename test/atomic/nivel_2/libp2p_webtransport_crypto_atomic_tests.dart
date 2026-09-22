// Atomic tests for the WebTransport certificate machinery in
// `packages/transpiled_libp2p/lib/src/p2p/transport/webtransport/crypto.dart`
// and `.../cert_manager.dart` -- the port of go-libp2p's `crypto.go` and
// `cert_manager.go`.
//
// Level 2 rather than 1: `CertManager.create` arms a real rollover timer, so
// these need a live event loop, even though nothing here touches the network.
//
// The RSA branch of `verifyRawCerts` has no test: reaching it needs an
// RSA-signed certificate, and nothing in this project can produce one --
// go-libp2p itself only ever generates ECDSA P-256 here.
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:test/test.dart';
import 'package:transpiled_libp2p/src/p2p/transport/webtransport/cert_manager.dart';
import 'package:transpiled_libp2p/src/p2p/transport/webtransport/crypto.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart'
    show generateEcdsaKeyPair;

void main() {
  group('WebtransportCertificate [Atomic Audit]', () {
    test(
      'sha256 - is the SHA-256 of the DER, which is what a certhash pins',
      () async {
        final key = generateEcdsaKeyPair();
        final start = DateTime.utc(2026, 1, 1);
        final cert = await generateCert(key, start, start.add(certValidity));
        expect(
          cert.sha256,
          orderedEquals(sha256.convert(cert.certificateDer).bytes),
        );
      },
    );

    test(
      'sign() - signs deterministically, so the certificate is a function of '
      'the host key and the window alone',
      () async {
        final key = generateEcdsaKeyPair();
        final start = DateTime.utc(2026, 1, 1);
        final cert = await generateCert(key, start, start.add(certValidity));
        final message = Uint8List.fromList('transcript'.codeUnits);
        expect(
          await cert.sign(message),
          orderedEquals(await cert.sign(message)),
        );
      },
    );
  });

  group('functions - WebTransport certificates [Atomic Audit]', () {
    test(
      'generateCert() - the same key and start give the same certificate',
      () async {
        final key = generateEcdsaKeyPair();
        final start = DateTime.utc(2026, 3, 4, 5, 6, 7);
        final first = await generateCert(key, start, start.add(certValidity));
        final second = await generateCert(key, start, start.add(certValidity));
        expect(first.certificateDer, orderedEquals(second.certificateDer));
      },
    );

    test(
      'generateCert() - a different start gives a different certificate',
      () async {
        final key = generateEcdsaKeyPair();
        final start = DateTime.utc(2026, 3, 4, 5, 6, 7);
        final first = await generateCert(key, start, start.add(certValidity));
        final later = start.add(const Duration(days: 1));
        final second = await generateCert(key, later, later.add(certValidity));
        expect(
          first.certificateDer,
          isNot(orderedEquals(second.certificateDer)),
        );
      },
    );

    test(
      'generateCert() - a different key gives a different certificate',
      () async {
        final start = DateTime.utc(2026, 3, 4);
        final first = await generateCert(
          generateEcdsaKeyPair(),
          start,
          start.add(certValidity),
        );
        final second = await generateCert(
          generateEcdsaKeyPair(),
          start,
          start.add(certValidity),
        );
        expect(
          first.certificateDer,
          isNot(orderedEquals(second.certificateDer)),
        );
      },
    );

    test('generateCert() - records the window it was asked for', () async {
      final start = DateTime.utc(2026, 3, 4);
      final cert = await generateCert(
        generateEcdsaKeyPair(),
        start,
        start.add(certValidity),
      );
      expect(cert.notBefore, equals(start));
      expect(cert.notAfter, equals(start.add(certValidity)));
    });

    test(
      'verifyRawCerts() - accepts a certificate pinned by its own hash',
      () async {
        final start = DateTime.now().toUtc().subtract(const Duration(hours: 1));
        final cert = await generateCert(
          generateEcdsaKeyPair(),
          start,
          start.add(certValidity),
        );
        expect(
          () => verifyRawCerts([cert.certificateDer], [cert.sha256]),
          returnsNormally,
        );
      },
    );

    test('verifyRawCerts() - throws CertHashMismatchException when no pinned '
        'hash matches', () async {
      final start = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      final cert = await generateCert(
        generateEcdsaKeyPair(),
        start,
        start.add(certValidity),
      );
      expect(
        () => verifyRawCerts([cert.certificateDer], [Uint8List(32)]),
        throwsA(isA<CertHashMismatchException>()),
      );
    });

    test('verifyRawCerts() - throws when there is no certificate at all', () {
      expect(
        () => verifyRawCerts([], [Uint8List(32)]),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'verifyRawCerts() - rejects a certificate valid for longer than 14 '
      'days, which is what made the libp2p identity certificate undiallable',
      () async {
        final start = DateTime.now().toUtc().subtract(const Duration(hours: 1));
        final cert = await generateCert(
          generateEcdsaKeyPair(),
          start,
          start.add(const Duration(days: 15)),
        );
        expect(
          () => verifyRawCerts([cert.certificateDer], [cert.sha256]),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('longer than 14 days'),
            ),
          ),
        );
      },
    );

    test(
      'verifyRawCerts() - rejects a certificate that is not valid yet',
      () async {
        final start = DateTime.utc(2030, 1, 1);
        final cert = await generateCert(
          generateEcdsaKeyPair(),
          start,
          start.add(certValidity),
        );
        expect(
          () => verifyRawCerts(
            [cert.certificateDer],
            [cert.sha256],
            now: DateTime.utc(2029, 1, 1),
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('cert not valid'),
            ),
          ),
        );
      },
    );

    test('verifyRawCerts() - rejects an expired certificate', () async {
      final start = DateTime.utc(2020, 1, 1);
      final cert = await generateCert(
        generateEcdsaKeyPair(),
        start,
        start.add(certValidity),
      );
      expect(
        () => verifyRawCerts(
          [cert.certificateDer],
          [cert.sha256],
          now: DateTime.utc(2021, 1, 1),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('currentBucketStartTime() - two instants inside one bucket give the '
        'same start, which is what survives a restart', () {
      const offset = Duration.zero;
      final anchor = currentBucketStartTime(DateTime.utc(2026, 5, 1), offset);
      expect(
        currentBucketStartTime(anchor.add(const Duration(days: 3)), offset),
        equals(anchor),
      );
    });

    test('currentBucketStartTime() - the next bucket starts exactly one stride '
        'later', () {
      const offset = Duration.zero;
      final anchor = currentBucketStartTime(DateTime.utc(2026, 5, 1), offset);
      final next = currentBucketStartTime(
        anchor.add(validityMinusTwoSkew).add(const Duration(minutes: 1)),
        offset,
      );
      expect(next.difference(anchor), equals(validityMinusTwoSkew));
    });

    test(
      'currentBucketStartTime() - the offset shifts the boundary by itself',
      () {
        const offset = Duration(minutes: 37);
        final plain = currentBucketStartTime(
          DateTime.utc(2026, 5, 1),
          Duration.zero,
        );
        final shifted = currentBucketStartTime(
          DateTime.utc(2026, 5, 1),
          offset,
        );
        expect(shifted.difference(plain), equals(offset));
      },
    );
  });

  group('CertHashMismatchException [Atomic Audit]', () {
    test('toString() - names the hash seen and the hashes expected', () {
      final exception = CertHashMismatchException(
        expected: Uint8List.fromList([0xde, 0xad]),
        actual: [
          Uint8List.fromList([0xbe, 0xef]),
        ],
      );
      expect(exception.toString(), contains('dead'));
      expect(exception.toString(), contains('beef'));
    });
  });

  group('CertManager [Atomic Audit]', () {
    test('current - is the certificate the cert manager hands the TLS '
        'handshake, and the first hash it advertises', () async {
      final manager = await CertManager.create(generateEcdsaKeyPair());
      try {
        expect(manager.current.certificateDer, isNotEmpty);
        expect(manager.current.sha256, orderedEquals(manager.certHashes.first));
      } finally {
        manager.close();
      }
    });

    test('create() - the current certificate is valid now and for no more than '
        '14 days', () async {
      final manager = await CertManager.create(generateEcdsaKeyPair());
      try {
        final now = DateTime.now().toUtc();
        expect(manager.current.notBefore.isBefore(now), isTrue);
        expect(manager.current.notAfter.isAfter(now), isTrue);
        expect(
          manager.current.notAfter.difference(manager.current.notBefore),
          lessThanOrEqualTo(certValidity),
        );
      } finally {
        manager.close();
      }
    });

    test('create() - the same host key rebuilds the same certificate, so a '
        'restart keeps a certhash a peer may have cached', () async {
      final key = generateEcdsaKeyPair();
      final first = await CertManager.create(key);
      final second = await CertManager.create(key);
      try {
        expect(
          first.current.certificateDer,
          orderedEquals(second.current.certificateDer),
        );
      } finally {
        first.close();
        second.close();
      }
    });

    test(
      'next - takes over where the current certificate leaves off, overlapping '
      'it by two skew allowances',
      () async {
        final manager = await CertManager.create(generateEcdsaKeyPair());
        try {
          expect(
            manager.next.certificateDer,
            isNot(orderedEquals(manager.current.certificateDer)),
          );
          expect(
            manager.next.notBefore,
            equals(manager.current.notAfter.subtract(clockSkewAllowance * 2)),
          );
        } finally {
          manager.close();
        }
      },
    );

    test('certHashes - advertises the current and next certificates before any '
        'rollover has happened', () async {
      final manager = await CertManager.create(generateEcdsaKeyPair());
      try {
        expect(manager.certHashes, hasLength(2));
        expect(manager.certHashes[0], orderedEquals(manager.current.sha256));
        expect(manager.certHashes[1], orderedEquals(manager.next.sha256));
      } finally {
        manager.close();
      }
    });

    test(
      'close() - is idempotent and leaves the certificates readable',
      () async {
        final manager = await CertManager.create(generateEcdsaKeyPair());
        manager.close();
        manager.close();
        expect(manager.current.certificateDer, isNotEmpty);
      },
    );
  });
}
