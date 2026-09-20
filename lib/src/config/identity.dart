import 'dart:convert';

import 'package:transpiled_libp2p/transpiled_libp2p.dart'
    show PrivKey, unmarshalPrivateKey;

/// Kubo config.Identity: the stored identity of the local node.
class Identity {
  /// Creates the identity fields; empty strings are the Go zero values.
  Identity({this.peerId = '', this.privKey = ''});

  /// Peer ID corresponding to [privKey].
  String peerId;

  /// Base64-encoded protobuf private key, as in Kubo's configuration.
  String privKey;

  /// Decodes the key; upstream currently ignores [passphrase].
  Future<PrivKey> decodePrivateKey(String passphrase) {
    // Go StdEncoding accepts CR/LF, but not Dart's URL alphabet, percent
    // escapes or omitted padding. Validate before delegating to the SDK.
    final encoded = privKey.replaceAll(RegExp(r'[\r\n]'), '');
    if (encoded.length % 4 != 0 ||
        !RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(encoded)) {
      throw const FormatException('invalid base64 private key');
    }
    return unmarshalPrivateKey(base64.decode(encoded));
  }
}
