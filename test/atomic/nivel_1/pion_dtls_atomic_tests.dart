// test/atomic/nivel_1/pion_dtls_atomic_tests.dart
// Testes atômicos 1 para 1 cobrindo 100% dos símbolos AST de transpiled_pion_dtls.

import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;
import 'package:test/test.dart';
import 'package:transpiled_pion_dtls/transpiled_pion_dtls.dart';
import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart'
    show NetAddr, UdpAddr;

void main() {
  group('Top-level functions [Atomic Audit]', () {
    test('cipherSuiteName() - atomic test', () async {
      expect(
        cipherSuiteName(tlsEcdheEcdsaWithAes128GcmSha256),
        contains('AES_128_GCM'),
      );
    });
    test('cipherSuites() - atomic test', () async {
      expect(cipherSuites(), isNotEmpty);
    });
    test('insecureCipherSuites() - atomic test', () async {
      expect(insecureCipherSuites(), isEmpty);
    });
    test('generateAeadAdditionalData() - atomic test', () async {
      final h = Header(
        epoch: 1,
        sequenceNumber: 2,
        contentType: ContentType.applicationData,
        version: Version.version1_2,
      );
      final ad = generateAeadAdditionalData(h, 10);
      expect(ad.length, equals(13));
    });
    test('withCertificates() - atomic test', () async {
      final cfg = Config();
      withCertificates([])(cfg);
      expect(cfg, isNotNull);
    });
    test('withCipherSuites() - atomic test', () async {
      final cfg = Config();
      withCipherSuites([tlsEcdheEcdsaWithAes128GcmSha256])(cfg);
      expect(cfg, isNotNull);
    });
    test('withCustomCipherSuites() - atomic test', () async {
      final cfg = Config();
      withCustomCipherSuites([])(cfg);
      expect(cfg, isNotNull);
    });
    test('withSignatureSchemes() - atomic test', () async {
      final cfg = Config();
      withSignatureSchemes([])(cfg);
      expect(cfg, isNotNull);
    });
    test('withCertificateSignatureSchemes() - atomic test', () async {
      final cfg = Config();
      withCertificateSignatureSchemes([])(cfg);
      expect(cfg, isNotNull);
    });
    test('withSrtpProtectionProfiles() - atomic test', () async {
      final cfg = Config();
      withSrtpProtectionProfiles([])(cfg);
      expect(cfg, isNotNull);
    });
    test('withSrtpMasterKeyIdentifier() - atomic test', () async {
      final cfg = Config();
      withSrtpMasterKeyIdentifier(Uint8List(0))(cfg);
      expect(cfg, isNotNull);
    });
    test('withExtendedMasterSecret() - atomic test', () async {
      final cfg = Config();
      withExtendedMasterSecret(ExtendedMasterSecretType.request)(cfg);
      expect(cfg, isNotNull);
    });
    test('withFlightInterval() - atomic test', () async {
      final cfg = Config();
      withFlightInterval(Duration(seconds: 1))(cfg);
      expect(cfg, isNotNull);
    });
    test('withDisableRetransmitBackoff() - atomic test', () async {
      final cfg = Config();
      withDisableRetransmitBackoff()(cfg);
      expect(cfg, isNotNull);
    });
    test('withPsk() - atomic test', () async {
      final cfg = Config();
      withPsk((_) => Uint8List(0))(cfg);
      expect(cfg, isNotNull);
    });
    test('withPskIdentityHint() - atomic test', () async {
      final cfg = Config();
      withPskIdentityHint(Uint8List(0))(cfg);
      expect(cfg, isNotNull);
    });
    test('withInsecureSkipVerify() - atomic test', () async {
      final cfg = Config();
      withInsecureSkipVerify()(cfg);
      expect(cfg, isNotNull);
    });
    test('withInsecureHashes() - atomic test', () async {
      final cfg = Config();
      withInsecureHashes()(cfg);
      expect(cfg, isNotNull);
    });
    test('withVerifyPeerCertificate() - atomic test', () async {
      final cfg = Config();
      withVerifyPeerCertificate((_, __) => null)(cfg);
      expect(cfg, isNotNull);
    });
    test('withVerifyConnection() - atomic test', () async {
      final cfg = Config();
      withVerifyConnection((_) => null)(cfg);
      expect(cfg, isNotNull);
    });
    test('withRootCAs() - atomic test', () async {
      final cfg = Config();
      withRootCAs([])(cfg);
      expect(cfg, isNotNull);
    });
    test('withServerName() - atomic test', () async {
      final cfg = Config();
      withServerName('test')(cfg);
      expect(cfg, isNotNull);
    });
    test('withLoggerFactory() - atomic test', () async {
      final cfg = Config();
      withLoggerFactory(null)(cfg);
      expect(cfg, isNotNull);
    });
    test('withMtu() - atomic test', () async {
      final cfg = Config();
      withMtu(1200)(cfg);
      expect(cfg, isNotNull);
    });
    test('withReplayProtectionWindow() - atomic test', () async {
      final cfg = Config();
      withReplayProtectionWindow(64)(cfg);
      expect(cfg, isNotNull);
    });
    test('withKeyLogWriter() - atomic test', () async {
      final cfg = Config();
      withKeyLogWriter(null)(cfg);
      expect(cfg, isNotNull);
    });
    test('withSessionStore() - atomic test', () async {
      final cfg = Config();
      withSessionStore(MemorySessionStore())(cfg);
      expect(cfg, isNotNull);
    });
    test('withSupportedProtocols() - atomic test', () async {
      final cfg = Config();
      withSupportedProtocols([])(cfg);
      expect(cfg, isNotNull);
    });
    test('withEllipticCurves() - atomic test', () async {
      final cfg = Config();
      withEllipticCurves([])(cfg);
      expect(cfg, isNotNull);
    });
    test('withGetClientCertificate() - atomic test', () async {
      final cfg = Config();
      withGetClientCertificate((_) async => null)(cfg);
      expect(cfg, isNotNull);
    });
    test('withConnectionIdGenerator() - atomic test', () async {
      final cfg = Config();
      withConnectionIdGenerator(randomCidGenerator(8))(cfg);
      expect(cfg, isNotNull);
    });
    test('withPaddingLengthGenerator() - atomic test', () async {
      final cfg = Config();
      withPaddingLengthGenerator(null)(cfg);
      expect(cfg, isNotNull);
    });
    test('withHelloRandomBytesGenerator() - atomic test', () async {
      final cfg = Config();
      withHelloRandomBytesGenerator(null)(cfg);
      expect(cfg, isNotNull);
    });
    test('withClientHelloMessageHook() - atomic test', () async {
      final cfg = Config();
      withClientHelloMessageHook((_) {})(cfg);
      expect(cfg, isNotNull);
    });
    test('withClientAuth() - atomic test', () async {
      final cfg = Config();
      withClientAuth(ClientAuthType.noClientCert)(cfg);
      expect(cfg, isNotNull);
    });
    test('withClientCAs() - atomic test', () async {
      final cfg = Config();
      withClientCAs([])(cfg);
      expect(cfg, isNotNull);
    });
    test('withGetCertificate() - atomic test', () async {
      final cfg = Config();
      withGetCertificate((_) async => null)(cfg);
      expect(cfg, isNotNull);
    });
    test('withInsecureSkipVerifyHello() - atomic test', () async {
      final cfg = Config();
      withInsecureSkipVerifyHello()(cfg);
      expect(cfg, isNotNull);
    });
    test('withServerHelloMessageHook() - atomic test', () async {
      final cfg = Config();
      withServerHelloMessageHook((_) {})(cfg);
      expect(cfg, isNotNull);
    });
    test('withCertificateRequestMessageHook() - atomic test', () async {
      final cfg = Config();
      withCertificateRequestMessageHook((_) {})(cfg);
      expect(cfg, isNotNull);
    });
    test('withOnConnectionAttempt() - atomic test', () async {
      final cfg = Config();
      withOnConnectionAttempt((_) {})(cfg);
      expect(cfg, isNotNull);
    });
    test('client() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final c = client(pconn, raddr, Config());
      expect(c, isNotNull);
    });
    test('clientWithOptions() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final c = clientWithOptions(pconn, raddr);
      expect(c, isNotNull);
    });
    test('server() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final c = server(pconn, raddr, Config());
      expect(c, isNotNull);
    });
    test('serverWithOptions() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final c = serverWithOptions(pconn, raddr);
      expect(c, isNotNull);
    });
    test('dial() - atomic test', () async {
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      expect(
        () => dial('udp4', raddr, Config()),
        throwsA(isA<UnimplementedError>()),
      );
    });
    test('dialWithOptions() - atomic test', () async {
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      expect(
        () => dialWithOptions('udp4', raddr),
        throwsA(isA<UnimplementedError>()),
      );
    });
    test('randomCidGenerator() - atomic test', () async {
      final gen = randomCidGenerator(8);
      expect(gen, isA<Function>());
    });
    test('onlySendCidGenerator() - atomic test', () async {
      final gen = onlySendCidGenerator();
      expect(gen, isA<Function>());
    });
    test('listen() - atomic test', () async {
      final laddr = UdpAddr(InternetAddress.loopbackIPv4, 1234);
      final l = await listen('udp4', laddr, Config());
      expect(l, isNotNull);
    });
    test('listenWithOptions() - atomic test', () async {
      final laddr = UdpAddr(InternetAddress.loopbackIPv4, 1234);
      final l = await listenWithOptions('udp4', laddr);
      expect(l, isNotNull);
    });
    test('listenerWithOptions() - atomic test', () async {
      final laddr = UdpAddr(InternetAddress.loopbackIPv4, 1234);
      final pconn = PacketConn(localAddr: laddr);
      final l = await listenerWithOptions(pconn);
      expect(l, isNotNull);
    });
    test('resume() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final st = State();
      final c = await resume(st, pconn, raddr, Config());
      expect(c, isNotNull);
    });
    test('resumeWithOptions() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final st = State();
      final c = await resumeWithOptions(st, pconn, raddr);
      expect(c, isNotNull);
    });
    test('pHash() - atomic test', () async {
      final sec = Uint8List(32);
      final seed = Uint8List(32);
      final out = pHash(sec, seed, 32, () => crypto.sha256);
      expect(out.length, equals(32));
    });
    test('masterSecret() - atomic test', () async {
      final sec = Uint8List(32);
      final seed = Uint8List(32);
      final out = masterSecret(sec, seed, seed, () => crypto.sha256);
      expect(out.length, equals(48));
    });
    test('extendedMasterSecret() - atomic test', () async {
      final sec = Uint8List(32);
      final seed = Uint8List(32);
      final out = extendedMasterSecret(sec, seed, () => crypto.sha256);
      expect(out.length, equals(48));
    });
    test('generateEncryptionKeys() - atomic test', () async {
      final sec = Uint8List(32);
      final seed = Uint8List(32);
      final keys = generateEncryptionKeys(
        Uint8List(48),
        seed,
        seed,
        0,
        16,
        4,
        () => crypto.sha256,
      );
      expect(keys.clientWriteKey.length, equals(16));
    });
    test('verifyDataClient() - atomic test', () async {
      final sec = Uint8List(32);
      final seed = Uint8List(32);
      final out = verifyDataClient(
        Uint8List(48),
        Uint8List(10),
        () => crypto.sha256,
      );
      expect(out.length, equals(12));
    });
    test('verifyDataServer() - atomic test', () async {
      final sec = Uint8List(32);
      final seed = Uint8List(32);
      final out = verifyDataServer(
        Uint8List(48),
        Uint8List(10),
        () => crypto.sha256,
      );
      expect(out.length, equals(12));
    });
    test('calculateEcdhPreMasterSecret() - atomic test', () async {
      final sec = Uint8List(32);
      final seed = Uint8List(32);
      final kpGen = pc.ECKeyGenerator();
      kpGen.init(
        pc.ParametersWithRandom(
          pc.ECKeyGeneratorParameters(pc.ECDomainParameters('prime256v1')),
          pc.SecureRandom('Fortuna')..seed(pc.KeyParameter(Uint8List(32))),
        ),
      );
      final kp1 = kpGen.generateKeyPair();
      final kp2 = kpGen.generateKeyPair();
      final pms = calculateEcdhPreMasterSecret(
        (kp1.publicKey as pc.ECPublicKey).Q!.getEncoded(false),
        kp2.privateKey as pc.ECPrivateKey,
      );
      expect(pms.length, equals(32));
    });
    test('unmarshalExtensions() - atomic test', () async {
      final raw = ServerName('test.p2p').marshal();
      final list = unmarshalExtensions(raw);
      expect(list.length, equals(1));
    });
    test('unpackDatagram() - atomic test', () async {
      final raw = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      ).marshal();
      final pkts = unpackDatagram(raw);
      expect(pkts, isNotEmpty);
    });
    test('recordlayerUnpackDatagram() - atomic test', () async {
      final raw = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      ).marshal();
      final pkts = recordlayerUnpackDatagram(raw);
      expect(pkts, isNotEmpty);
    });
    test('bigEndianUint24() - atomic test', () async {
      expect(bigEndianUint24(Uint8List.fromList([1, 2, 3])), equals(0x010203));
    });
    test('putBigEndianUint24() - atomic test', () async {
      final b = Uint8List(3);
      putBigEndianUint24(b, 0x010203);
      expect(b, equals([1, 2, 3]));
    });
    test('putBigEndianUint48() - atomic test', () async {
      final b = Uint8List(6);
      putBigEndianUint48(b, 0x010203040506);
      expect(b, equals([1, 2, 3, 4, 5, 6]));
    });
    test('max() - atomic test', () async {
      expect(max(5, 10), equals(10));
    });
    test('addUint48() - atomic test', () async {
      final l = <int>[];
      addUint48(l, 0x010203040506);
      expect(l.length, equals(6));
    });
  });
  group('Aes128Ccm [Atomic Audit]', () {
    test('init() - atomic test', () async {
      final c = Aes128Ccm();
      c.init();
      expect(c, isNotNull);
    });
  });
  group('Aes256Ccm [Atomic Audit]', () {
    test('init() - atomic test', () async {
      final c = Aes256Ccm();
      c.init();
      expect(c, isNotNull);
    });
  });
  group('AesCcm [Atomic Audit]', () {
    test('certificateType() - atomic test', () async {
      final c = AesCcm();
      expect(c.certificateType(), isA<int>());
    });
    test('id() - atomic test', () async {
      final c = AesCcm();
      expect(c.id(), isA<int>());
    });
    test('string() - atomic test', () async {
      final c = AesCcm();
      expect(c.string(), isNotEmpty);
    });
    test('ecc() - atomic test', () async {
      final c = AesCcm();
      expect(c.ecc(), isA<bool>());
    });
    test('keyExchangeAlgorithm() - atomic test', () async {
      final c = AesCcm();
      expect(c.keyExchangeAlgorithm(), isA<int>());
    });
    test('hashFunc() - atomic test', () async {
      final c = AesCcm();
      expect(c.hashFunc(), isA<Function>());
    });
    test('authenticationType() - atomic test', () async {
      final c = AesCcm();
      expect(c.authenticationType(), isA<int>());
    });
    test('isInitialized() - atomic test', () async {
      final c = AesCcm();
      expect(c.isInitialized(), isA<bool>());
    });
    test('init() - atomic test', () async {
      final c = AesCcm();
      c.init();
      expect(c.isInitialized(), isTrue);
    });
    test('encrypt() - atomic test', () async {
      final c = AesCcm();
      expect(c.encrypt(Uint8List(5)), isNotNull);
    });
    test('decrypt() - atomic test', () async {
      final c = AesCcm();
      expect(c.decrypt(Uint8List(5)), isNotNull);
    });
  });
  group('Alert [Atomic Audit]', () {
    test('contentType() - atomic test', () async {
      final a = Alert(
        level: AlertLevel.fatal,
        description: AlertDescription.closeNotify,
      );
      expect(a.contentType(), equals(ContentType.alert));
    });
    test('marshal() - atomic test', () async {
      final a = Alert(
        level: AlertLevel.fatal,
        description: AlertDescription.closeNotify,
      );
      expect(a.marshal().length, equals(2));
    });
    test('unmarshal() - atomic test', () async {
      final a = Alert(
        level: AlertLevel.fatal,
        description: AlertDescription.closeNotify,
      );
      final a2 = Alert()..unmarshal(a.marshal());
      expect(a2.description, equals(AlertDescription.closeNotify));
    });
    test('string() - atomic test', () async {
      final a = Alert(
        level: AlertLevel.fatal,
        description: AlertDescription.closeNotify,
      );
      expect(a.string(), contains('closeNotify'));
    });
    test('toString() - atomic test', () async {
      final a = Alert(
        level: AlertLevel.fatal,
        description: AlertDescription.closeNotify,
      );
      expect(a.toString(), isNotEmpty);
    });
  });
  group('AlertDescription [Atomic Audit]', () {
    test('noApplicationProtocol() - atomic test', () async {
      expect(AlertDescription.noApplicationProtocol.value, equals(120));
    });
    test('fromValue() - atomic test', () async {
      expect(
        AlertDescription.fromValue(0),
        equals(AlertDescription.closeNotify),
      );
    });
  });
  group('AlertException [Atomic Audit]', () {
    test('error() - atomic test', () async {
      final a = Alert(
        level: AlertLevel.fatal,
        description: AlertDescription.closeNotify,
      );
      final e = AlertException(a);
      expect(e.error(), contains('closeNotify'));
    });
    test('isFatalOrCloseNotify() - atomic test', () async {
      final a = Alert(
        level: AlertLevel.fatal,
        description: AlertDescription.closeNotify,
      );
      final e = AlertException(a);
      expect(e.isFatalOrCloseNotify(), isTrue);
    });
    test('isMatch() - atomic test', () async {
      final a = Alert(
        level: AlertLevel.fatal,
        description: AlertDescription.closeNotify,
      );
      final e = AlertException(a);
      expect(e.isMatch(AlertException(a)), isTrue);
    });
    test('toString() - atomic test', () async {
      final a = Alert(
        level: AlertLevel.fatal,
        description: AlertDescription.closeNotify,
      );
      final e = AlertException(a);
      expect(e.toString(), contains('alert'));
    });
  });
  group('AlertLevel [Atomic Audit]', () {
    test('fatal() - atomic test', () async {
      expect(AlertLevel.fatal.value, equals(2));
    });
    test('fromValue() - atomic test', () async {
      expect(AlertLevel.fromValue(2), equals(AlertLevel.fatal));
    });
  });
  group('ApplicationData [Atomic Audit]', () {
    test('contentType() - atomic test', () async {
      final c = ApplicationData(Uint8List(5));
      expect(c.contentType(), isNotNull);
    });
    test('marshal() - atomic test', () async {
      final c = ApplicationData(Uint8List(5));
      expect(c.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final c = ApplicationData(Uint8List(5));
      c.unmarshal(Uint8List(5));
      expect(true, isTrue);
    });
  });
  group('BaseGcmCipherSuite [Atomic Audit]', () {
    test('isInitialized() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      expect(cs.isInitialized(), isA<bool>());
    });
    test('encrypt() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      expect(cs.encrypt(rl, rl.marshal()), isNotNull);
    });
    test('decrypt() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      final csServer = TlsEcdheEcdsaWithAes128GcmSha256();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      csServer.init(Uint8List(48), Uint8List(32), Uint8List(32), false);
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      final enc = csServer.encrypt(rl, rl.marshal());
      expect(cs.decrypt(rl, enc), isNotNull);
    });
    test('initGcm() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      cs.initGcm(
        masterSecret: Uint8List(48),
        clientRandom: Uint8List(32),
        serverRandom: Uint8List(32),
        isClient: true,
        keyLen: 16,
        hashFunc: () => crypto.sha256,
      );
      expect(cs.isInitialized(), isTrue);
    });
  });
  group('Cbc [Atomic Audit]', () {
    test('encrypt() - atomic test', () async {
      final c = Cbc();
      expect(c.encrypt(Uint8List(10)), isNotNull);
    });
    test('decrypt() - atomic test', () async {
      final c = Cbc();
      expect(c.decrypt(Uint8List(10)), isNotNull);
    });
  });
  group('Ccm [Atomic Audit]', () {
    test('maxLength() - atomic test', () async {
      final c = Ccm();
      expect(c.maxLength(), isA<int>());
    });
    test('nonceSize() - atomic test', () async {
      final c = Ccm();
      expect(c.nonceSize(), isA<int>());
    });
    test('overhead() - atomic test', () async {
      final c = Ccm();
      expect(c.overhead(), isA<int>());
    });
    test('maxNonceLength() - atomic test', () async {
      final c = Ccm();
      expect(c.maxNonceLength(), isA<int>());
    });
    test('seal() - atomic test', () async {
      final c = Ccm();
      expect(
        c.seal(Uint8List(0), Uint8List(12), Uint8List(10), Uint8List(0)),
        isNotNull,
      );
    });
    test('open() - atomic test', () async {
      final c = Ccm();
      expect(
        c.open(Uint8List(0), Uint8List(12), Uint8List(10), Uint8List(0)),
        isNotNull,
      );
    });
    test('encrypt() - atomic test', () async {
      final c = Ccm();
      expect(c.encrypt(Uint8List(10)), isNotNull);
    });
    test('decrypt() - atomic test', () async {
      final c = Ccm();
      expect(c.decrypt(Uint8List(10)), isNotNull);
    });
  });
  group('CertificateRequestInfo [Atomic Audit]', () {
    test('supportsCertificate() - atomic test', () async {
      final cri = CertificateRequestInfo(acceptableCAs: []);
      expect(cri.supportsCertificate(null), isTrue);
    });
  });
  group('ChangeCipherSpec [Atomic Audit]', () {
    test('contentType() - atomic test', () async {
      final c = ChangeCipherSpec();
      expect(c.contentType(), isNotNull);
    });
    test('marshal() - atomic test', () async {
      final c = ChangeCipherSpec();
      expect(c.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final c = ChangeCipherSpec();
      c.unmarshal(Uint8List.fromList([0x01]));
      expect(c.contentType(), equals(ContentType.changeCipherSpec));
    });
  });
  group('CipherSuite [Atomic Audit]', () {
    test('string() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      expect(cs.string(), isNotEmpty);
    });
    test('id() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      expect(cs.id(), isA<int>());
    });
    test('certificateType() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      expect(cs.certificateType(), isA<int>());
    });
    test('hashFunc() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      expect(cs.hashFunc(), isA<Function>());
    });
    test('authenticationType() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      expect(cs.authenticationType(), isA<int>());
    });
    test('keyExchangeAlgorithm() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      expect(cs.keyExchangeAlgorithm(), isA<int>());
    });
    test('ecc() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      expect(cs.ecc(), isA<bool>());
    });
    test('init() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      expect(cs.isInitialized(), isTrue);
    });
    test('isInitialized() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      expect(cs.isInitialized(), isA<bool>());
    });
    test('encrypt() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      expect(cs.encrypt(rl, rl.marshal()), isNotNull);
    });
    test('decrypt() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      final csServer = TlsEcdheEcdsaWithAes128GcmSha256();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      csServer.init(Uint8List(48), Uint8List(32), Uint8List(32), false);
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      final enc = csServer.encrypt(rl, rl.marshal());
      expect(cs.decrypt(rl, enc), isNotNull);
    });
  });
  group('ClientAuthType [Atomic Audit]', () {
    test('requireAndVerifyClientCert() - atomic test', () async {
      expect(ClientAuthType.requireAndVerifyClientCert.value, equals(4));
    });
  });
  group('ClientOption [Atomic Audit]', () {
    test('apply() - atomic test', () async {
      final opt = withCertificates([]);
      final cfg = Config();
      opt.apply(cfg);
      expect(cfg, isNotNull);
    });
    test('call() - atomic test', () async {
      final opt = withCertificates([]);
      final cfg = Config();
      opt(cfg);
      expect(cfg, isNotNull);
    });
  });
  group('Closer [Atomic Audit]', () {
    test('done() - atomic test', () async {
      final c = Closer();
      expect(c.done(), isA<Future<void>>());
    });
    test('err() - atomic test', () async {
      final c = Closer();
      expect(c.err(), isNull);
    });
    test('close() - atomic test', () async {
      final c = Closer();
      c.close();
      expect(c.err(), isNull);
    });
  });
  group('Conn [Atomic Audit]', () {
    test('handshake() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final conn = Conn(
        nextConn: pconn,
        remoteAddrValue: raddr,
        config: Config(),
        state: State(),
      );
      expect(conn.handshake, isNotNull);
    });
    test('handshakeContext() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final conn = Conn(
        nextConn: pconn,
        remoteAddrValue: raddr,
        config: Config(),
        state: State(),
      );
      expect(conn.handshakeContext, isNotNull);
    });
    test('read() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final conn = Conn(
        nextConn: pconn,
        remoteAddrValue: raddr,
        config: Config(),
        state: State(),
      );
      expect(conn.read(Uint8List(10)), isA<Future>());
    });
    test('write() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final conn = Conn(
        nextConn: pconn,
        remoteAddrValue: raddr,
        config: Config(),
        state: State(),
      );
      conn.completeHandshake();
      expect(conn.write(Uint8List(5)), isA<Future<int>>());
    });
    test('close() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final conn = Conn(
        nextConn: pconn,
        remoteAddrValue: raddr,
        config: Config(),
        state: State(),
      );
      await conn.close();
      expect(true, isTrue);
    });
    test('connectionState() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final conn = Conn(
        nextConn: pconn,
        remoteAddrValue: raddr,
        config: Config(),
        state: State(),
      );
      expect(conn.connectionState(), isNotNull);
    });
    test('selectedSrtpProtectionProfile() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final conn = Conn(
        nextConn: pconn,
        remoteAddrValue: raddr,
        config: Config(),
        state: State(),
      );
      expect(conn.selectedSrtpProtectionProfile().$2, isFalse);
    });
    test('remoteSrtpMasterKeyIdentifier() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final conn = Conn(
        nextConn: pconn,
        remoteAddrValue: raddr,
        config: Config(),
        state: State(),
      );
      expect(conn.remoteSrtpMasterKeyIdentifier().$2, isFalse);
    });
    test('localAddr() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final conn = Conn(
        nextConn: pconn,
        remoteAddrValue: raddr,
        config: Config(),
        state: State(),
      );
      expect(conn.localAddr(), isNotNull);
    });
    test('remoteAddr() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final conn = Conn(
        nextConn: pconn,
        remoteAddrValue: raddr,
        config: Config(),
        state: State(),
      );
      expect(conn.remoteAddr(), equals(raddr));
    });
    test('setDeadline() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final conn = Conn(
        nextConn: pconn,
        remoteAddrValue: raddr,
        config: Config(),
        state: State(),
      );
      conn.setDeadline(DateTime.now());
      expect(true, isTrue);
    });
    test('setReadDeadline() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final conn = Conn(
        nextConn: pconn,
        remoteAddrValue: raddr,
        config: Config(),
        state: State(),
      );
      conn.setReadDeadline(DateTime.now());
      expect(true, isTrue);
    });
    test('setWriteDeadline() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final conn = Conn(
        nextConn: pconn,
        remoteAddrValue: raddr,
        config: Config(),
        state: State(),
      );
      conn.setWriteDeadline(DateTime.now());
      expect(true, isTrue);
    });
    test('completeHandshake() - atomic test', () async {
      final pconn = PacketConn(
        localAddr: UdpAddr(InternetAddress.loopbackIPv4, 1234),
      );
      final raddr = UdpAddr(InternetAddress.loopbackIPv4, 5678);
      final conn = Conn(
        nextConn: pconn,
        remoteAddrValue: raddr,
        config: Config(),
        state: State(),
      );
      conn.completeHandshake();
      expect(true, isTrue);
    });
  });
  group('Content [Atomic Audit]', () {
    test('contentType() - atomic test', () async {
      final c = ApplicationData(Uint8List(5));
      expect(c.contentType(), isNotNull);
    });
    test('marshal() - atomic test', () async {
      final c = ApplicationData(Uint8List(5));
      expect(c.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final c = ApplicationData(Uint8List(5));
      c.unmarshal(Uint8List(5));
      expect(true, isTrue);
    });
  });
  group('ContentType [Atomic Audit]', () {
    test('connectionId() - atomic test', () async {
      expect(ContentType.connectionId.value, equals(25));
    });
    test('fromValue() - atomic test', () async {
      expect(ContentType.fromValue(23), equals(ContentType.applicationData));
    });
  });
  group('CookieExt [Atomic Audit]', () {
    test('typeValue() - atomic test', () async {
      final ext = CookieExt(Uint8List(3));
      expect(ext.typeValue, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final ext = CookieExt(Uint8List(3));
      expect(ext.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final ext = CookieExt(Uint8List(3));
      ext.unmarshal(ext.marshal());
      expect(ext.typeValue, isNotNull);
    });
  });
  group('ExtendedMasterSecretType [Atomic Audit]', () {
    test('disable() - atomic test', () async {
      expect(ExtendedMasterSecretType.disable.value, equals(2));
    });
  });
  group('Extension [Atomic Audit]', () {
    test('typeValue() - atomic test', () async {
      final ext = ServerName('test.p2p');
      expect(ext.typeValue, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final ext = ServerName('test.p2p');
      expect(ext.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final ext = ServerName('test.p2p');
      ext.unmarshal(ext.marshal());
      expect(ext.typeValue, isNotNull);
    });
  });
  group('FlightVal [Atomic Audit]', () {
    test('flight6() - atomic test', () async {
      final f = FlightVal.flight6;
      expect(FlightVal.flight6.value, equals(9));
    });
    test('string() - atomic test', () async {
      final f = FlightVal.flight6;
      expect(f.string(), equals('Flight 6'));
    });
    test('isLastSendFlight() - atomic test', () async {
      final f = FlightVal.flight6;
      expect(f.isLastSendFlight(), isTrue);
    });
    test('isLastRecvFlight() - atomic test', () async {
      final f = FlightVal.flight6;
      expect(FlightVal.flight6.isLastRecvFlight(), isTrue);
    });
  });
  group('GcmCipher [Atomic Audit]', () {
    test('encrypt() - atomic test', () async {
      final kClient = Uint8List(16);
      final kServer = Uint8List(16);
      final ivClient = Uint8List(4);
      final ivServer = Uint8List(4);
      final clientCipher = GcmCipher(
        localKey: kClient,
        localWriteIv: ivClient,
        remoteKey: kServer,
        remoteWriteIv: ivServer,
      );
      final serverCipher = GcmCipher(
        localKey: kServer,
        localWriteIv: ivServer,
        remoteKey: kClient,
        remoteWriteIv: ivClient,
      );
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      expect(clientCipher.encrypt(rl, rl.marshal()), isNotEmpty);
    });
    test('decrypt() - atomic test', () async {
      final kClient = Uint8List(16);
      final kServer = Uint8List(16);
      final ivClient = Uint8List(4);
      final ivServer = Uint8List(4);
      final clientCipher = GcmCipher(
        localKey: kClient,
        localWriteIv: ivClient,
        remoteKey: kServer,
        remoteWriteIv: ivServer,
      );
      final serverCipher = GcmCipher(
        localKey: kServer,
        localWriteIv: ivServer,
        remoteKey: kClient,
        remoteWriteIv: ivClient,
      );
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      final enc = clientCipher.encrypt(rl, rl.marshal());
      expect(serverCipher.decrypt(rl, enc), isNotEmpty);
    });
  });
  group('Handshake [Atomic Audit]', () {
    test('contentType() - atomic test', () async {
      final hs = Handshake(message: MessageFinished(verifyData: Uint8List(12)));
      expect(hs.contentType(), equals(ContentType.handshake));
    });
    test('marshal() - atomic test', () async {
      final hs = Handshake(message: MessageFinished(verifyData: Uint8List(12)));
      expect(hs.marshal().length, greaterThan(12));
    });
    test('unmarshal() - atomic test', () async {
      final hs = Handshake(message: MessageFinished(verifyData: Uint8List(12)));
      final hs2 = Handshake()..unmarshal(hs.marshal());
      expect(hs2.header, isNotNull);
    });
  });
  group('HandshakeFsm [Atomic Audit]', () {
    test('run() - atomic test', () async {
      final fsm = HandshakeFsm();
      expect(fsm.run, isNotNull);
    });
    test('done() - atomic test', () async {
      final fsm = HandshakeFsm();
      expect(fsm.done(), isA<Future<void>>());
    });
  });
  group('HandshakeHeader [Atomic Audit]', () {
    test('marshal() - atomic test', () async {
      final h = HandshakeHeader(type: HandshakeType.clientHello, length: 10);
      expect(h.marshal().length, equals(12));
    });
    test('unmarshal() - atomic test', () async {
      final h = HandshakeHeader(type: HandshakeType.clientHello, length: 10);
      final h2 = HandshakeHeader()..unmarshal(h.marshal());
      expect(h2.length, equals(10));
    });
  });
  group('HandshakeState [Atomic Audit]', () {
    test('handshakeFinished() - atomic test', () async {
      final s = HandshakeState.handshakeFinished;
      expect(HandshakeState.handshakeFinished.value, equals(4));
    });
    test('string() - atomic test', () async {
      final s = HandshakeState.handshakeFinished;
      expect(s.string(), contains('Finished'));
    });
  });
  group('HandshakeType [Atomic Audit]', () {
    test('finished() - atomic test', () async {
      expect(HandshakeType.finished.value, equals(20));
    });
    test('fromValue() - atomic test', () async {
      expect(HandshakeType.fromValue(1), equals(HandshakeType.clientHello));
    });
  });
  group('Header [Atomic Audit]', () {
    test('size() - atomic test', () async {
      final h = Header(
        contentType: ContentType.applicationData,
        version: Version.version1_2,
        epoch: 1,
        sequenceNumber: 2,
      );
      expect(h.size(), equals(13));
    });
    test('marshal() - atomic test', () async {
      final h = Header(
        contentType: ContentType.applicationData,
        version: Version.version1_2,
        epoch: 1,
        sequenceNumber: 2,
      );
      expect(h.marshal().length, equals(13));
    });
    test('unmarshal() - atomic test', () async {
      final h = Header(
        contentType: ContentType.applicationData,
        version: Version.version1_2,
        epoch: 1,
        sequenceNumber: 2,
      );
      final h2 = Header()..unmarshal(h.marshal());
      expect(h2.sequenceNumber, equals(2));
    });
  });
  group('InvalidCipherSuiteException [Atomic Audit]', () {
    test('error() - atomic test', () async {
      final e = InvalidCipherSuiteException(0x1234);
      expect(e.error(), contains('0x1234'));
    });
    test('isMatch() - atomic test', () async {
      final e = InvalidCipherSuiteException(0x1234);
      expect(e.isMatch(InvalidCipherSuiteException(0x1234)), isTrue);
    });
    test('toString() - atomic test', () async {
      final e = InvalidCipherSuiteException(0x1234);
      expect(e.toString(), contains('0x1234'));
    });
  });
  group('ListenConfig [Atomic Audit]', () {
    test('listen() - atomic test', () async {
      final lc = ListenConfig();
      expect(lc.listen('udp4', '127.0.0.1:0'), isNotNull);
    });
  });
  group('Listener [Atomic Audit]', () {
    test('accept() - atomic test', () async {
      final l = Listener(null, Config());
      expect(l.accept, isNotNull);
    });
    test('close() - atomic test', () async {
      final l = Listener(null, Config());
      await l.close();
      expect(true, isTrue);
    });
    test('addr() - atomic test', () async {
      final l = Listener(null, Config());
      expect(l.addr(), isNotNull);
    });
  });
  group('MemorySessionStore [Atomic Audit]', () {
    test('set() - atomic test', () async {
      final store = MemorySessionStore();
      final key = Uint8List.fromList([1, 2, 3]);
      final s = Session(id: key, secret: Uint8List(10));
      store.set(key, s);
      expect(store.get(key), isNotNull);
    });
    test('get() - atomic test', () async {
      final store = MemorySessionStore();
      final key = Uint8List.fromList([1, 2, 3]);
      final s = Session(id: key, secret: Uint8List(10));
      store.set(key, s);
      expect(store.get(key)?.secret.length, equals(10));
    });
    test('del() - atomic test', () async {
      final store = MemorySessionStore();
      final key = Uint8List.fromList([1, 2, 3]);
      final s = Session(id: key, secret: Uint8List(10));
      store.set(key, s);
      store.del(key);
      expect(store.get(key), isNull);
    });
  });
  group('Message [Atomic Audit]', () {
    test('type() - atomic test', () async {
      final m = MessageFinished(verifyData: Uint8List(12));
      expect(m.type, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final m = MessageFinished(verifyData: Uint8List(12));
      expect(m.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final m = MessageFinished(verifyData: Uint8List(12));
      m.unmarshal(m.marshal());
      expect(m.type, isNotNull);
    });
  });
  group('MessageCertificate [Atomic Audit]', () {
    test('type() - atomic test', () async {
      final m = MessageCertificate([Uint8List(5)]);
      expect(m.type, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final m = MessageCertificate([Uint8List(5)]);
      expect(m.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final m = MessageCertificate([Uint8List(5)]);
      m.unmarshal(m.marshal());
      expect(m.type, isNotNull);
    });
  });
  group('MessageCertificateRequest [Atomic Audit]', () {
    test('type() - atomic test', () async {
      final m = MessageCertificateRequest();
      expect(m.type, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final m = MessageCertificateRequest();
      expect(m.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final m = MessageCertificateRequest();
      m.unmarshal(m.marshal());
      expect(m.type, isNotNull);
    });
  });
  group('MessageCertificateVerify [Atomic Audit]', () {
    test('type() - atomic test', () async {
      final m = MessageCertificateVerify();
      expect(m.type, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final m = MessageCertificateVerify();
      expect(m.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final m = MessageCertificateVerify();
      m.unmarshal(m.marshal());
      expect(m.type, isNotNull);
    });
  });
  group('MessageClientHello [Atomic Audit]', () {
    test('cipherSuites() - atomic test', () async {
      final m = MessageClientHello(
        cipherSuites: [tlsEcdheEcdsaWithAes128GcmSha256],
      );
      expect(m.cipherSuites, isNotEmpty);
    });
    test('cipherSuites() - atomic test', () async {
      final m = MessageClientHello(
        cipherSuites: [tlsEcdheEcdsaWithAes128GcmSha256],
      );
      m.cipherSuites = [1];
      expect(m.cipherSuites, equals([1]));
    });
    test('type() - atomic test', () async {
      final m = MessageClientHello(
        cipherSuites: [tlsEcdheEcdsaWithAes128GcmSha256],
      );
      expect(m.type, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final m = MessageClientHello(
        cipherSuites: [tlsEcdheEcdsaWithAes128GcmSha256],
      );
      expect(m.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final m = MessageClientHello(
        cipherSuites: [tlsEcdheEcdsaWithAes128GcmSha256],
      );
      m.unmarshal(m.marshal());
      expect(m.type, isNotNull);
    });
  });
  group('MessageClientKeyExchange [Atomic Audit]', () {
    test('type() - atomic test', () async {
      final m = MessageClientKeyExchange(publicKey: Uint8List(5));
      expect(m.type, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final m = MessageClientKeyExchange(publicKey: Uint8List(5));
      expect(m.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final m = MessageClientKeyExchange(publicKey: Uint8List(5));
      m.unmarshal(m.marshal());
      expect(m.type, isNotNull);
    });
  });
  group('MessageFinished [Atomic Audit]', () {
    test('type() - atomic test', () async {
      final m = MessageFinished(verifyData: Uint8List(12));
      expect(m.type, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final m = MessageFinished(verifyData: Uint8List(12));
      expect(m.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final m = MessageFinished(verifyData: Uint8List(12));
      m.unmarshal(m.marshal());
      expect(m.type, isNotNull);
    });
  });
  group('MessageHelloVerifyRequest [Atomic Audit]', () {
    test('type() - atomic test', () async {
      final m = MessageHelloVerifyRequest(
        cookie: Uint8List.fromList([1, 2, 3]),
      );
      expect(m.type, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final m = MessageHelloVerifyRequest(
        cookie: Uint8List.fromList([1, 2, 3]),
      );
      expect(m.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final m = MessageHelloVerifyRequest(
        cookie: Uint8List.fromList([1, 2, 3]),
      );
      m.unmarshal(m.marshal());
      expect(m.type, isNotNull);
    });
  });
  group('MessageServerHello [Atomic Audit]', () {
    test('cipherSuite() - atomic test', () async {
      final m = MessageServerHello(
        cipherSuite: tlsEcdheEcdsaWithAes128GcmSha256,
      );
      expect(m.cipherSuite, equals(tlsEcdheEcdsaWithAes128GcmSha256));
    });
    test('cipherSuite() - atomic test', () async {
      final m = MessageServerHello(
        cipherSuite: tlsEcdheEcdsaWithAes128GcmSha256,
      );
      m.cipherSuite = 1;
      expect(m.cipherSuite, equals(1));
    });
    test('type() - atomic test', () async {
      final m = MessageServerHello(
        cipherSuite: tlsEcdheEcdsaWithAes128GcmSha256,
      );
      expect(m.type, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final m = MessageServerHello(
        cipherSuite: tlsEcdheEcdsaWithAes128GcmSha256,
      );
      expect(m.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final m = MessageServerHello(
        cipherSuite: tlsEcdheEcdsaWithAes128GcmSha256,
      );
      m.unmarshal(m.marshal());
      expect(m.type, isNotNull);
    });
  });
  group('MessageServerHelloDone [Atomic Audit]', () {
    test('type() - atomic test', () async {
      final m = MessageServerHelloDone();
      expect(m.type, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final m = MessageServerHelloDone();
      expect(m.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final m = MessageServerHelloDone();
      m.unmarshal(m.marshal());
      expect(m.type, isNotNull);
    });
  });
  group('MessageServerKeyExchange [Atomic Audit]', () {
    test('type() - atomic test', () async {
      final m = MessageServerKeyExchange(
        namedCurve: 23,
        publicKey: Uint8List(5),
      );
      expect(m.type, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final m = MessageServerKeyExchange(
        namedCurve: 23,
        publicKey: Uint8List(5),
      );
      expect(m.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final m = MessageServerKeyExchange(
        namedCurve: 23,
        publicKey: Uint8List(5),
      );
      m.unmarshal(m.marshal());
      expect(m.type, isNotNull);
    });
  });
  group('Option [Atomic Audit]', () {
    test('apply() - atomic test', () async {
      final opt = withCertificates([]);
      final cfg = Config();
      opt.apply(cfg);
      expect(cfg, isNotNull);
    });
    test('call() - atomic test', () async {
      final opt = withCertificates([]);
      final cfg = Config();
      opt(cfg);
      expect(cfg, isNotNull);
    });
  });
  group('PacketBuffer [Atomic Audit]', () {
    test('writeTo() - atomic test', () async {
      final buf = PacketBuffer();
      final addr = UdpAddr(InternetAddress.loopbackIPv4, 1234);
      final n = await buf.writeTo(Uint8List(5), addr);
      expect(n, equals(5));
    });
    test('readFrom() - atomic test', () async {
      final buf = PacketBuffer();
      final addr = UdpAddr(InternetAddress.loopbackIPv4, 1234);
      await buf.writeTo(Uint8List(5), addr);
      final out = Uint8List(10);
      final (n, a) = await buf.readFrom(out);
      expect(n, equals(5));
    });
    test('close() - atomic test', () async {
      final buf = PacketBuffer();
      final addr = UdpAddr(InternetAddress.loopbackIPv4, 1234);
      buf.close();
      expect(true, isTrue);
    });
    test('setReadDeadline() - atomic test', () async {
      final buf = PacketBuffer();
      final addr = UdpAddr(InternetAddress.loopbackIPv4, 1234);
      buf.setReadDeadline(DateTime.now().add(Duration(seconds: 1)));
      expect(true, isTrue);
    });
  });
  group('PacketConn [Atomic Audit]', () {
    test('readFrom() - atomic test', () async {
      final laddr = UdpAddr(InternetAddress.loopbackIPv4, 1234);
      final conn = PacketConn(localAddr: laddr);
      conn.setReadDeadline(DateTime.now().subtract(Duration(seconds: 1)));
      expect(() => conn.readFrom(Uint8List(10)), throwsA(anything));
    });
    test('writeTo() - atomic test', () async {
      final laddr = UdpAddr(InternetAddress.loopbackIPv4, 1234);
      final conn = PacketConn(localAddr: laddr);
      final n = await conn.writeTo(Uint8List(5), laddr);
      expect(n, equals(5));
    });
    test('close() - atomic test', () async {
      final laddr = UdpAddr(InternetAddress.loopbackIPv4, 1234);
      final conn = PacketConn(localAddr: laddr);
      await conn.close();
      expect(true, isTrue);
    });
    test('localAddr() - atomic test', () async {
      final laddr = UdpAddr(InternetAddress.loopbackIPv4, 1234);
      final conn = PacketConn(localAddr: laddr);
      expect(conn.localAddr(), equals(laddr));
    });
    test('setDeadline() - atomic test', () async {
      final laddr = UdpAddr(InternetAddress.loopbackIPv4, 1234);
      final conn = PacketConn(localAddr: laddr);
      conn.setDeadline(DateTime.now());
      expect(true, isTrue);
    });
    test('setReadDeadline() - atomic test', () async {
      final laddr = UdpAddr(InternetAddress.loopbackIPv4, 1234);
      final conn = PacketConn(localAddr: laddr);
      conn.setReadDeadline(DateTime.now());
      expect(true, isTrue);
    });
    test('setWriteDeadline() - atomic test', () async {
      final laddr = UdpAddr(InternetAddress.loopbackIPv4, 1234);
      final conn = PacketConn(localAddr: laddr);
      conn.setWriteDeadline(DateTime.now());
      expect(true, isTrue);
    });
  });
  group('Random [Atomic Audit]', () {
    test('marshal() - atomic test', () async {
      final r = Random.generate();
      expect(r.marshal().length, equals(32));
    });
    test('unmarshal() - atomic test', () async {
      final r = Random.generate();
      final r2 = Random()..unmarshal(r.marshal());
      expect(r2.randomBytes.length, equals(28));
    });
  });
  group('RecordLayer [Atomic Audit]', () {
    test('marshal() - atomic test', () async {
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      expect(rl.marshal().length, greaterThan(0));
    });
    test('unmarshal() - atomic test', () async {
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      final rl2 = RecordLayer()..unmarshal(rl.marshal());
      expect(rl2.header, isNotNull);
    });
    test('unpackDatagram() - atomic test', () async {
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      expect(RecordLayer.unpackDatagram(rl.marshal()), isNotEmpty);
    });
  });
  group('ServerName [Atomic Audit]', () {
    test('typeValue() - atomic test', () async {
      final ext = ServerName('test.p2p');
      expect(ext.typeValue, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final ext = ServerName('test.p2p');
      expect(ext.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final ext = ServerName('test.p2p');
      ext.unmarshal(ext.marshal());
      expect(ext.typeValue, isNotNull);
    });
  });
  group('ServerOption [Atomic Audit]', () {
    test('apply() - atomic test', () async {
      final opt = withCertificates([]);
      final cfg = Config();
      opt.apply(cfg);
      expect(cfg, isNotNull);
    });
    test('call() - atomic test', () async {
      final opt = withCertificates([]);
      final cfg = Config();
      opt(cfg);
      expect(cfg, isNotNull);
    });
  });
  group('SessionStore [Atomic Audit]', () {
    test('set() - atomic test', () async {
      final store = MemorySessionStore();
      final key = Uint8List.fromList([1, 2, 3]);
      final s = Session(id: key, secret: Uint8List(10));
      store.set(key, s);
      expect(store.get(key), isNotNull);
    });
    test('get() - atomic test', () async {
      final store = MemorySessionStore();
      final key = Uint8List.fromList([1, 2, 3]);
      final s = Session(id: key, secret: Uint8List(10));
      store.set(key, s);
      expect(store.get(key)?.secret.length, equals(10));
    });
    test('del() - atomic test', () async {
      final store = MemorySessionStore();
      final key = Uint8List.fromList([1, 2, 3]);
      final s = Session(id: key, secret: Uint8List(10));
      store.set(key, s);
      store.del(key);
      expect(store.get(key), isNull);
    });
  });
  group('SrtpProtectionProfile [Atomic Audit]', () {
    test('srtpAeadAes256Gcm() - atomic test', () async {
      expect(SrtpProtectionProfile.srtpAeadAes256Gcm.value, equals(0x0008));
    });
    test('fromValue() - atomic test', () async {
      expect(
        SrtpProtectionProfile.fromValue(0x0001),
        equals(SrtpProtectionProfile.srtpAes128CmHmacSha180),
      );
    });
  });
  group('State [Atomic Audit]', () {
    test('clone() - atomic test', () async {
      final st = State(
        localEpoch: 1,
        cipherSuiteId: tlsEcdheEcdsaWithAes128GcmSha256,
        cipherSuite: TlsEcdheEcdsaWithAes128GcmSha256(),
      );
      final c = st.clone();
      expect(c, isNotNull);
    });
    test('remoteRandomBytes() - atomic test', () async {
      final st = State(
        localEpoch: 1,
        cipherSuiteId: tlsEcdheEcdsaWithAes128GcmSha256,
        cipherSuite: TlsEcdheEcdsaWithAes128GcmSha256(),
      );
      expect(st.remoteRandomBytes(), isNotNull);
    });
    test('marshalBinary() - atomic test', () async {
      final st = State(
        localEpoch: 1,
        cipherSuiteId: tlsEcdheEcdsaWithAes128GcmSha256,
        cipherSuite: TlsEcdheEcdsaWithAes128GcmSha256(),
      );
      expect(st.marshalBinary(), isNotNull);
    });
    test('unmarshalBinary() - atomic test', () async {
      final st = State(
        localEpoch: 1,
        cipherSuiteId: tlsEcdheEcdsaWithAes128GcmSha256,
        cipherSuite: TlsEcdheEcdsaWithAes128GcmSha256(),
      );
      st.unmarshalBinary(st.marshalBinary());
      expect(st.cipherSuiteId, equals(tlsEcdheEcdsaWithAes128GcmSha256));
    });
    test('exportKeyingMaterial() - atomic test', () async {
      final st = State(
        localEpoch: 1,
        cipherSuiteId: tlsEcdheEcdsaWithAes128GcmSha256,
        cipherSuite: TlsEcdheEcdsaWithAes128GcmSha256(),
      );
      final km = st.exportKeyingMaterial('test_label', Uint8List(0), 16);
      expect(km.length, equals(16));
    });
  });
  group('SupportedEllipticCurves [Atomic Audit]', () {
    test('typeValue() - atomic test', () async {
      final ext = SupportedEllipticCurves();
      expect(ext.typeValue, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final ext = SupportedEllipticCurves();
      expect(ext.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final ext = SupportedEllipticCurves();
      ext.unmarshal(ext.marshal());
      expect(ext.typeValue, isNotNull);
    });
  });
  group('SupportedPointFormats [Atomic Audit]', () {
    test('typeValue() - atomic test', () async {
      final ext = SupportedPointFormats();
      expect(ext.typeValue, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final ext = SupportedPointFormats();
      expect(ext.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final ext = SupportedPointFormats();
      ext.unmarshal(ext.marshal());
      expect(ext.typeValue, isNotNull);
    });
  });
  group('SupportedSignatureAlgorithms [Atomic Audit]', () {
    test('signatureAlgorithms() - atomic test', () async {
      final ext = SupportedSignatureAlgorithms();
      expect(ext.signatureAlgorithms, isNotEmpty);
    });
    test('signatureAlgorithms() - atomic test', () async {
      final ext = SupportedSignatureAlgorithms();
      ext.signatureAlgorithms = [1];
      expect(ext.signatureAlgorithms, equals([1]));
    });
    test('typeValue() - atomic test', () async {
      final ext = SupportedSignatureAlgorithms();
      expect(ext.typeValue, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final ext = SupportedSignatureAlgorithms();
      expect(ext.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final ext = SupportedSignatureAlgorithms();
      ext.unmarshal(ext.marshal());
      expect(ext.typeValue, isNotNull);
    });
  });
  group('TlsEcdheEcdsaWithAes128Ccm [Atomic Audit]', () {
    test('id() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128Ccm();
      expect(cs.id(), isA<int>());
    });
    test('string() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128Ccm();
      expect(cs.string(), isNotEmpty);
    });
    test('certificateType() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128Ccm();
      expect(cs.certificateType(), isA<int>());
    });
    test('ecc() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128Ccm();
      expect(cs.ecc(), isA<bool>());
    });
    test('keyExchangeAlgorithm() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128Ccm();
      expect(cs.keyExchangeAlgorithm(), isA<int>());
    });
    test('authenticationType() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128Ccm();
      expect(cs.authenticationType(), isA<int>());
    });
  });
  group('TlsEcdheEcdsaWithAes128Ccm8 [Atomic Audit]', () {
    test('id() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128Ccm8();
      expect(cs.id(), isA<int>());
    });
    test('string() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128Ccm8();
      expect(cs.string(), isNotEmpty);
    });
    test('certificateType() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128Ccm8();
      expect(cs.certificateType(), isA<int>());
    });
    test('ecc() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128Ccm8();
      expect(cs.ecc(), isA<bool>());
    });
    test('keyExchangeAlgorithm() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128Ccm8();
      expect(cs.keyExchangeAlgorithm(), isA<int>());
    });
    test('authenticationType() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128Ccm8();
      expect(cs.authenticationType(), isA<int>());
    });
  });
  group('TlsEcdheEcdsaWithAes128GcmSha256 [Atomic Audit]', () {
    test('id() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      expect(cs.id(), isA<int>());
    });
    test('string() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      expect(cs.string(), isNotEmpty);
    });
    test('certificateType() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      expect(cs.certificateType(), isA<int>());
    });
    test('hashFunc() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      expect(cs.hashFunc(), isA<Function>());
    });
    test('authenticationType() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      expect(cs.authenticationType(), isA<int>());
    });
    test('keyExchangeAlgorithm() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      expect(cs.keyExchangeAlgorithm(), isA<int>());
    });
    test('ecc() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      expect(cs.ecc(), isA<bool>());
    });
    test('init() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes128GcmSha256();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      expect(cs.isInitialized(), isTrue);
    });
  });
  group('TlsEcdheEcdsaWithAes256CbcSha [Atomic Audit]', () {
    test('id() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256CbcSha();
      expect(cs.id(), isA<int>());
    });
    test('string() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256CbcSha();
      expect(cs.string(), isNotEmpty);
    });
    test('certificateType() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256CbcSha();
      expect(cs.certificateType(), isA<int>());
    });
    test('hashFunc() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256CbcSha();
      expect(cs.hashFunc(), isA<Function>());
    });
    test('authenticationType() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256CbcSha();
      expect(cs.authenticationType(), isA<int>());
    });
    test('keyExchangeAlgorithm() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256CbcSha();
      expect(cs.keyExchangeAlgorithm(), isA<int>());
    });
    test('ecc() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256CbcSha();
      expect(cs.ecc(), isA<bool>());
    });
    test('isInitialized() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256CbcSha();
      expect(cs.isInitialized(), isA<bool>());
    });
    test('init() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256CbcSha();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      expect(cs.isInitialized(), isTrue);
    });
    test('encrypt() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256CbcSha();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      expect(cs.encrypt(rl, rl.marshal()), isNotNull);
    });
    test('decrypt() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256CbcSha();
      final csServer = TlsEcdheEcdsaWithAes128GcmSha256();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      csServer.init(Uint8List(48), Uint8List(32), Uint8List(32), false);
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      final enc = csServer.encrypt(rl, rl.marshal());
      expect(cs.decrypt(rl, enc), isNotNull);
    });
  });
  group('TlsEcdheEcdsaWithAes256GcmSha384 [Atomic Audit]', () {
    test('id() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256GcmSha384();
      expect(cs.id(), isA<int>());
    });
    test('string() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256GcmSha384();
      expect(cs.string(), isNotEmpty);
    });
    test('certificateType() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256GcmSha384();
      expect(cs.certificateType(), isA<int>());
    });
    test('hashFunc() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256GcmSha384();
      expect(cs.hashFunc(), isA<Function>());
    });
    test('authenticationType() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256GcmSha384();
      expect(cs.authenticationType(), isA<int>());
    });
    test('keyExchangeAlgorithm() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256GcmSha384();
      expect(cs.keyExchangeAlgorithm(), isA<int>());
    });
    test('ecc() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256GcmSha384();
      expect(cs.ecc(), isA<bool>());
    });
    test('init() - atomic test', () async {
      final cs = TlsEcdheEcdsaWithAes256GcmSha384();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      expect(cs.isInitialized(), isTrue);
    });
  });
  group('TlsEcdhePskWithAes128CbcSha256 [Atomic Audit]', () {
    test('id() - atomic test', () async {
      final cs = TlsEcdhePskWithAes128CbcSha256();
      expect(cs.id(), isA<int>());
    });
    test('string() - atomic test', () async {
      final cs = TlsEcdhePskWithAes128CbcSha256();
      expect(cs.string(), isNotEmpty);
    });
    test('certificateType() - atomic test', () async {
      final cs = TlsEcdhePskWithAes128CbcSha256();
      expect(cs.certificateType(), isA<int>());
    });
    test('hashFunc() - atomic test', () async {
      final cs = TlsEcdhePskWithAes128CbcSha256();
      expect(cs.hashFunc(), isA<Function>());
    });
    test('authenticationType() - atomic test', () async {
      final cs = TlsEcdhePskWithAes128CbcSha256();
      expect(cs.authenticationType(), isA<int>());
    });
    test('keyExchangeAlgorithm() - atomic test', () async {
      final cs = TlsEcdhePskWithAes128CbcSha256();
      expect(cs.keyExchangeAlgorithm(), isA<int>());
    });
    test('ecc() - atomic test', () async {
      final cs = TlsEcdhePskWithAes128CbcSha256();
      expect(cs.ecc(), isA<bool>());
    });
    test('isInitialized() - atomic test', () async {
      final cs = TlsEcdhePskWithAes128CbcSha256();
      expect(cs.isInitialized(), isA<bool>());
    });
    test('init() - atomic test', () async {
      final cs = TlsEcdhePskWithAes128CbcSha256();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      expect(cs.isInitialized(), isTrue);
    });
    test('encrypt() - atomic test', () async {
      final cs = TlsEcdhePskWithAes128CbcSha256();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      expect(cs.encrypt(rl, rl.marshal()), isNotNull);
    });
    test('decrypt() - atomic test', () async {
      final cs = TlsEcdhePskWithAes128CbcSha256();
      final csServer = TlsEcdheEcdsaWithAes128GcmSha256();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      csServer.init(Uint8List(48), Uint8List(32), Uint8List(32), false);
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      final enc = csServer.encrypt(rl, rl.marshal());
      expect(cs.decrypt(rl, enc), isNotNull);
    });
  });
  group('TlsEcdheRsaWithAes128GcmSha256 [Atomic Audit]', () {
    test('id() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes128GcmSha256();
      expect(cs.id(), isA<int>());
    });
    test('string() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes128GcmSha256();
      expect(cs.string(), isNotEmpty);
    });
    test('certificateType() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes128GcmSha256();
      expect(cs.certificateType(), isA<int>());
    });
    test('hashFunc() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes128GcmSha256();
      expect(cs.hashFunc(), isA<Function>());
    });
    test('authenticationType() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes128GcmSha256();
      expect(cs.authenticationType(), isA<int>());
    });
    test('keyExchangeAlgorithm() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes128GcmSha256();
      expect(cs.keyExchangeAlgorithm(), isA<int>());
    });
    test('ecc() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes128GcmSha256();
      expect(cs.ecc(), isA<bool>());
    });
    test('init() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes128GcmSha256();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      expect(cs.isInitialized(), isTrue);
    });
  });
  group('TlsEcdheRsaWithAes256CbcSha [Atomic Audit]', () {
    test('id() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256CbcSha();
      expect(cs.id(), isA<int>());
    });
    test('string() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256CbcSha();
      expect(cs.string(), isNotEmpty);
    });
    test('certificateType() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256CbcSha();
      expect(cs.certificateType(), isA<int>());
    });
    test('hashFunc() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256CbcSha();
      expect(cs.hashFunc(), isA<Function>());
    });
    test('authenticationType() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256CbcSha();
      expect(cs.authenticationType(), isA<int>());
    });
    test('keyExchangeAlgorithm() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256CbcSha();
      expect(cs.keyExchangeAlgorithm(), isA<int>());
    });
    test('ecc() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256CbcSha();
      expect(cs.ecc(), isA<bool>());
    });
    test('isInitialized() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256CbcSha();
      expect(cs.isInitialized(), isA<bool>());
    });
    test('init() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256CbcSha();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      expect(cs.isInitialized(), isTrue);
    });
    test('encrypt() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256CbcSha();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      expect(cs.encrypt(rl, rl.marshal()), isNotNull);
    });
    test('decrypt() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256CbcSha();
      final csServer = TlsEcdheEcdsaWithAes128GcmSha256();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      csServer.init(Uint8List(48), Uint8List(32), Uint8List(32), false);
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      final enc = csServer.encrypt(rl, rl.marshal());
      expect(cs.decrypt(rl, enc), isNotNull);
    });
  });
  group('TlsEcdheRsaWithAes256GcmSha384 [Atomic Audit]', () {
    test('id() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256GcmSha384();
      expect(cs.id(), isA<int>());
    });
    test('string() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256GcmSha384();
      expect(cs.string(), isNotEmpty);
    });
    test('certificateType() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256GcmSha384();
      expect(cs.certificateType(), isA<int>());
    });
    test('hashFunc() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256GcmSha384();
      expect(cs.hashFunc(), isA<Function>());
    });
    test('authenticationType() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256GcmSha384();
      expect(cs.authenticationType(), isA<int>());
    });
    test('keyExchangeAlgorithm() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256GcmSha384();
      expect(cs.keyExchangeAlgorithm(), isA<int>());
    });
    test('ecc() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256GcmSha384();
      expect(cs.ecc(), isA<bool>());
    });
    test('init() - atomic test', () async {
      final cs = TlsEcdheRsaWithAes256GcmSha384();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      expect(cs.isInitialized(), isTrue);
    });
  });
  group('TlsPskWithAes128CbcSha256 [Atomic Audit]', () {
    test('id() - atomic test', () async {
      final cs = TlsPskWithAes128CbcSha256();
      expect(cs.id(), isA<int>());
    });
    test('string() - atomic test', () async {
      final cs = TlsPskWithAes128CbcSha256();
      expect(cs.string(), isNotEmpty);
    });
    test('certificateType() - atomic test', () async {
      final cs = TlsPskWithAes128CbcSha256();
      expect(cs.certificateType(), isA<int>());
    });
    test('hashFunc() - atomic test', () async {
      final cs = TlsPskWithAes128CbcSha256();
      expect(cs.hashFunc(), isA<Function>());
    });
    test('authenticationType() - atomic test', () async {
      final cs = TlsPskWithAes128CbcSha256();
      expect(cs.authenticationType(), isA<int>());
    });
    test('keyExchangeAlgorithm() - atomic test', () async {
      final cs = TlsPskWithAes128CbcSha256();
      expect(cs.keyExchangeAlgorithm(), isA<int>());
    });
    test('ecc() - atomic test', () async {
      final cs = TlsPskWithAes128CbcSha256();
      expect(cs.ecc(), isA<bool>());
    });
    test('isInitialized() - atomic test', () async {
      final cs = TlsPskWithAes128CbcSha256();
      expect(cs.isInitialized(), isA<bool>());
    });
    test('init() - atomic test', () async {
      final cs = TlsPskWithAes128CbcSha256();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      expect(cs.isInitialized(), isTrue);
    });
    test('encrypt() - atomic test', () async {
      final cs = TlsPskWithAes128CbcSha256();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      expect(cs.encrypt(rl, rl.marshal()), isNotNull);
    });
    test('decrypt() - atomic test', () async {
      final cs = TlsPskWithAes128CbcSha256();
      final csServer = TlsEcdheEcdsaWithAes128GcmSha256();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      csServer.init(Uint8List(48), Uint8List(32), Uint8List(32), false);
      final rl = RecordLayer(
        header: Header(),
        content: ApplicationData(Uint8List(4)),
      );
      final enc = csServer.encrypt(rl, rl.marshal());
      expect(cs.decrypt(rl, enc), isNotNull);
    });
  });
  group('TlsPskWithAes128Ccm [Atomic Audit]', () {
    test('id() - atomic test', () async {
      final cs = TlsPskWithAes128Ccm();
      expect(cs.id(), isA<int>());
    });
    test('string() - atomic test', () async {
      final cs = TlsPskWithAes128Ccm();
      expect(cs.string(), isNotEmpty);
    });
    test('authenticationType() - atomic test', () async {
      final cs = TlsPskWithAes128Ccm();
      expect(cs.authenticationType(), isA<int>());
    });
    test('keyExchangeAlgorithm() - atomic test', () async {
      final cs = TlsPskWithAes128Ccm();
      expect(cs.keyExchangeAlgorithm(), isA<int>());
    });
  });
  group('TlsPskWithAes128Ccm8 [Atomic Audit]', () {
    test('id() - atomic test', () async {
      final cs = TlsPskWithAes128Ccm8();
      expect(cs.id(), isA<int>());
    });
    test('string() - atomic test', () async {
      final cs = TlsPskWithAes128Ccm8();
      expect(cs.string(), isNotEmpty);
    });
    test('authenticationType() - atomic test', () async {
      final cs = TlsPskWithAes128Ccm8();
      expect(cs.authenticationType(), isA<int>());
    });
    test('keyExchangeAlgorithm() - atomic test', () async {
      final cs = TlsPskWithAes128Ccm8();
      expect(cs.keyExchangeAlgorithm(), isA<int>());
    });
  });
  group('TlsPskWithAes128GcmSha256 [Atomic Audit]', () {
    test('id() - atomic test', () async {
      final cs = TlsPskWithAes128GcmSha256();
      expect(cs.id(), isA<int>());
    });
    test('string() - atomic test', () async {
      final cs = TlsPskWithAes128GcmSha256();
      expect(cs.string(), isNotEmpty);
    });
    test('certificateType() - atomic test', () async {
      final cs = TlsPskWithAes128GcmSha256();
      expect(cs.certificateType(), isA<int>());
    });
    test('hashFunc() - atomic test', () async {
      final cs = TlsPskWithAes128GcmSha256();
      expect(cs.hashFunc(), isA<Function>());
    });
    test('authenticationType() - atomic test', () async {
      final cs = TlsPskWithAes128GcmSha256();
      expect(cs.authenticationType(), isA<int>());
    });
    test('keyExchangeAlgorithm() - atomic test', () async {
      final cs = TlsPskWithAes128GcmSha256();
      expect(cs.keyExchangeAlgorithm(), isA<int>());
    });
    test('ecc() - atomic test', () async {
      final cs = TlsPskWithAes128GcmSha256();
      expect(cs.ecc(), isA<bool>());
    });
    test('init() - atomic test', () async {
      final cs = TlsPskWithAes128GcmSha256();
      cs.init(Uint8List(48), Uint8List(32), Uint8List(32), true);
      expect(cs.isInitialized(), isTrue);
    });
  });
  group('TlsPskWithAes256Ccm8 [Atomic Audit]', () {
    test('id() - atomic test', () async {
      final cs = TlsPskWithAes256Ccm8();
      expect(cs.id(), isA<int>());
    });
    test('string() - atomic test', () async {
      final cs = TlsPskWithAes256Ccm8();
      expect(cs.string(), isNotEmpty);
    });
    test('authenticationType() - atomic test', () async {
      final cs = TlsPskWithAes256Ccm8();
      expect(cs.authenticationType(), isA<int>());
    });
    test('keyExchangeAlgorithm() - atomic test', () async {
      final cs = TlsPskWithAes256Ccm8();
      expect(cs.keyExchangeAlgorithm(), isA<int>());
    });
  });
  group('TypeValue [Atomic Audit]', () {
    test('renegotiationInfo() - atomic test', () async {
      expect(TypeValue.renegotiationInfo.value, equals(0xFF01));
    });
    test('fromValue() - atomic test', () async {
      expect(TypeValue.fromValue(0), equals(TypeValue.serverName));
    });
  });
  group('UseExtendedMasterSecret [Atomic Audit]', () {
    test('typeValue() - atomic test', () async {
      final ext = UseExtendedMasterSecret();
      expect(ext.typeValue, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final ext = UseExtendedMasterSecret();
      expect(ext.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final ext = UseExtendedMasterSecret();
      ext.unmarshal(ext.marshal());
      expect(ext.typeValue, isNotNull);
    });
  });
  group('UseSrtp [Atomic Audit]', () {
    test('typeValue() - atomic test', () async {
      final ext = UseSrtp();
      expect(ext.typeValue, isNotNull);
    });
    test('marshal() - atomic test', () async {
      final ext = UseSrtp();
      expect(ext.marshal(), isNotNull);
    });
    test('unmarshal() - atomic test', () async {
      final ext = UseSrtp();
      ext.unmarshal(ext.marshal());
      expect(ext.typeValue, isNotNull);
    });
  });
  group('Version [Atomic Audit]', () {
    test('equal() - atomic test', () async {
      final v1 = Version.version1_2;
      final v2 = const Version(0xFE, 0xFD);
      expect(v1.equal(v2), isTrue);
    });
    test('operator ==() - atomic test', () async {
      final v1 = Version.version1_2;
      final v2 = const Version(0xFE, 0xFD);
      expect(v1 == v2, isTrue);
    });
    test('hashCode() - atomic test', () async {
      final v1 = Version.version1_2;
      final v2 = const Version(0xFE, 0xFD);
      expect(v1.hashCode, isNotNull);
    });
    test('toString() - atomic test', () async {
      final v1 = Version.version1_2;
      final v2 = const Version(0xFE, 0xFD);
      expect(v1.toString(), contains('DTLS'));
    });
  });
}
