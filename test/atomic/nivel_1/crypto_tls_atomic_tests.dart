// test/atomic/nivel_1/crypto_tls_atomic_tests.dart
// Testes atomicos 1 para 1 para transpiled_crypto_tls (key_schedule.dart,
// cipher_suites.dart, alert.dart, record_layer.dart): a fundacao pura do
// TLS 1.3 (RFC 8446 Section 7) mais o record layer (RFC 8446 Section 5).
//
// Vetores:
//  - ACVP (key_schedule_test.go:TestACVPVectors, valores oficiais do NIST
//    ACVP-Server para TLS-v1.3-KDF-RFC8446), transcritos byte a byte.
//  - draft-ietf-tls-tls13-vectors-07 (key_schedule_test.go:TestTrafficKey).
//  - AEAD (AES-128-GCM, AES-256-GCM, ChaCha20-Poly1305): nao ha
//    cipher_suites_test.go com vetores TLS 1.3 no checkout esparso deste
//    projeto. Os vetores abaixo foram computados por um oraculo
//    independente (Python 3.14 + `cryptography` 46.0.5, AESGCM/
//    ChaCha20Poly1305), nao pelo proprio port em teste, para que o teste
//    prove byte a byte a construcao xorNonceAEAD (XOR da sequencia de
//    registro na mascara de nonce) e a primitiva pointycastle por baixo,
//    em vez de apenas um round-trip seal/open que se auto-confirmaria.
//  - Record layer (HalfConn.encrypt/decrypt, writeTls13Records,
//    readTls13Record): conn_test.go's own tests (TestDynamicRecordSizingWith*,
//    TestRecordBadVersionTLS13) drive a full net.Conn handshake with
//    *Config/x509, out of scope here (see record_layer.dart's header), so
//    they cannot be reused verbatim. Instead these tests reconstruct the
//    expected wire bytes independently via the already oracle-verified
//    CipherSuiteTls13Aead primitive (same pattern as the AEAD tests above),
//    proving HalfConn's framing (header-as-AAD, type-byte append, sequence-
//    as-nonce) rather than only a self-confirming encrypt/decrypt round
//    trip; the version-mismatch error text is checked against conn_test.go's
//    own `TestRecordBadVersionTLS13` expectation ("received record with
//    version 1111 when expecting version 303").

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:test/test.dart';
import 'package:transpiled_crypto_tls/transpiled_crypto_tls.dart';

Uint8List _hex(String s) => Uint8List.fromList(
  List<int>.generate(
    s.length ~/ 2,
    (i) => int.parse(s.substring(i * 2, i * 2 + 2), radix: 16),
  ),
);

String _toHex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('expandLabel [Atomic Audit]', () {
    // Porta de key_schedule_test.go:TestTrafficKey (draft-ietf-tls-tls13-vectors-07).
    test(
      'expandLabel() - HKDF-Expand-Label(key) casa com o vetor draft-tls13-vectors',
      () {
        final trafficSecret = _hex(
          'b67b7d690cc16c4e75e54213cb2d37b4e9c912bcded9105d42befd59d391ad38',
        );
        final wantKey = _hex('3fce516009c21727d0f2e4e86ee403bc');
        final got = expandLabel(
          crypto.sha256,
          trafficSecret,
          'key',
          Uint8List(0),
          16,
        );
        expect(_toHex(got), equals(_toHex(wantKey)));
      },
    );

    test(
      'expandLabel() - HKDF-Expand-Label(iv) casa com o vetor draft-tls13-vectors',
      () {
        final trafficSecret = _hex(
          'b67b7d690cc16c4e75e54213cb2d37b4e9c912bcded9105d42befd59d391ad38',
        );
        final wantIv = _hex('5d313eb2671276ee13000b30');
        final got = expandLabel(
          crypto.sha256,
          trafficSecret,
          'iv',
          Uint8List(0),
          12,
        );
        expect(_toHex(got), equals(_toHex(wantIv)));
      },
    );

    test('expandLabel() - lanca StateError quando label excede 255 bytes', () {
      final longLabel = 'x' * 250; // + 'tls13 ' prefix (6) pushes it over 255
      expect(
        () => expandLabel(
          crypto.sha256,
          Uint8List(32),
          longLabel,
          Uint8List(0),
          16,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('CipherSuiteTls13 [Atomic Audit]', () {
    // Porta de key_schedule_test.go:TestTrafficKey via cipherSuitesTLS13[0]
    // (TLS_AES_128_GCM_SHA256).
    test(
      'trafficKey() - casa key e iv do vetor draft-tls13-vectors via cipherSuitesTls13[0]',
      () {
        final trafficSecret = _hex(
          'b67b7d690cc16c4e75e54213cb2d37b4e9c912bcded9105d42befd59d391ad38',
        );
        final suite = cipherSuitesTls13[0];
        expect(suite.id, equals(tlsAes128GcmSha256));
        final result = suite.trafficKey(trafficSecret);
        expect(_toHex(result.key), equals('3fce516009c21727d0f2e4e86ee403bc'));
        expect(_toHex(result.iv), equals('5d313eb2671276ee13000b30'));
      },
    );

    test(
      'nextTrafficSecret() - produz 32 bytes para uma suite SHA-256 e e deterministico',
      () {
        final suite = cipherSuitesTls13[0];
        final secret = _hex('00' * 32);
        final next1 = suite.nextTrafficSecret(secret);
        final next2 = suite.nextTrafficSecret(secret);
        expect(next1.length, equals(32));
        expect(_toHex(next1), equals(_toHex(next2)));
        expect(_toHex(next1), isNot(equals(_toHex(secret))));
      },
    );

    test(
      'finishedHash() - produz um HMAC de 32 bytes e reage a transcript diferente',
      () {
        final suite = cipherSuitesTls13[0];
        final baseKey = _hex('11' * 32);
        final t1 = HandshakeTranscript(crypto.sha256)
          ..write(utf8.encode('client hello'));
        final t2 = HandshakeTranscript(crypto.sha256)
          ..write(utf8.encode('client hallo'));
        final h1 = suite.finishedHash(baseKey, t1);
        final h2 = suite.finishedHash(baseKey, t2);
        expect(h1.length, equals(32));
        expect(_toHex(h1), isNot(equals(_toHex(h2))));
      },
    );

    test(
      'exportKeyingMaterial() - closure retorna material determinado por label/context/length',
      () {
        final suite = cipherSuitesTls13[0];
        final early = EarlySecret(crypto.sha256, Uint8List(32));
        final hs = early.handshakeSecret(_hex('22' * 32));
        final master = hs.masterSecret();
        final transcript = HandshakeTranscript(crypto.sha256)
          ..write(utf8.encode('finished'));
        final exporter = suite.exportKeyingMaterial(master, transcript);
        final a = exporter('EXPORTER-test', Uint8List(0), 20);
        final b = exporter('EXPORTER-test', Uint8List(0), 20);
        final c = exporter('EXPORTER-other', Uint8List(0), 20);
        expect(a.length, equals(20));
        expect(_toHex(a), equals(_toHex(b)));
        expect(_toHex(a), isNot(equals(_toHex(c))));
      },
    );
  });

  group('EarlySecret [Atomic Audit]', () {
    // Porta de key_schedule_test.go:TestACVPVectors (vetores oficiais NIST
    // ACVP-Server, TLS-v1.3-KDF-RFC8446).
    final psk = _hex(
      '56288B726C73829F7A3E47B103837C8139ACF552E7530C7A710B35ED41191698',
    );
    final dhe = _hex(
      'EFFE9EC26AA29FD750DFA6A10B944D74071595B27EE88887D5E11C84590B5CC3',
    );
    final helloClientRandom = _hex(
      'E9137679E582BA7C1DB41CF725F86C6D09C8C05F297BAD9A65B552EAF524FDE4',
    );
    final helloServerRandom = _hex(
      '23ECCFD030790748C8F8D8A656FD98D717F1B62AF3712F97211D2070B499F98A',
    );
    final finishedServerRandom = _hex(
      'C750EDA6696CD101B142BD79E00E6AC8C5F2C0ABC78DD64F4D991326659E9299',
    );
    final finishedClientRandom = _hex(
      '62A62FA75563ED4FDCAA0BC16567B314871C304ACF06B0FFC3F08C1797594D43',
    );

    const clientEarlyTrafficSecret =
        '3272189698C3594D18F58EFA3F12B638A249515099BE7A2FA9836BABE74F0111';
    const earlyExporterMasterSecret =
        '88E078F562CDC930219F6A5E98A1CE8C6E5F3DAC5AC516459A96F2EF8F114C66';
    const clientHandshakeTrafficSecret =
        'B32306C3CE9932C460A1FE6C0F060593974842036B96FA45049B7352E71C2AD2';
    const serverHandshakeTrafficSecret =
        '22787F8CA269D34BC549AC8BA19F2040938A3AA370D7CC9D60F720882B88D01B';
    const clientApplicationTrafficSecret =
        '47D7EA08397B5871154B0FE85584BCC30A87C69E84D69B56007C5B21F76493BA';
    const serverApplicationTrafficSecret =
        'EFBDB0C873C0480DA57307083839A8984BE25B9A8545E4FCA029940FE2800565';
    const exporterMasterSecret =
        '8A43D787EE3804EAD4A2A5B32972F9896B696295645D7222E1FD081DDD939834';
    const resumptionMasterSecret =
        '5F4C961329C91044011ACBECB0B289282E0E3FED045CB3EA924DFFE5FE654B3D';

    test('clientEarlyTrafficSecret() - casa o vetor ACVP', () {
      final es = EarlySecret(crypto.sha256, psk);
      final transcript = HandshakeTranscript(crypto.sha256)
        ..write(helloClientRandom);
      expect(
        _toHex(es.clientEarlyTrafficSecret(transcript)).toUpperCase(),
        equals(clientEarlyTrafficSecret),
      );
    });

    test(
      'earlyExporterMasterSecret() - casa o vetor ACVP via testingOnlyExporterSecret()',
      () {
        final es = EarlySecret(crypto.sha256, psk);
        final transcript = HandshakeTranscript(crypto.sha256)
          ..write(helloClientRandom);
        final exp = es.earlyExporterMasterSecret(transcript);
        expect(
          _toHex(exp.testingOnlyExporterSecret()).toUpperCase(),
          equals(earlyExporterMasterSecret),
        );
      },
    );

    test(
      'handshakeSecret() - encadeia ate os vetores ACVP de handshake, master e resumption',
      () {
        final es = EarlySecret(crypto.sha256, psk);
        final earlyTranscript = HandshakeTranscript(crypto.sha256)
          ..write(helloClientRandom);
        // Consumido apenas para paridade com o fluxo do vetor upstream (a
        // transcript e reaproveitada de forma acumulativa nos passos abaixo).
        es.clientEarlyTrafficSecret(earlyTranscript);

        final hs = es.handshakeSecret(dhe);
        final hsTranscript = HandshakeTranscript(crypto.sha256)
          ..write(helloClientRandom)
          ..write(helloServerRandom);
        expect(
          _toHex(hs.clientHandshakeTrafficSecret(hsTranscript)).toUpperCase(),
          equals(clientHandshakeTrafficSecret),
        );
        expect(
          _toHex(hs.serverHandshakeTrafficSecret(hsTranscript)).toUpperCase(),
          equals(serverHandshakeTrafficSecret),
        );

        final master = hs.masterSecret();
        final msTranscript = HandshakeTranscript(crypto.sha256)
          ..write(helloClientRandom)
          ..write(helloServerRandom)
          ..write(finishedServerRandom);
        expect(
          _toHex(
            master.clientApplicationTrafficSecret(msTranscript),
          ).toUpperCase(),
          equals(clientApplicationTrafficSecret),
        );
        expect(
          _toHex(
            master.serverApplicationTrafficSecret(msTranscript),
          ).toUpperCase(),
          equals(serverApplicationTrafficSecret),
        );
        expect(
          _toHex(
            master
                .exporterMasterSecret(msTranscript)
                .testingOnlyExporterSecret(),
          ).toUpperCase(),
          equals(exporterMasterSecret),
        );

        final resTranscript = HandshakeTranscript(crypto.sha256)
          ..write(helloClientRandom)
          ..write(helloServerRandom)
          ..write(finishedServerRandom)
          ..write(finishedClientRandom);
        expect(
          _toHex(master.resumptionMasterSecret(resTranscript)).toUpperCase(),
          equals(resumptionMasterSecret),
        );
      },
    );

    test(
      'resumptionBinderKey() - 32 bytes deterministicos para um dado PSK',
      () {
        final es1 = EarlySecret(crypto.sha256, psk);
        final es2 = EarlySecret(crypto.sha256, psk);
        final k1 = es1.resumptionBinderKey();
        final k2 = es2.resumptionBinderKey();
        expect(k1.length, equals(32));
        expect(_toHex(k1), equals(_toHex(k2)));
      },
    );
  });

  group('HandshakeSecret [Atomic Audit]', () {
    test(
      'masterSecret() - produz um MasterSecret independente por HandshakeSecret',
      () {
        final es = EarlySecret(crypto.sha256, Uint8List(32));
        final hs = es.handshakeSecret(_hex('33' * 32));
        final master = hs.masterSecret();
        final transcript = HandshakeTranscript(crypto.sha256)
          ..write(utf8.encode('x'));
        expect(
          master.clientApplicationTrafficSecret(transcript).length,
          equals(32),
        );
      },
    );

    test(
      'clientHandshakeTrafficSecret() - 32 bytes, muda com a transcript',
      () {
        final es = EarlySecret(crypto.sha256, Uint8List(32));
        final hs = es.handshakeSecret(_hex('35' * 32));
        final t1 = HandshakeTranscript(crypto.sha256)..write(utf8.encode('ch'));
        final t2 = HandshakeTranscript(crypto.sha256)..write(utf8.encode('sh'));
        final a = hs.clientHandshakeTrafficSecret(t1);
        final b = hs.clientHandshakeTrafficSecret(t2);
        expect(a.length, equals(32));
        expect(_toHex(a), isNot(equals(_toHex(b))));
      },
    );

    test(
      'serverHandshakeTrafficSecret() - 32 bytes, distinto do client handshake traffic secret',
      () {
        final es = EarlySecret(crypto.sha256, Uint8List(32));
        final hs = es.handshakeSecret(_hex('36' * 32));
        final t = HandshakeTranscript(crypto.sha256)
          ..write(utf8.encode('ch+sh'));
        final client = hs.clientHandshakeTrafficSecret(t);
        final server = hs.serverHandshakeTrafficSecret(t);
        expect(server.length, equals(32));
        expect(_toHex(server), isNot(equals(_toHex(client))));
      },
    );
  });

  group('MasterSecret [Atomic Audit]', () {
    test(
      'exporterMasterSecret() - exporter() e determinado por label/context/length',
      () {
        final es = EarlySecret(crypto.sha384, Uint8List(48));
        final hs = es.handshakeSecret(_hex('44' * 48));
        final master = hs.masterSecret();
        final transcript = HandshakeTranscript(crypto.sha384)
          ..write(utf8.encode('server finished'));
        final exp = master.exporterMasterSecret(transcript);
        final out1 = exp.exporter('label-a', _hex('aa'), 24);
        final out2 = exp.exporter('label-a', _hex('bb'), 24);
        expect(out1.length, equals(24));
        expect(_toHex(out1), isNot(equals(_toHex(out2))));
      },
    );

    test(
      'clientApplicationTrafficSecret() - 32 bytes, muda com a transcript',
      () {
        final es = EarlySecret(crypto.sha256, Uint8List(32));
        final master = es.handshakeSecret(_hex('37' * 32)).masterSecret();
        final t1 = HandshakeTranscript(crypto.sha256)
          ..write(utf8.encode('fin-a'));
        final t2 = HandshakeTranscript(crypto.sha256)
          ..write(utf8.encode('fin-b'));
        final a = master.clientApplicationTrafficSecret(t1);
        final b = master.clientApplicationTrafficSecret(t2);
        expect(a.length, equals(32));
        expect(_toHex(a), isNot(equals(_toHex(b))));
      },
    );

    test(
      'serverApplicationTrafficSecret() - 32 bytes, distinto do client application traffic secret',
      () {
        final es = EarlySecret(crypto.sha256, Uint8List(32));
        final master = es.handshakeSecret(_hex('38' * 32)).masterSecret();
        final t = HandshakeTranscript(crypto.sha256)..write(utf8.encode('fin'));
        final client = master.clientApplicationTrafficSecret(t);
        final server = master.serverApplicationTrafficSecret(t);
        expect(server.length, equals(32));
        expect(_toHex(server), isNot(equals(_toHex(client))));
      },
    );

    test('resumptionMasterSecret() - 32 bytes, muda com a transcript', () {
      final es = EarlySecret(crypto.sha256, Uint8List(32));
      final master = es.handshakeSecret(_hex('39' * 32)).masterSecret();
      final t1 = HandshakeTranscript(crypto.sha256)
        ..write(utf8.encode('client-fin-a'));
      final t2 = HandshakeTranscript(crypto.sha256)
        ..write(utf8.encode('client-fin-b'));
      final a = master.resumptionMasterSecret(t1);
      final b = master.resumptionMasterSecret(t2);
      expect(a.length, equals(32));
      expect(_toHex(a), isNot(equals(_toHex(b))));
    });
  });

  group('ExporterMasterSecret [Atomic Audit]', () {
    test('exporter() - tamanho da saida obedece length pedido', () {
      final es = EarlySecret(crypto.sha256, Uint8List(32));
      final transcript = HandshakeTranscript(crypto.sha256)
        ..write(utf8.encode('early'));
      final exp = es.earlyExporterMasterSecret(transcript);
      expect(exp.exporter('l', Uint8List(0), 7).length, equals(7));
      expect(exp.exporter('l', Uint8List(0), 64).length, equals(64));
    });

    test(
      'testingOnlyExporterSecret() - casa o vetor ACVP earlyExporterMasterSecret',
      () {
        final psk = _hex(
          '56288B726C73829F7A3E47B103837C8139ACF552E7530C7A710B35ED41191698',
        );
        final helloClientRandom = _hex(
          'E9137679E582BA7C1DB41CF725F86C6D09C8C05F297BAD9A65B552EAF524FDE4',
        );
        final es = EarlySecret(crypto.sha256, psk);
        final transcript = HandshakeTranscript(crypto.sha256)
          ..write(helloClientRandom);
        final exp = es.earlyExporterMasterSecret(transcript);
        expect(
          _toHex(exp.testingOnlyExporterSecret()).toUpperCase(),
          equals(
            '88E078F562CDC930219F6A5E98A1CE8C6E5F3DAC5AC516459A96F2EF8F114C66',
          ),
        );
      },
    );
  });

  group('HandshakeTranscript [Atomic Audit]', () {
    test('write() - acumula bytes sucessivos sem reiniciar o digest', () {
      final t = HandshakeTranscript(crypto.sha256);
      t.write(utf8.encode('abc'));
      final direct = crypto.sha256.convert(utf8.encode('abc')).bytes;
      expect(_toHex(t.sum()), equals(_toHex(direct)));
      t.write(utf8.encode('def'));
      final combined = crypto.sha256.convert(utf8.encode('abcdef')).bytes;
      expect(_toHex(t.sum()), equals(_toHex(combined)));
    });

    test(
      'sum() - transcript vazia casa o digest de sha256 da string vazia',
      () {
        final t = HandshakeTranscript(crypto.sha256);
        expect(
          _toHex(t.sum()),
          equals(_toHex(crypto.sha256.convert(const <int>[]).bytes)),
        );
      },
    );
  });

  group('cipherSuiteTls13ById [Atomic Audit]', () {
    test(
      'cipherSuiteTls13ById() - encontra as 3 suites TLS versao 13 pelo id',
      () {
        expect(
          cipherSuiteTls13ById(tlsAes128GcmSha256)?.id,
          equals(tlsAes128GcmSha256),
        );
        expect(
          cipherSuiteTls13ById(tlsAes256GcmSha384)?.id,
          equals(tlsAes256GcmSha384),
        );
        expect(
          cipherSuiteTls13ById(tlsChacha20Poly1305Sha256)?.id,
          equals(tlsChacha20Poly1305Sha256),
        );
      },
    );

    test('cipherSuiteTls13ById() - retorna null para um id desconhecido', () {
      expect(cipherSuiteTls13ById(0x0000), isNull);
    });
  });

  group('mutualCipherSuiteTls13 [Atomic Audit]', () {
    test(
      'mutualCipherSuiteTls13() - seleciona a suite desejada quando presente em have',
      () {
        final result = mutualCipherSuiteTls13([
          tlsChacha20Poly1305Sha256,
          tlsAes128GcmSha256,
        ], tlsAes128GcmSha256);
        expect(result?.id, equals(tlsAes128GcmSha256));
      },
    );

    test(
      'mutualCipherSuiteTls13() - retorna null quando want nao esta em have',
      () {
        expect(
          mutualCipherSuiteTls13([
            tlsChacha20Poly1305Sha256,
          ], tlsAes128GcmSha256),
          isNull,
        );
      },
    );
  });

  group('CipherSuiteTls13Aead [Atomic Audit]', () {
    // Vetores computados por um oraculo independente (Python 3.14.2 +
    // `cryptography` 46.0.5 `AESGCM`/`ChaCha20Poly1305`), nao pelo port em
    // teste. key/aad/plaintext fixos; nonce (sequencia de registro) varia
    // para provar a construcao XOR de xorNonceAEAD, nao so a primitiva.
    final plaintext = utf8.encode('hello tls 1.3 aead');
    final aad = _hex('1703030013');
    // Mascara fixa (IV derivada) usada em todos os casos abaixo.
    final nonceMask = _hex('000000000000000000000001');

    test(
      'nonceSize - e 8 (sequencia de registro de 64 bits) para AES-GCM e ChaCha20-Poly1305',
      () {
        expect(aeadAesGcmTls13(Uint8List(16), nonceMask).nonceSize, equals(8));
        expect(
          aeadChaCha20Poly1305(Uint8List(32), nonceMask).nonceSize,
          equals(8),
        );
      },
    );

    test(
      'overhead - e 16 (tag de 128 bits) para AES-GCM e ChaCha20-Poly1305',
      () {
        expect(aeadAesGcmTls13(Uint8List(16), nonceMask).overhead, equals(16));
        expect(
          aeadChaCha20Poly1305(Uint8List(32), nonceMask).overhead,
          equals(16),
        );
      },
    );

    test(
      'explicitNonceLen - e 0 nesta versao do protocolo (nonce inteiro vem da mascara XOR sequencia)',
      () {
        expect(
          aeadAesGcmTls13(Uint8List(16), nonceMask).explicitNonceLen,
          equals(0),
        );
        expect(
          aeadChaCha20Poly1305(Uint8List(32), nonceMask).explicitNonceLen,
          equals(0),
        );
      },
    );

    test(
      'seal() - AES-128-GCM, sequencia 0, casa o vetor do oraculo independente',
      () {
        final key = Uint8List.fromList(
          List<int>.generate(16, (i) => i + 1),
        ); // 01..10
        final aead = aeadAesGcmTls13(key, nonceMask);
        final sealed = aead.seal(
          _hex('0000000000000000'),
          Uint8List.fromList(plaintext),
          aad,
        );
        expect(
          _toHex(sealed),
          equals(
            'b739d4b87bee1a5f28a82e943b95dcf200dcab720ca5a007da3e44e61099c9311639',
          ),
        );
      },
    );

    test(
      'seal() - AES-128-GCM, sequencia 3, XOR contra a mascara casa o segundo vetor',
      () {
        final key = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
        final aead = aeadAesGcmTls13(key, nonceMask);
        final sealed = aead.seal(
          _hex('0000000000000003'),
          Uint8List.fromList(plaintext),
          aad,
        );
        expect(
          _toHex(sealed),
          equals(
            'a49af81f01f2e5f2d25f6a91e523b9e5bd2dee67af9206856f865279e2f73fd600ee',
          ),
        );
      },
    );

    test(
      'seal() - AES-256-GCM, sequencia 0, casa o vetor do oraculo independente',
      () {
        final key = Uint8List.fromList(List<int>.generate(32, (i) => 0x10 + i));
        final aead = aeadAesGcmTls13(key, nonceMask);
        final sealed = aead.seal(
          _hex('0000000000000000'),
          Uint8List.fromList(plaintext),
          aad,
        );
        expect(
          _toHex(sealed),
          equals(
            'e8ebf333359825e9d67801d08fe12209b3e1c34b234f7e83c755381d9b6632556c04',
          ),
        );
      },
    );

    test(
      'seal() - ChaCha20-Poly1305, sequencia 0, casa o vetor do oraculo independente',
      () {
        final key = Uint8List.fromList(List<int>.generate(32, (i) => 0x20 + i));
        final aead = aeadChaCha20Poly1305(key, nonceMask);
        final sealed = aead.seal(
          _hex('0000000000000000'),
          Uint8List.fromList(plaintext),
          aad,
        );
        expect(
          _toHex(sealed),
          equals(
            '3b32b6da7925b362c920c5f01f876efdb14afdbf6c3ae019d6d521847bac19a5f8bc',
          ),
        );
      },
    );

    test(
      'seal() - ChaCha20-Poly1305, sequencia 3, XOR contra a mascara casa o segundo vetor',
      () {
        final key = Uint8List.fromList(List<int>.generate(32, (i) => 0x20 + i));
        final aead = aeadChaCha20Poly1305(key, nonceMask);
        final sealed = aead.seal(
          _hex('0000000000000003'),
          Uint8List.fromList(plaintext),
          aad,
        );
        expect(
          _toHex(sealed),
          equals(
            '44562646c4b11f7042beb95d1f225b9d2f9b4bafa73156d714f81d4422d3d5c97c14',
          ),
        );
      },
    );

    test('open() - AES-128-GCM round trip recupera o plaintext original', () {
      final key = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
      final aead = aeadAesGcmTls13(key, nonceMask);
      final seq = _hex('0000000000000007');
      final sealed = aead.seal(seq, Uint8List.fromList(plaintext), aad);
      final opened = aead.open(seq, sealed, aad);
      expect(_toHex(opened), equals(_toHex(plaintext)));
    });

    test(
      'open() - ChaCha20-Poly1305 round trip recupera o plaintext original',
      () {
        final key = Uint8List.fromList(List<int>.generate(32, (i) => 0x20 + i));
        final aead = aeadChaCha20Poly1305(key, nonceMask);
        final seq = _hex('0000000000000007');
        final sealed = aead.seal(seq, Uint8List.fromList(plaintext), aad);
        final opened = aead.open(seq, sealed, aad);
        expect(_toHex(opened), equals(_toHex(plaintext)));
      },
    );

    test(
      'open() - lanca AeadAuthenticationException quando a tag foi adulterada',
      () {
        final key = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
        final aead = aeadAesGcmTls13(key, nonceMask);
        final seq = _hex('0000000000000009');
        final sealed = aead.seal(seq, Uint8List.fromList(plaintext), aad);
        final tampered = Uint8List.fromList(sealed);
        tampered[tampered.length - 1] ^= 0xff;
        expect(
          () => aead.open(seq, tampered, aad),
          throwsA(isA<AeadAuthenticationException>()),
        );
      },
    );

    test(
      'open() - lanca AeadAuthenticationException para ChaCha20-Poly1305 com tag adulterada',
      () {
        final key = Uint8List.fromList(List<int>.generate(32, (i) => 0x20 + i));
        final aead = aeadChaCha20Poly1305(key, nonceMask);
        final seq = _hex('0000000000000009');
        final sealed = aead.seal(seq, Uint8List.fromList(plaintext), aad);
        final tampered = Uint8List.fromList(sealed);
        tampered[tampered.length - 1] ^= 0xff;
        expect(
          () => aead.open(seq, tampered, aad),
          throwsA(isA<AeadAuthenticationException>()),
        );
      },
    );
  });

  group('aeadAesGcmTls13 [Atomic Audit]', () {
    test(
      'aeadAesGcmTls13() - constroi um CipherSuiteTls13Aead com overhead de 16 bytes',
      () {
        final aead = aeadAesGcmTls13(
          Uint8List(16),
          _hex('000000000000000000000001'),
        );
        expect(aead.overhead, equals(16));
        expect(aead.nonceSize, equals(8));
      },
    );

    test(
      'aeadAesGcmTls13() - lanca ArgumentError quando a mascara de nonce nao tem 12 bytes',
      () {
        expect(
          () => aeadAesGcmTls13(Uint8List(16), Uint8List(4)),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });

  group('aeadChaCha20Poly1305 [Atomic Audit]', () {
    test(
      'aeadChaCha20Poly1305() - constroi um CipherSuiteTls13Aead com overhead de 16 bytes',
      () {
        final aead = aeadChaCha20Poly1305(
          Uint8List(32),
          _hex('000000000000000000000001'),
        );
        expect(aead.overhead, equals(16));
        expect(aead.nonceSize, equals(8));
      },
    );

    test(
      'aeadChaCha20Poly1305() - lanca ArgumentError quando a mascara de nonce nao tem 12 bytes',
      () {
        expect(
          () => aeadChaCha20Poly1305(Uint8List(32), Uint8List(4)),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });

  group('AeadAuthenticationException [Atomic Audit]', () {
    test('toString() - inclui a mensagem de falha', () {
      final e = AeadAuthenticationException('tag mismatch');
      expect(e.toString(), contains('tag mismatch'));
    });
  });

  // ---------------------------------------------------------------------
  // handshake_messages.dart -- vetores:
  //  - testes 'rejeita extensao duplicada' (ClientHelloMsg, ServerHelloMsg):
  //    hex transcrito literalmente de
  //    handshake_messages_test.go:TestRejectDuplicateExtensions (linhas
  //    571-589 do checkout esparso go-stdlib).
  //  - demais testes sao round-trip/error-path proprios deste port
  //    (construir campos concretos -> marshal() -> unmarshal() -> conferir
  //    os campos, ou alimentar bytes truncados/malformados e conferir a
  //    excecao tipada). handshake_messages_test.go:TestMarshalUnmarshal/
  //    TestFuzz sao dirigidos por testing/quick (aleatorios), nao
  //    transcritiveis byte a byte; TestRejectEmptySCTList/TestRejectEmptySCT
  //    constroem o vetor via marshal-then-mutate-bytes, nao uma string hex
  //    fixa -- o teste 'rejeita signed_certificate_timestamp de comprimento
  //    zero' abaixo reproduz a mesma intencao diretamente.
  // ---------------------------------------------------------------------

  group('HandshakeMessageFormatException [Atomic Audit]', () {
    test('toString() - inclui a mensagem original', () {
      const e = HandshakeMessageFormatException('truncated');
      expect(e.toString(), contains('truncated'));
      expect(e.message, equals('truncated'));
    });
  });

  group('KeyShare [Atomic Audit]', () {
    test('KeyShare() - preserva group e data', () {
      final data = Uint8List.fromList([1, 2, 3]);
      final ks = KeyShare(group: 29, data: data);
      expect(ks.group, equals(29));
      expect(ks.data, equals(data));
    });
  });

  group('PskIdentity [Atomic Audit]', () {
    test('PskIdentity() - preserva label e obfuscatedTicketAge', () {
      final label = Uint8List.fromList([9, 9]);
      final psk = PskIdentity(label: label, obfuscatedTicketAge: 12345);
      expect(psk.label, equals(label));
      expect(psk.obfuscatedTicketAge, equals(12345));
    });
  });

  group('ClientHelloMsg [Atomic Audit]', () {
    ClientHelloMsg buildFull() => ClientHelloMsg(
      vers: 0x0303,
      random: Uint8List(32)..[0] = 0x42,
      sessionId: Uint8List.fromList([1, 2, 3, 4]),
      cipherSuites: [0x1301, 0x1302, 0x1303],
      compressionMethods: Uint8List.fromList([0]),
      serverName: 'example.com',
      supportedCurves: [29, 23],
      supportedSignatureAlgorithms: [0x0403, 0x0807],
      alpnProtocols: ['h2', 'http/1.1'],
      supportedVersions: [0x0304],
      cookie: Uint8List.fromList([9, 9, 9]),
      keyShares: [KeyShare(group: 29, data: Uint8List(32)..[0] = 7)],
      pskModes: Uint8List.fromList([1]),
      pskIdentities: [
        PskIdentity(label: Uint8List.fromList([1, 2]), obfuscatedTicketAge: 42),
      ],
      pskBinders: [Uint8List(32)..[0] = 5],
    );

    test('marshal() - round trip preserva todos os campos implementados', () {
      final original = buildFull();
      final bytes = original.marshal();
      final parsed = ClientHelloMsg.unmarshal(bytes);

      expect(parsed.vers, equals(original.vers));
      expect(parsed.random, equals(original.random));
      expect(parsed.sessionId, equals(original.sessionId));
      expect(parsed.cipherSuites, equals(original.cipherSuites));
      expect(parsed.compressionMethods, equals(original.compressionMethods));
      expect(parsed.serverName, equals('example.com'));
      expect(parsed.supportedCurves, equals(original.supportedCurves));
      expect(
        parsed.supportedSignatureAlgorithms,
        equals(original.supportedSignatureAlgorithms),
      );
      expect(parsed.alpnProtocols, equals(original.alpnProtocols));
      expect(parsed.supportedVersions, equals(original.supportedVersions));
      expect(parsed.cookie, equals(original.cookie));
      expect(parsed.keyShares.single.group, equals(29));
      expect(
        parsed.keyShares.single.data,
        equals(original.keyShares.single.data),
      );
      expect(parsed.pskModes, equals(original.pskModes));
      expect(parsed.pskIdentities.single.obfuscatedTicketAge, equals(42));
      expect(parsed.pskBinders.single, equals(original.pskBinders.single));
      // pre_shared_key must land last on the wire (RFC 8446 4.2.11): rebuilding
      // and re-marshaling must reproduce identical bytes (determinism check).
      expect(parsed.marshal(), equals(bytes));
    });

    test('unmarshal() - round trip sem nenhuma extensao', () {
      final original = ClientHelloMsg(
        vers: 0x0303,
        random: Uint8List(32),
        sessionId: Uint8List(0),
        cipherSuites: [0x1301],
        compressionMethods: Uint8List.fromList([0]),
      );
      final parsed = ClientHelloMsg.unmarshal(original.marshal());
      expect(parsed.cipherSuites, equals([0x1301]));
      expect(parsed.serverName, isEmpty);
      expect(parsed.extensions, isEmpty);
    });

    test(
      'unmarshal() - lanca HandshakeMessageFormatException com bytes truncados',
      () {
        expect(
          () => ClientHelloMsg.unmarshal(Uint8List.fromList([1, 0, 0])),
          throwsA(isA<HandshakeMessageFormatException>()),
        );
      },
    );

    test(
      'unmarshal() - rejeita extensao duplicada (vetor TestRejectDuplicateExtensions)',
      () {
        final clientHelloBytes = _hex(
          '010000440303000000000000000000000000000000000000000000000000'
          '000000000000000000000000001c0000000a000800000568656c6c6f0000'
          '000a000800000568656c6c6f',
        );
        expect(
          () => ClientHelloMsg.unmarshal(clientHelloBytes),
          throwsA(isA<HandshakeMessageFormatException>()),
        );
      },
    );

    test('extensions - registra os IDs de extensao vistos, na ordem', () {
      final parsed = ClientHelloMsg.unmarshal(buildFull().marshal());
      expect(parsed.extensions, equals([0, 10, 13, 16, 43, 44, 51, 45, 41]));
    });

    test(
      'marshalWithoutBinders() - retorna o ClientHello sem a lista de binders',
      () {
        final original = buildFull();
        final full = original.marshal();
        final withoutBinders = original.marshalWithoutBinders();
        expect(withoutBinders.length, lessThan(full.length));
        expect(full.sublist(0, withoutBinders.length), equals(withoutBinders));
      },
    );

    test('updateBinders() - substitui pskBinders quando os tamanhos batem', () {
      final original = buildFull();
      final newBinder = Uint8List(32)..[0] = 0xAA;
      original.updateBinders([newBinder]);
      expect(original.pskBinders.single, equals(newBinder));
    });

    test(
      'updateBinders() - lanca ArgumentError quando a quantidade de binders difere',
      () {
        final original = buildFull();
        expect(() => original.updateBinders([]), throwsA(isA<ArgumentError>()));
      },
    );

    test(
      'updateBinders() - lanca ArgumentError quando o tamanho de um binder difere',
      () {
        final original = buildFull();
        expect(
          () => original.updateBinders([Uint8List(16)]),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });

  group('ServerHelloMsg [Atomic Audit]', () {
    test(
      'marshal() - round trip preserva os campos de um ServerHello completo',
      () {
        final original = ServerHelloMsg(
          vers: 0x0303,
          random: Uint8List(32)..[1] = 0x99,
          sessionId: Uint8List.fromList([5, 6]),
          cipherSuite: 0x1301,
          compressionMethod: 0,
          ocspStapling: true,
          ticketSupported: true,
          secureRenegotiationSupported: true,
          secureRenegotiation: Uint8List.fromList([1, 2, 3]),
          extendedMasterSecret: true,
          alpnProtocol: 'h2',
          scts: [
            Uint8List.fromList([0xAB, 0xCD]),
          ],
          supportedVersion: 0x0304,
          serverShare: KeyShare(group: 29, data: Uint8List(32)..[0] = 3),
          selectedIdentityPresent: true,
          selectedIdentity: 7,
          supportedPoints: Uint8List.fromList([0]),
          serverNameAck: true,
          cookie: Uint8List.fromList([1, 1, 1]),
        );

        final parsed = ServerHelloMsg.unmarshal(original.marshal());

        expect(parsed.vers, equals(original.vers));
        expect(parsed.random, equals(original.random));
        expect(parsed.sessionId, equals(original.sessionId));
        expect(parsed.cipherSuite, equals(original.cipherSuite));
        expect(parsed.ocspStapling, isTrue);
        expect(parsed.ticketSupported, isTrue);
        expect(parsed.secureRenegotiationSupported, isTrue);
        expect(
          parsed.secureRenegotiation,
          equals(original.secureRenegotiation),
        );
        expect(parsed.extendedMasterSecret, isTrue);
        expect(parsed.alpnProtocol, equals('h2'));
        expect(parsed.scts.single, equals(original.scts.single));
        expect(parsed.supportedVersion, equals(0x0304));
        expect(parsed.serverShare!.group, equals(29));
        expect(parsed.serverShare!.data, equals(original.serverShare!.data));
        expect(parsed.selectedIdentityPresent, isTrue);
        expect(parsed.selectedIdentity, equals(7));
        expect(parsed.supportedPoints, equals(original.supportedPoints));
        expect(parsed.serverNameAck, isTrue);
        expect(parsed.cookie, equals(original.cookie));
        expect(parsed.selectedGroup, isNull);
      },
    );

    test(
      'marshal() - HelloRetryRequest usa selectedGroup em vez de serverShare',
      () {
        final original = ServerHelloMsg(
          vers: 0x0303,
          random: Uint8List(32),
          sessionId: Uint8List(0),
          cipherSuite: 0x1301,
          cookie: Uint8List.fromList([7, 7]),
          selectedGroup: 23,
        );
        final parsed = ServerHelloMsg.unmarshal(original.marshal());
        expect(parsed.selectedGroup, equals(23));
        expect(parsed.serverShare, isNull);
        expect(parsed.cookie, equals(original.cookie));
      },
    );

    test('unmarshal() - round trip sem nenhuma extensao', () {
      final original = ServerHelloMsg(
        vers: 0x0303,
        random: Uint8List(32),
        sessionId: Uint8List(0),
        cipherSuite: 0x1301,
      );
      final parsed = ServerHelloMsg.unmarshal(original.marshal());
      expect(parsed.cipherSuite, equals(0x1301));
      expect(parsed.ocspStapling, isFalse);
    });

    test(
      'unmarshal() - rejeita extensao duplicada (vetor TestRejectDuplicateExtensions)',
      () {
        final serverHelloBytes = _hex(
          '02000030030300000000000000000000000000000000000000000000000000'
          '0000000000000000000000080005000000050000',
        );
        expect(
          () => ServerHelloMsg.unmarshal(serverHelloBytes),
          throwsA(isA<HandshakeMessageFormatException>()),
        );
      },
    );

    test(
      'unmarshal() - rejeita signed_certificate_timestamp de comprimento zero',
      () {
        // Inspirado em handshake_messages_test.go:TestRejectEmptySCT: uma
        // extensao SCT cuja lista interna contem uma entrada de tamanho 0 deve
        // ser rejeitada (RFC 6962, Secao 3.3.1).
        final original = ServerHelloMsg(
          vers: 0x0303,
          random: Uint8List(32),
          sessionId: Uint8List(0),
          cipherSuite: 0x1301,
          scts: [
            Uint8List.fromList([1, 2, 3, 4]),
          ],
        );
        final validBytes = original.marshal();

        // Locate the 4-byte SCT payload and replace the sct-list contents with
        // a single zero-length entry (extension_data becomes: list_len=0002,
        // sct_len=0000), then fix up the length fields that wrap it.
        final sctPattern = [1, 2, 3, 4];
        var i = -1;
        for (var j = 0; j + sctPattern.length <= validBytes.length; j++) {
          if (validBytes[j] == sctPattern[0] &&
              validBytes[j + 1] == sctPattern[1] &&
              validBytes[j + 2] == sctPattern[2] &&
              validBytes[j + 3] == sctPattern[3]) {
            i = j;
            break;
          }
        }
        expect(
          i,
          greaterThan(0),
          reason: 'fixture SCT payload not found in marshaled bytes',
        );

        final mutated = <int>[
          ...validBytes.sublist(
            0,
            i - 2,
          ), // up to (but excluding) the sct entry's 2-byte length prefix
          0,
          0, // sct-list length = 0 (was 0x0006: 2-byte entry-len prefix + 4 payload bytes)
          ...validBytes.sublist(i + 4), // resume right after the removed entry
        ];
        // Fix up the outer handshake length (bytes[1..3]) and the extensions
        // block length (bytes[42..43]): both shrank by 6 bytes (the removed
        // 2-byte sct entry length prefix + 4-byte payload).
        const shrinkBy = 6;
        final outerLen =
            ((mutated[1] << 16) | (mutated[2] << 8) | mutated[3]) - shrinkBy;
        mutated[1] = (outerLen >> 16) & 0xFF;
        mutated[2] = (outerLen >> 8) & 0xFF;
        mutated[3] = outerLen & 0xFF;
        final extLen = ((mutated[42] << 8) | mutated[43]) - shrinkBy;
        mutated[42] = (extLen >> 8) & 0xFF;
        mutated[43] = extLen & 0xFF;

        expect(
          () => ServerHelloMsg.unmarshal(Uint8List.fromList(mutated)),
          throwsA(isA<HandshakeMessageFormatException>()),
        );
      },
    );
  });

  group('EncryptedExtensionsMsg [Atomic Audit]', () {
    test(
      'marshal() - round trip preserva alpnProtocol, earlyData e serverNameAck',
      () {
        final original = EncryptedExtensionsMsg(
          alpnProtocol: 'h2',
          earlyData: true,
          serverNameAck: true,
        );
        final parsed = EncryptedExtensionsMsg.unmarshal(original.marshal());
        expect(parsed.alpnProtocol, equals('h2'));
        expect(parsed.earlyData, isTrue);
        expect(parsed.serverNameAck, isTrue);
      },
    );

    test('unmarshal() - round trip vazio', () {
      final parsed = EncryptedExtensionsMsg.unmarshal(
        EncryptedExtensionsMsg().marshal(),
      );
      expect(parsed.alpnProtocol, isEmpty);
      expect(parsed.earlyData, isFalse);
    });

    test(
      'unmarshal() - lanca HandshakeMessageFormatException em extensao duplicada',
      () {
        final b = EncryptedExtensionsMsg(earlyData: true).marshal();
        // Handcraft a second copy of the (empty) early_data extension appended
        // into the extensions block, then fix up both length fields.
        final earlyDataExt = [0, 42, 0, 0]; // extension id 42, length 0
        final mutated = <int>[...b, ...earlyDataExt];
        const grow = 4;
        final outerLen =
            ((mutated[1] << 16) | (mutated[2] << 8) | mutated[3]) + grow;
        mutated[1] = (outerLen >> 16) & 0xFF;
        mutated[2] = (outerLen >> 8) & 0xFF;
        mutated[3] = outerLen & 0xFF;
        final extLen = ((mutated[4] << 8) | mutated[5]) + grow;
        mutated[4] = (extLen >> 8) & 0xFF;
        mutated[5] = extLen & 0xFF;
        expect(
          () => EncryptedExtensionsMsg.unmarshal(Uint8List.fromList(mutated)),
          throwsA(isA<HandshakeMessageFormatException>()),
        );
      },
    );
  });

  group('EndOfEarlyDataMsg [Atomic Audit]', () {
    test('marshal() - round trip produz uma mensagem vazia de 4 bytes', () {
      const original = EndOfEarlyDataMsg();
      final bytes = original.marshal();
      expect(bytes.length, equals(4));
      expect(EndOfEarlyDataMsg.unmarshal(bytes), isA<EndOfEarlyDataMsg>());
    });

    test(
      'unmarshal() - lanca HandshakeMessageFormatException quando o tamanho nao e 4',
      () {
        expect(
          () => EndOfEarlyDataMsg.unmarshal(Uint8List.fromList([5, 0, 0])),
          throwsA(isA<HandshakeMessageFormatException>()),
        );
      },
    );
  });

  group('KeyUpdateMsg [Atomic Audit]', () {
    test('marshal() - round trip com updateRequested=true', () {
      final parsed = KeyUpdateMsg.unmarshal(
        KeyUpdateMsg(updateRequested: true).marshal(),
      );
      expect(parsed.updateRequested, isTrue);
    });

    test('unmarshal() - round trip com updateRequested=false', () {
      final parsed = KeyUpdateMsg.unmarshal(KeyUpdateMsg().marshal());
      expect(parsed.updateRequested, isFalse);
    });

    test(
      'unmarshal() - lanca HandshakeMessageFormatException para valor invalido',
      () {
        expect(
          () => KeyUpdateMsg.unmarshal(Uint8List.fromList([24, 0, 0, 1, 2])),
          throwsA(isA<HandshakeMessageFormatException>()),
        );
      },
    );
  });

  group('NewSessionTicketMsgTls13 [Atomic Audit]', () {
    test('marshal() - round trip com maxEarlyData presente', () {
      final original = NewSessionTicketMsgTls13(
        lifetime: 7200,
        ageAdd: 0xDEADBEEF,
        nonce: Uint8List.fromList([1]),
        label: Uint8List.fromList([2, 3, 4]),
        maxEarlyData: 16384,
      );
      final parsed = NewSessionTicketMsgTls13.unmarshal(original.marshal());
      expect(parsed.lifetime, equals(7200));
      expect(parsed.ageAdd, equals(0xDEADBEEF));
      expect(parsed.nonce, equals(original.nonce));
      expect(parsed.label, equals(original.label));
      expect(parsed.maxEarlyData, equals(16384));
    });

    test('unmarshal() - round trip sem early_data (maxEarlyData=0)', () {
      final original = NewSessionTicketMsgTls13(
        lifetime: 100,
        ageAdd: 1,
        nonce: Uint8List.fromList([9]),
        label: Uint8List.fromList([1, 2]),
      );
      final parsed = NewSessionTicketMsgTls13.unmarshal(original.marshal());
      expect(parsed.maxEarlyData, equals(0));
    });
  });

  group('CertificateRequestMsgTls13 [Atomic Audit]', () {
    test(
      'marshal() - round trip preserva sigAlgs e certificate_authorities',
      () {
        final original = CertificateRequestMsgTls13(
          ocspStapling: true,
          scts: true,
          supportedSignatureAlgorithms: [0x0403, 0x0807],
          supportedSignatureAlgorithmsCert: [0x0401],
          certificateAuthorities: [
            Uint8List.fromList(utf8.encode('CA-one')),
            Uint8List.fromList(utf8.encode('CA-two')),
          ],
        );
        final parsed = CertificateRequestMsgTls13.unmarshal(original.marshal());
        expect(parsed.ocspStapling, isTrue);
        expect(parsed.scts, isTrue);
        expect(
          parsed.supportedSignatureAlgorithms,
          equals(original.supportedSignatureAlgorithms),
        );
        expect(
          parsed.supportedSignatureAlgorithmsCert,
          equals(original.supportedSignatureAlgorithmsCert),
        );
        expect(parsed.certificateAuthorities.length, equals(2));
        expect(utf8.decode(parsed.certificateAuthorities[0]), equals('CA-one'));
        expect(utf8.decode(parsed.certificateAuthorities[1]), equals('CA-two'));
      },
    );

    test('unmarshal() - round trip vazio', () {
      final parsed = CertificateRequestMsgTls13.unmarshal(
        CertificateRequestMsgTls13().marshal(),
      );
      expect(parsed.ocspStapling, isFalse);
      expect(parsed.certificateAuthorities, isEmpty);
    });
  });

  group('CertificateMsgTls13 [Atomic Audit]', () {
    test(
      'marshal() - round trip com cadeia de 2 certificados e OCSP/SCT no leaf',
      () {
        final leaf = Uint8List.fromList(List<int>.generate(10, (i) => i));
        final intermediate = Uint8List.fromList(
          List<int>.generate(8, (i) => 0xF0 + i),
        );
        final original = CertificateMsgTls13(
          certificateChain: [leaf, intermediate],
          ocspStaple: Uint8List.fromList([1, 2, 3]),
          signedCertificateTimestamps: [
            Uint8List.fromList([9, 9]),
          ],
          ocspStapling: true,
          scts: true,
        );
        final parsed = CertificateMsgTls13.unmarshal(original.marshal());
        expect(parsed.certificateChain.length, equals(2));
        expect(parsed.certificateChain[0], equals(leaf));
        expect(parsed.certificateChain[1], equals(intermediate));
        expect(parsed.ocspStapling, isTrue);
        expect(parsed.ocspStaple, equals(original.ocspStaple));
        expect(parsed.scts, isTrue);
        expect(
          parsed.signedCertificateTimestamps!.single,
          equals(Uint8List.fromList([9, 9])),
        );
      },
    );

    test('unmarshal() - round trip sem OCSP nem SCT', () {
      final leaf = Uint8List.fromList([1, 2, 3, 4]);
      final parsed = CertificateMsgTls13.unmarshal(
        CertificateMsgTls13(certificateChain: [leaf]).marshal(),
      );
      expect(parsed.certificateChain.single, equals(leaf));
      expect(parsed.ocspStapling, isFalse);
      expect(parsed.ocspStaple, isNull);
      expect(parsed.scts, isFalse);
      expect(parsed.signedCertificateTimestamps, isNull);
    });
  });

  group('FinishedMsg [Atomic Audit]', () {
    test('marshal() - round trip preserva verifyData', () {
      final verifyData = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final parsed = FinishedMsg.unmarshal(
        FinishedMsg(verifyData: verifyData).marshal(),
      );
      expect(parsed.verifyData, equals(verifyData));
    });

    test(
      'unmarshal() - lanca HandshakeMessageFormatException com bytes truncados',
      () {
        expect(
          () => FinishedMsg.unmarshal(Uint8List.fromList([20, 0, 0, 5, 1, 2])),
          throwsA(isA<HandshakeMessageFormatException>()),
        );
      },
    );
  });

  group('CertificateVerifyMsg [Atomic Audit]', () {
    test(
      'marshal() - round trip com hasSignatureAlgorithm verdadeiro (modo TLS13)',
      () {
        final signature = Uint8List.fromList(List<int>.generate(64, (i) => i));
        final original = CertificateVerifyMsg(
          signatureAlgorithm: 0x0807,
          signature: signature,
        );
        final parsed = CertificateVerifyMsg.unmarshal(original.marshal());
        expect(parsed.hasSignatureAlgorithm, isTrue);
        expect(parsed.signatureAlgorithm, equals(0x0807));
        expect(parsed.signature, equals(signature));
      },
    );

    test('unmarshal() - round trip com hasSignatureAlgorithm falso', () {
      final signature = Uint8List.fromList([1, 2, 3]);
      final original = CertificateVerifyMsg(
        hasSignatureAlgorithm: false,
        signature: signature,
      );
      final bytes = original.marshal();
      final parsed = CertificateVerifyMsg.unmarshal(
        bytes,
        hasSignatureAlgorithm: false,
      );
      expect(parsed.hasSignatureAlgorithm, isFalse);
      expect(parsed.signatureAlgorithm, equals(0));
      expect(parsed.signature, equals(signature));
    });

    test(
      'unmarshal() - lanca HandshakeMessageFormatException com bytes truncados',
      () {
        expect(
          () => CertificateVerifyMsg.unmarshal(
            Uint8List.fromList([15, 0, 0, 2, 4]),
          ),
          throwsA(isA<HandshakeMessageFormatException>()),
        );
      },
    );
  });

  group('AlertException [Atomic Audit]', () {
    test('description - resolve o texto conhecido de alertBadRecordMac', () {
      expect(
        const AlertException(alertBadRecordMac).description,
        equals('bad record MAC'),
      );
    });

    test(
      'description - retorna fallback alert(codigo) para um codigo desconhecido',
      () {
        expect(const AlertException(200).description, equals('alert(200)'));
      },
    );

    test('toString() - inclui o prefixo tls: e a descricao', () {
      expect(
        const AlertException(alertCloseNotify).toString(),
        equals('tls: close notify'),
      );
    });

    test('code - preserva o valor passado no construtor', () {
      expect(const AlertException(alertHandshakeFailure).code, equals(40));
    });
  });

  group('HalfConn [Atomic Audit]', () {
    test(
      'HalfConn() - inicia sem cipher, sequencia zerada e version nao negociada',
      () {
        final half = HalfConn();
        expect(half.cipher, isNull);
        expect(half.version, equals(0));
        expect(half.seq, equals(Uint8List(8)));
      },
    );

    test('incSeq() - incrementa o byte menos significativo da sequencia', () {
      final half = HalfConn();
      half.incSeq();
      expect(_toHex(half.seq), equals(_toHex(_hex('0000000000000001'))));
      half.incSeq();
      expect(_toHex(half.seq), equals(_toHex(_hex('0000000000000002'))));
    });

    test(
      'incSeq() - propaga carry para o byte anterior apos 256 incrementos',
      () {
        final half = HalfConn();
        for (var i = 0; i < 256; i++) {
          half.incSeq();
        }
        expect(_toHex(half.seq), equals(_toHex(_hex('0000000000000100'))));
      },
    );

    test(
      'setTrafficSecret() - deriva cipher via a chave de trafego da suite e zera a sequencia',
      () {
        final half = HalfConn();
        half.incSeq();
        half.incSeq();
        final suite = cipherSuitesTls13[0];
        final secret = _hex('11' * 32);
        half.setTrafficSecret(suite, secret);
        expect(half.trafficSecret, equals(secret));
        expect(half.cipher, isNotNull);
        expect(half.seq, equals(Uint8List(8)));

        // O cipher derivado deve produzir a mesma saida que montar o AEAD
        // diretamente a partir de suite.trafficKey(secret) (key/iv).
        final keys = suite.trafficKey(secret);
        final directCipher = suite.aead(keys.key, keys.iv);
        final aad = _hex('1703030005');
        final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);
        final nonce = _hex('0000000000000000');
        expect(
          _toHex(half.cipher!.seal(nonce, plaintext, aad)),
          equals(_toHex(directCipher.seal(nonce, plaintext, aad))),
        );
      },
    );

    test(
      'changeCipherSpec() - lanca AlertException(alertInternalError) nesta variante restrita a TLS13',
      () {
        final half = HalfConn()..version = versionTls13;
        expect(
          () => half.changeCipherSpec(),
          throwsA(
            isA<AlertException>().having(
              (e) => e.code,
              'code',
              equals(alertInternalError),
            ),
          ),
        );
      },
    );

    test('explicitNonceLen - e 0 sem cipher e com cipher AEAD TLS13', () {
      final half = HalfConn();
      expect(half.explicitNonceLen, equals(0));
      half.setTrafficSecret(cipherSuitesTls13[0], _hex('22' * 32));
      expect(half.explicitNonceLen, equals(0));
    });

    test(
      'seq - reflete o estado atual da sequencia como copia defensiva (mutar o retorno nao afeta o estado)',
      () {
        final half = HalfConn();
        half.incSeq();
        final snapshot = half.seq;
        snapshot[0] = 0xff;
        expect(half.seq, equals(_hex('0000000000000001')));
      },
    );

    test(
      'encrypt() - monta o registro TLS 1.3 completo: outer type 23, '
      'AAD com o length final, type original anexado ao plaintext interno',
      () {
        final key = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
        final nonceMask = _hex('000000000000000000000001');
        final half = HalfConn()
          ..version = versionTls13
          ..cipher = aeadAesGcmTls13(key, nonceMask);
        final payload = Uint8List.fromList(utf8.encode('ping'));
        final header = Uint8List(5)
          ..[0] = recordTypeHandshake
          ..[1] = 0x03
          ..[2] = 0x03
          ..[3] = 0
          ..[4] = payload.length;

        final got = half.encrypt(header, payload);

        // Reconstroi o esperado de forma independente via o primitivo AEAD
        // (ja provado contra o oraculo Python no grupo CipherSuiteTls13Aead
        // acima), sem reusar HalfConn.encrypt em si.
        final independentAead = aeadAesGcmTls13(key, nonceMask);
        final innerPlaintext = Uint8List.fromList([
          ...payload,
          recordTypeHandshake,
        ]);
        final n = payload.length + 1 + independentAead.overhead;
        final aad = Uint8List.fromList([
          recordTypeApplicationData,
          0x03,
          0x03,
          (n >> 8) & 0xff,
          n & 0xff,
        ]);
        final ciphertext = independentAead.seal(
          _hex('0000000000000000'),
          innerPlaintext,
          aad,
        );
        final want = Uint8List.fromList([...aad, ...ciphertext]);

        expect(_toHex(got), equals(_toHex(want)));
        expect(got[0], equals(recordTypeApplicationData));
        expect(half.seq, equals(_hex('0000000000000001')));
      },
    );

    test(
      'encrypt() - sem cipher retorna header++payload sem alterar a sequencia',
      () {
        final half = HalfConn();
        final header = Uint8List(5)
          ..[0] = recordTypeHandshake
          ..[1] = 0x03
          ..[2] = 0x01
          ..[3] = 0
          ..[4] = 3;
        final payload = Uint8List.fromList([9, 9, 9]);
        final got = half.encrypt(header, payload);
        expect(got, equals(Uint8List.fromList([...header, ...payload])));
        expect(half.seq, equals(Uint8List(8)));
      },
    );

    test(
      'encrypt() - lanca ArgumentError quando o header nao tem recordHeaderLen bytes',
      () {
        final half = HalfConn();
        expect(
          () => half.encrypt(Uint8List(4), Uint8List(1)),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      'decrypt() - round trip recupera plaintext e recordType originais',
      () {
        final key = Uint8List.fromList(List<int>.generate(32, (i) => 0x30 + i));
        final nonceMask = _hex('000000000000000000000002');
        final out = HalfConn()
          ..version = versionTls13
          ..cipher = aeadChaCha20Poly1305(key, nonceMask);
        final inConn = HalfConn()
          ..version = versionTls13
          ..cipher = aeadChaCha20Poly1305(key, nonceMask);

        final payload = Uint8List.fromList(
          utf8.encode('finished-message-bytes'),
        );
        final header = Uint8List(5)
          ..[0] = recordTypeHandshake
          ..[1] = 0x03
          ..[2] = 0x03
          ..[3] = (payload.length >> 8) & 0xff
          ..[4] = payload.length & 0xff;
        final record = out.encrypt(header, payload);

        final decoded = inConn.decrypt(record);
        expect(decoded.recordType, equals(recordTypeHandshake));
        expect(_toHex(decoded.plaintext), equals(_toHex(payload)));
        expect(inConn.seq, equals(_hex('0000000000000001')));
      },
    );

    test(
      'decrypt() - ignora um registro change_cipher_spec sem tentar AEAD (RFC 8446 Appendix D.4)',
      () {
        final half = HalfConn()
          ..version = versionTls13
          ..cipher = aeadAesGcmTls13(
            Uint8List(16),
            _hex('000000000000000000000003'),
          );
        // Um CCS legado real e enviado em claro: 5 bytes de header + 1 byte
        // de corpo (0x01), sem tag AEAD -- decrypt() nao pode tentar abri-lo
        // como se fosse protegido.
        final record = Uint8List.fromList([
          recordTypeChangeCipherSpec,
          0x03,
          0x03,
          0x00,
          0x01,
          0x01,
        ]);
        final decoded = half.decrypt(record);
        expect(decoded.recordType, equals(recordTypeChangeCipherSpec));
        expect(decoded.plaintext, equals(Uint8List.fromList([0x01])));
        // A sequencia nao avanca: o retorno antecipado do RFC 8446 Appendix
        // D.4 pula o incSeq() do final de decrypt().
        expect(half.seq, equals(Uint8List(8)));
      },
    );

    test(
      'decrypt() - lanca AlertException(alertBadRecordMac) quando a tag foi adulterada',
      () {
        final key = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
        final nonceMask = _hex('000000000000000000000004');
        final out = HalfConn()
          ..version = versionTls13
          ..cipher = aeadAesGcmTls13(key, nonceMask);
        final inConn = HalfConn()
          ..version = versionTls13
          ..cipher = aeadAesGcmTls13(key, nonceMask);
        final payload = Uint8List.fromList([1, 2, 3]);
        final header = Uint8List(5)
          ..[0] = recordTypeApplicationData
          ..[1] = 0x03
          ..[2] = 0x03
          ..[3] = 0
          ..[4] = payload.length;
        final record = out.encrypt(header, payload);
        record[record.length - 1] ^= 0xff;
        expect(
          () => inConn.decrypt(record),
          throwsA(
            isA<AlertException>().having(
              (e) => e.code,
              'code',
              equals(alertBadRecordMac),
            ),
          ),
        );
      },
    );

    test(
      'decrypt() - lanca AlertException(alertUnexpectedMessage) quando o outer type nao e '
      'application_data com cipher ativo',
      () {
        final key = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
        final nonceMask = _hex('000000000000000000000005');
        final half = HalfConn()
          ..version = versionTls13
          ..cipher = aeadAesGcmTls13(key, nonceMask);
        // AEAD abre com sucesso (AAD/nonce corretos), mas o outer type nunca
        // deveria ser diferente de application_data quando o cipher ja esta
        // ativo (TLS 1.3 sempre obfusca o content type real dentro do
        // plaintext).
        final aead = aeadAesGcmTls13(key, nonceMask);
        final aad = Uint8List.fromList([
          recordTypeHandshake,
          0x03,
          0x03,
          0x00,
          0x14,
        ]);
        final ciphertext = aead.seal(
          _hex('0000000000000000'),
          Uint8List.fromList([1, 2, 3, recordTypeHandshake]),
          aad,
        );
        final record = Uint8List.fromList([...aad, ...ciphertext]);
        expect(
          () => half.decrypt(record),
          throwsA(
            isA<AlertException>().having(
              (e) => e.code,
              'code',
              equals(alertUnexpectedMessage),
            ),
          ),
        );
      },
    );

    test(
      'decrypt() - sem cipher retorna o payload como esta (registro nao protegido)',
      () {
        final half = HalfConn();
        final payload = Uint8List.fromList([7, 7, 7]);
        final record = Uint8List.fromList([
          recordTypeHandshake,
          0x03,
          0x01,
          0x00,
          0x03,
          ...payload,
        ]);
        final decoded = half.decrypt(record);
        expect(decoded.recordType, equals(recordTypeHandshake));
        expect(decoded.plaintext, equals(payload));
        expect(half.seq, equals(_hex('0000000000000001')));
      },
    );
  });

  group('writeTls13Records [Atomic Audit]', () {
    test(
      'writeTls13Records() - fragmenta em pedacos de no maximo maxPlaintext bytes',
      () {
        final half = HalfConn()
          ..version = versionTls13
          ..setTrafficSecret(cipherSuitesTls13[0], _hex('44' * 32));
        final data = Uint8List(maxPlaintext * 2 + 10);
        final records = writeTls13Records(
          half,
          recordTypeApplicationData,
          data,
        );
        expect(records.length, equals(3));
        // Cada registro = 5 bytes de header + fragmento + 1 byte de type
        // interno + 16 bytes de tag AEAD (AES-128-GCM).
        expect(records[0].length, equals(5 + maxPlaintext + 1 + 16));
        expect(records[1].length, equals(5 + maxPlaintext + 1 + 16));
        expect(records[2].length, equals(5 + 10 + 1 + 16));
      },
    );

    // RFC 8446 Section 5.1: TLS 1.3 freezes the on-wire record version to 1.2.
    test(
      'writeTls13Records() - usa versionTls12 no cabecalho quando version=versionTls13',
      () {
        final half =
            HalfConn(); // sem cipher: registro fica em claro, mais facil inspecionar o header.
        final records = writeTls13Records(
          half,
          recordTypeHandshake,
          Uint8List.fromList([1, 2, 3]),
        );
        expect(records.single[1], equals(0x03));
        expect(records.single[2], equals(0x03));
      },
    );

    test('writeTls13Records() - retorna lista vazia para dados vazios', () {
      final half = HalfConn();
      expect(
        writeTls13Records(half, recordTypeHandshake, Uint8List(0)),
        isEmpty,
      );
    });
  });

  group('readTls13Record [Atomic Audit]', () {
    test(
      'readTls13Record() - round trip com writeTls13Records recompoe o payload original',
      () {
        final suite = cipherSuitesTls13[0];
        final secret = _hex('55' * 32);
        final out = HalfConn()
          ..version = versionTls13
          ..setTrafficSecret(suite, secret);
        final inConn = HalfConn()
          ..version = versionTls13
          ..setTrafficSecret(suite, secret);
        final data = Uint8List(maxPlaintext + 20);
        for (var i = 0; i < data.length; i++) {
          data[i] = i & 0xff;
        }
        final records = writeTls13Records(out, recordTypeApplicationData, data);
        final recovered = BytesBuilder(copy: false);
        for (final record in records) {
          final decoded = readTls13Record(
            inConn,
            record,
            expectedVersion: versionTls13,
          );
          expect(decoded.recordType, equals(recordTypeApplicationData));
          recovered.add(decoded.data);
        }
        expect(_toHex(recovered.toBytes()), equals(_toHex(data)));
      },
    );

    test(
      'readTls13Record() - lanca RecordHeaderException para heuristica SSLv2 no primeiro registro',
      () {
        final half = HalfConn();
        final record = Uint8List.fromList([0x80, 0x00, 0x02, 0x00, 0x00]);
        expect(
          () => readTls13Record(half, record, expectedVersion: null),
          throwsA(isA<RecordHeaderException>()),
        );
      },
    );

    test(
      'readTls13Record() - lanca RecordHeaderException quando a versao nao bate com a esperada',
      () {
        final half = HalfConn();
        final record = Uint8List.fromList([
          recordTypeHandshake,
          0x11,
          0x11,
          0x00,
          0x01,
          0x00,
        ]);
        expect(
          () => readTls13Record(half, record, expectedVersion: versionTls13),
          throwsA(
            isA<RecordHeaderException>().having(
              (e) => e.message,
              'message',
              contains(
                'received record with version 1111 when expecting version 303',
              ),
            ),
          ),
        );
      },
    );

    test(
      'readTls13Record() - lanca AlertException(alertRecordOverflow) quando n excede maxCiphertextTls13',
      () {
        final half = HalfConn()..version = versionTls13;
        final header = Uint8List(5)
          ..[0] = recordTypeApplicationData
          ..[1] = 0x03
          ..[2] = 0x03
          ..[3] = ((maxCiphertextTls13 + 1) >> 8) & 0xff
          ..[4] = (maxCiphertextTls13 + 1) & 0xff;
        final record = Uint8List.fromList([
          ...header,
          ...Uint8List(maxCiphertextTls13 + 1),
        ]);
        expect(
          () => readTls13Record(half, record, expectedVersion: versionTls13),
          throwsA(
            isA<AlertException>().having(
              (e) => e.code,
              'code',
              equals(alertRecordOverflow),
            ),
          ),
        );
      },
    );
  });

  group('RecordHeaderException [Atomic Audit]', () {
    test(
      'RecordHeaderException() - preenche recordHeader com zeros quando a entrada e mais curta que 5 bytes',
      () {
        final ex = RecordHeaderException('short', Uint8List.fromList([1, 2]));
        expect(ex.recordHeader, equals(Uint8List.fromList([1, 2, 0, 0, 0])));
      },
    );

    test('toString() - inclui o prefixo tls: e a mensagem', () {
      final ex = RecordHeaderException('bad header', Uint8List(5));
      expect(ex.toString(), equals('tls: bad header'));
    });
  });
}
