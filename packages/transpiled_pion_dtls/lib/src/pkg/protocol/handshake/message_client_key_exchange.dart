part of 'handshake.dart';

// Port of pkg/protocol/handshake/message_client_key_exchange.go.

/// MessageClientKeyExchange is a DTLS Handshake Message. With this message,
/// the premaster secret is set, either by direct transmission of the
/// RSA-encrypted secret or by the transmission of Diffie-Hellman parameters
/// that will allow each side to agree upon the same premaster secret.
/// https://tools.ietf.org/html/rfc5246#section-7.4.7
///
/// Port of `MessageClientKeyExchange` (message_client_key_exchange.go:17-23)
/// and its methods `Type`/`Marshal`/`Unmarshal`
/// (message_client_key_exchange.go:26-79). `KeyExchangeAlgorithm` (Go's
/// `types.KeyExchangeAlgorithm`) is a plain `int` bitmask here -- see
/// `handshake.dart`'s library doc.
final class MessageClientKeyExchange implements Message {
  Uint8List? identityHint;
  Uint8List? publicKey;

  /// For unmarshaling.
  int keyExchangeAlgorithm;

  MessageClientKeyExchange({
    this.identityHint,
    this.publicKey,
    this.keyExchangeAlgorithm = 0,
  });

  @override
  HandshakeType get type => HandshakeType.clientKeyExchange;

  /// Marshal encodes the Handshake.
  @override
  Uint8List marshal() {
    final hint = identityHint;
    final pubKey = publicKey;
    if (hint == null && pubKey == null) throw _errInvalidClientKeyExchange;

    final out = BytesBuilder();
    if (hint != null) {
      final withHeader = Uint8List(2 + hint.length);
      withHeader[0] = (hint.length >> 8) & 0xff;
      withHeader[1] = hint.length & 0xff;
      withHeader.setRange(2, withHeader.length, hint);
      out.add(withHeader);
    }

    if (pubKey != null) {
      out.addByte(pubKey.length);
      out.add(pubKey);
    }

    return out.toBytes();
  }

  /// Unmarshal populates the message from encoded data.
  @override
  void unmarshal(Uint8List data) {
    if (data.length < 2) throw _errBufferTooSmall;
    if (keyExchangeAlgorithm == 0) throw _errCipherSuiteUnset;

    var offset = 0;
    if ((keyExchangeAlgorithm &
            cipherSuite.cipherSuiteKeyExchangeAlgorithmPsk) ==
        cipherSuite.cipherSuiteKeyExchangeAlgorithmPsk) {
      final pskLength = (data[0] << 8) | data[1];
      if (pskLength > data.length - 2) throw _errBufferTooSmall;
      identityHint = Uint8List.fromList(data.sublist(2, pskLength + 2));
      offset += pskLength + 2;
    }

    if ((keyExchangeAlgorithm &
            cipherSuite.cipherSuiteKeyExchangeAlgorithmEcdhe) ==
        cipherSuite.cipherSuiteKeyExchangeAlgorithmEcdhe) {
      final publicKeyLength = data[offset];
      if (publicKeyLength > data.length - 1 - offset) {
        throw _errBufferTooSmall;
      }
      publicKey = Uint8List.fromList(data.sublist(offset + 1));
    }
  }
}
