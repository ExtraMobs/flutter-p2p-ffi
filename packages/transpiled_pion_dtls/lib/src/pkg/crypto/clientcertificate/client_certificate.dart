// Port of github.com/pion/dtls/v3 pkg/crypto/clientcertificate/client_certificate.go
//
// Provides all the support for Client Certificate types.

/// Type is used to communicate what type of certificate is being
/// transported.
///
/// https://www.iana.org/assignments/tls-parameters/tls-parameters.xhtml#tls-parameters-2
class ClientCertificateType {
  const ClientCertificateType(this.value);

  final int value;

  static const ClientCertificateType rsaSign = ClientCertificateType(1);
  static const ClientCertificateType ecdsaSign = ClientCertificateType(64);

  /// Types returns all valid ClientCertificate Types.
  static Map<ClientCertificateType, bool> types() => {
    rsaSign: true,
    ecdsaSign: true,
  };

  @override
  bool operator ==(Object other) =>
      other is ClientCertificateType && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ClientCertificateType($value)';
}
