// Port of github.com/pion/dtls/v3 internal/ciphersuite/types/authentication_type.go
//
// AuthenticationType controls what authentication method is used during
// the handshake.
class AuthenticationType {
  const AuthenticationType(this.value);

  final int value;

  static const AuthenticationType certificate = AuthenticationType(1);
  static const AuthenticationType preSharedKey = AuthenticationType(2);
  static const AuthenticationType anonymous = AuthenticationType(3);

  @override
  bool operator ==(Object other) =>
      other is AuthenticationType && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
