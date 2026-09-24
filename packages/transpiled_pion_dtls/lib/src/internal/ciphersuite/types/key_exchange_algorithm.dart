// Port of github.com/pion/dtls/v3 internal/ciphersuite/types/key_exchange_algorithm.go
//
// KeyExchangeAlgorithm controls what exchange algorithm was chosen. This is
// a bitmask in Go (`KeyExchangeAlgorithmPsk | KeyExchangeAlgorithmEcdhe` is
// a valid value, used by TLS_ECDHE_PSK_* suites), so unlike the plain enums
// elsewhere in this port, this needs `|`/`&` operators rather than a fixed
// set of named constants.
class KeyExchangeAlgorithm {
  const KeyExchangeAlgorithm(this.value);

  final int value;

  static const KeyExchangeAlgorithm none = KeyExchangeAlgorithm(0);
  static const KeyExchangeAlgorithm psk = KeyExchangeAlgorithm(2);
  static const KeyExchangeAlgorithm ecdhe = KeyExchangeAlgorithm(4);

  KeyExchangeAlgorithm operator |(KeyExchangeAlgorithm other) =>
      KeyExchangeAlgorithm(value | other.value);

  KeyExchangeAlgorithm operator &(KeyExchangeAlgorithm other) =>
      KeyExchangeAlgorithm(value & other.value);

  /// Has checks if keyExchangeAlgorithm is supported.
  bool has(KeyExchangeAlgorithm v) => (this & v) == v;

  @override
  bool operator ==(Object other) =>
      other is KeyExchangeAlgorithm && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
