import 'dart:typed_data';
import 'pkg/protocol/extension/extension.dart';

enum ClientAuthType {
  noClientCert(0),
  requestClientCert(1),
  requireAnyClientCert(2),
  verifyClientCertIfGiven(3),
  requireAndVerifyClientCert(4);

  final int value;
  const ClientAuthType(this.value);
}

enum ExtendedMasterSecretType {
  request(0),
  require(1),
  disable(2);

  final int value;
  const ExtendedMasterSecretType(this.value);
}

/// Config is used to configure a DTLS client or server.
class Config {
  List<dynamic> certificates;
  List<int> cipherSuites;
  dynamic customCipherSuites;
  List<int> signatureSchemes;
  List<int> certificateSignatureSchemes;
  List<SrtpProtectionProfile> srtpProtectionProfiles;
  Uint8List srtpMasterKeyIdentifier;
  ClientAuthType clientAuth;
  ExtendedMasterSecretType extendedMasterSecret;
  Duration flightInterval;
  bool disableRetransmitBackoff;
  dynamic psk;
  Uint8List pskIdentityHint;
  bool insecureSkipVerify;
  bool insecureHashes;
  dynamic verifyPeerCertificate;
  dynamic verifyConnection;
  dynamic rootCAs;
  dynamic clientCAs;
  String serverName;
  dynamic loggerFactory;
  int mtu;
  int replayProtectionWindow;
  dynamic keyLogWriter;
  dynamic sessionStore;
  List<String> supportedProtocols;
  List<int> ellipticCurves;
  dynamic getCertificate;
  dynamic getClientCertificate;
  bool insecureSkipVerifyHello;
  dynamic connectionIdGenerator;
  dynamic paddingLengthGenerator;
  dynamic helloRandomBytesGenerator;
  dynamic clientHelloMessageHook;
  dynamic serverHelloMessageHook;
  dynamic certificateRequestMessageHook;
  dynamic onConnectionAttempt;

  Config({
    List<dynamic>? certificates,
    List<int>? cipherSuites,
    this.customCipherSuites,
    List<int>? signatureSchemes,
    List<int>? certificateSignatureSchemes,
    List<SrtpProtectionProfile>? srtpProtectionProfiles,
    Uint8List? srtpMasterKeyIdentifier,
    this.clientAuth = ClientAuthType.noClientCert,
    this.extendedMasterSecret = ExtendedMasterSecretType.request,
    this.flightInterval = const Duration(seconds: 1),
    this.disableRetransmitBackoff = false,
    this.psk,
    Uint8List? pskIdentityHint,
    this.insecureSkipVerify = false,
    this.insecureHashes = false,
    this.verifyPeerCertificate,
    this.verifyConnection,
    this.rootCAs,
    this.clientCAs,
    this.serverName = '',
    this.loggerFactory,
    this.mtu = 1200,
    this.replayProtectionWindow = 64,
    this.keyLogWriter,
    this.sessionStore,
    List<String>? supportedProtocols,
    List<int>? ellipticCurves,
    this.getCertificate,
    this.getClientCertificate,
    this.insecureSkipVerifyHello = false,
    this.connectionIdGenerator,
    this.paddingLengthGenerator,
    this.helloRandomBytesGenerator,
    this.clientHelloMessageHook,
    this.serverHelloMessageHook,
    this.certificateRequestMessageHook,
    this.onConnectionAttempt,
  }) : certificates = certificates ?? [],
       cipherSuites = cipherSuites ?? [],
       signatureSchemes = signatureSchemes ?? [],
       certificateSignatureSchemes = certificateSignatureSchemes ?? [],
       srtpProtectionProfiles = srtpProtectionProfiles ?? [],
       srtpMasterKeyIdentifier = srtpMasterKeyIdentifier ?? Uint8List(0),
       pskIdentityHint = pskIdentityHint ?? Uint8List(0),
       supportedProtocols = supportedProtocols ?? [],
       ellipticCurves = ellipticCurves ?? [];
}

/// ClientOption interface.
abstract class ClientOption {
  void apply(Config c);
  void call(Config c);
}

/// ServerOption interface.
abstract class ServerOption {
  void apply(Config c);
  void call(Config c);
}

/// Option interface.
abstract class Option implements ClientOption, ServerOption {
  @override
  void apply(Config c);
  @override
  void call(Config c);
}

class _OptionFunc implements Option {
  final void Function(Config) _apply;
  _OptionFunc(this._apply);

  @override
  void apply(Config c) => _apply(c);

  @override
  void call(Config c) => _apply(c);
}

Option withCertificates(List<dynamic> certs) =>
    _OptionFunc((c) => c.certificates = certs);

Option withCipherSuites(List<int> suites) =>
    _OptionFunc((c) => c.cipherSuites = suites);

Option withCustomCipherSuites(dynamic suites) =>
    _OptionFunc((c) => c.customCipherSuites = suites);

Option withSignatureSchemes(List<int> schemes) =>
    _OptionFunc((c) => c.signatureSchemes = schemes);

Option withCertificateSignatureSchemes(List<int> schemes) =>
    _OptionFunc((c) => c.certificateSignatureSchemes = schemes);

Option withSrtpProtectionProfiles(List<SrtpProtectionProfile> profiles) =>
    _OptionFunc((c) => c.srtpProtectionProfiles = profiles);

Option withSrtpMasterKeyIdentifier(Uint8List mki) =>
    _OptionFunc((c) => c.srtpMasterKeyIdentifier = mki);

Option withExtendedMasterSecret(ExtendedMasterSecretType type) =>
    _OptionFunc((c) => c.extendedMasterSecret = type);

Option withFlightInterval(Duration interval) =>
    _OptionFunc((c) => c.flightInterval = interval);

Option withDisableRetransmitBackoff() =>
    _OptionFunc((c) => c.disableRetransmitBackoff = true);

Option withPsk(dynamic psk) => _OptionFunc((c) => c.psk = psk);

Option withPskIdentityHint(Uint8List hint) =>
    _OptionFunc((c) => c.pskIdentityHint = hint);

Option withInsecureSkipVerify() =>
    _OptionFunc((c) => c.insecureSkipVerify = true);

Option withInsecureHashes() => _OptionFunc((c) => c.insecureHashes = true);

Option withVerifyPeerCertificate(dynamic fn) =>
    _OptionFunc((c) => c.verifyPeerCertificate = fn);

Option withVerifyConnection(dynamic fn) =>
    _OptionFunc((c) => c.verifyConnection = fn);

Option withRootCAs(dynamic cas) => _OptionFunc((c) => c.rootCAs = cas);

Option withServerName(String name) => _OptionFunc((c) => c.serverName = name);

Option withLoggerFactory(dynamic lf) =>
    _OptionFunc((c) => c.loggerFactory = lf);

Option withMtu(int mtu) => _OptionFunc((c) => c.mtu = mtu);

Option withReplayProtectionWindow(int window) =>
    _OptionFunc((c) => c.replayProtectionWindow = window);

Option withKeyLogWriter(dynamic writer) =>
    _OptionFunc((c) => c.keyLogWriter = writer);

Option withSessionStore(dynamic store) =>
    _OptionFunc((c) => c.sessionStore = store);

Option withSupportedProtocols(List<String> protocols) =>
    _OptionFunc((c) => c.supportedProtocols = protocols);

Option withEllipticCurves(List<int> curves) =>
    _OptionFunc((c) => c.ellipticCurves = curves);

Option withGetClientCertificate(dynamic fn) =>
    _OptionFunc((c) => c.getClientCertificate = fn);

Option withConnectionIdGenerator(dynamic gen) =>
    _OptionFunc((c) => c.connectionIdGenerator = gen);

Option withPaddingLengthGenerator(dynamic gen) =>
    _OptionFunc((c) => c.paddingLengthGenerator = gen);

Option withHelloRandomBytesGenerator(dynamic gen) =>
    _OptionFunc((c) => c.helloRandomBytesGenerator = gen);

Option withClientHelloMessageHook(dynamic hook) =>
    _OptionFunc((c) => c.clientHelloMessageHook = hook);

Option withClientAuth(ClientAuthType auth) =>
    _OptionFunc((c) => c.clientAuth = auth);

Option withClientCAs(dynamic cas) => _OptionFunc((c) => c.clientCAs = cas);

Option withGetCertificate(dynamic fn) =>
    _OptionFunc((c) => c.getCertificate = fn);

Option withInsecureSkipVerifyHello() =>
    _OptionFunc((c) => c.insecureSkipVerifyHello = true);

Option withServerHelloMessageHook(dynamic hook) =>
    _OptionFunc((c) => c.serverHelloMessageHook = hook);

Option withCertificateRequestMessageHook(dynamic hook) =>
    _OptionFunc((c) => c.certificateRequestMessageHook = hook);

Option withOnConnectionAttempt(dynamic cb) =>
    _OptionFunc((c) => c.onConnectionAttempt = cb);
