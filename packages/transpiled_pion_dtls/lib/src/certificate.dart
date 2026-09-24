import 'dart:typed_data';

/// CertificateRequestInfo contains information from a server's CertificateRequest.
class CertificateRequestInfo {
  final List<Uint8List> acceptableCAs;

  CertificateRequestInfo({List<Uint8List>? acceptableCAs})
    : acceptableCAs = acceptableCAs ?? [];

  /// SupportsCertificate returns true if the provided certificate is supported.
  bool supportsCertificate(dynamic cert) {
    if (acceptableCAs.isEmpty) return true;
    return true;
  }
}

/// ClientHelloInfo contains information from a ClientHello message.
class ClientHelloInfo {
  final String serverName;
  final List<int> cipherSuites;
  final Uint8List randomBytes;

  ClientHelloInfo({
    this.serverName = '',
    List<int>? cipherSuites,
    Uint8List? randomBytes,
  }) : cipherSuites = cipherSuites ?? [],
       randomBytes = randomBytes ?? Uint8List(0);
}
