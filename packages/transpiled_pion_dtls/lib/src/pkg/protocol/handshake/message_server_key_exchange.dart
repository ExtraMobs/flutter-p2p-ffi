part of 'handshake.dart';

// Port of pkg/protocol/handshake/message_server_key_exchange.go.
//
// Depends on `pkg/crypto/elliptic`, `pkg/crypto/hash`, `pkg/crypto/
// signature`, owned by a concurrent agent -- see `handshake.dart`'s library
// doc for the assumed shape (`elliptic.Curve`/`hash.Algorithm`/
// `signature.Algorithm` as open value classes constructible from an
// unchecked wire int, `elliptic.none`/`hash.none`/`signature.anonymous` as
// top-level sentinel constants, `elliptic.curves()`/`curveTypes()`/
// `hash.algorithms()`/`signature.algorithms()` returning `Set<T>`).

/// MessageServerKeyExchange supports ECDH and PSK.
///
/// Port of `MessageServerKeyExchange` (message_server_key_exchange.go:16-27)
/// and its methods `Type`/`Marshal`/`Unmarshal`
/// (message_server_key_exchange.go:30-150). `KeyExchangeAlgorithm` is a
/// plain `int` bitmask here -- see `handshake.dart`'s library doc.
final class MessageServerKeyExchange implements Message {
  Uint8List? identityHint;

  elliptic.CurveType? ellipticCurveType;
  elliptic.Curve? namedCurve;
  Uint8List publicKey;
  hash.Algorithm hashAlgorithm;
  signature.Algorithm signatureAlgorithm;
  Uint8List signatureBytes;

  /// For unmarshaling.
  int keyExchangeAlgorithm;

  MessageServerKeyExchange({
    this.identityHint,
    this.ellipticCurveType,
    this.namedCurve,
    Uint8List? publicKey,
    hash.Algorithm? hashAlgorithm,
    signature.Algorithm? signatureAlgorithm,
    Uint8List? signatureBytes,
    this.keyExchangeAlgorithm = 0,
  }) : publicKey = publicKey ?? Uint8List(0),
       hashAlgorithm = hashAlgorithm ?? hash.none,
       signatureAlgorithm = signatureAlgorithm ?? signature.anonymous,
       signatureBytes = signatureBytes ?? Uint8List(0);

  @override
  HandshakeType get type => HandshakeType.serverKeyExchange;

  /// Marshal encodes the Handshake.
  @override
  Uint8List marshal() {
    final out = BytesBuilder();
    final hint = identityHint;
    if (hint != null) {
      out.add([(hint.length >> 8) & 0xff, hint.length & 0xff]);
      out.add(hint);
    }

    final curveType = ellipticCurveType;
    if (curveType == null || curveType.value == 0 || publicKey.isEmpty) {
      return out.toBytes();
    }
    out.addByte(curveType.value);
    final curveValue = namedCurve?.value ?? 0;
    out.add([(curveValue >> 8) & 0xff, curveValue & 0xff]);

    out.addByte(publicKey.length);
    out.add(publicKey);

    if (hashAlgorithm != hash.none && signatureBytes.isEmpty) {
      throw _errInvalidHashAlgorithm;
    }
    if (hashAlgorithm == hash.none && signatureBytes.isNotEmpty) {
      throw _errInvalidHashAlgorithm;
    }
    if (signatureAlgorithm == signature.anonymous &&
        (hashAlgorithm != hash.none || signatureBytes.isNotEmpty)) {
      throw _errInvalidSignatureAlgorithm;
    }
    if (signatureAlgorithm == signature.anonymous) {
      return out.toBytes();
    }

    out.add([
      hashAlgorithm.value,
      signatureAlgorithm.value,
      (signatureBytes.length >> 8) & 0xff,
      signatureBytes.length & 0xff,
    ]);
    out.add(signatureBytes);

    return out.toBytes();
  }

  /// Unmarshal populates the message from encoded data.
  @override
  void unmarshal(Uint8List data) {
    if (data.length < 2) throw _errBufferTooSmall;
    if (keyExchangeAlgorithm == 0) throw _errCipherSuiteUnset;

    final hintLength = (data[0] << 8) | data[1];
    var rest = data;
    if (hintLength <= data.length - 2 &&
        (keyExchangeAlgorithm &
                cipherSuite.cipherSuiteKeyExchangeAlgorithmPsk) ==
            cipherSuite.cipherSuiteKeyExchangeAlgorithmPsk) {
      identityHint = Uint8List.fromList(data.sublist(2, 2 + hintLength));
      rest = Uint8List.sublistView(data, 2 + hintLength);
    }
    if (keyExchangeAlgorithm ==
        cipherSuite.cipherSuiteKeyExchangeAlgorithmPsk) {
      if (rest.isEmpty) return;
      throw _errLengthMismatch;
    }

    if ((keyExchangeAlgorithm &
            cipherSuite.cipherSuiteKeyExchangeAlgorithmEcdhe) !=
        cipherSuite.cipherSuiteKeyExchangeAlgorithmEcdhe) {
      throw _errLengthMismatch;
    }

    final curveType = elliptic.CurveType(rest[0]);
    if (elliptic.curveTypes().contains(curveType)) {
      ellipticCurveType = curveType;
    } else {
      throw _errInvalidEllipticCurveType;
    }

    if (rest.length - 1 < 2) throw _errBufferTooSmall;
    final curve = elliptic.Curve((rest[1] << 8) | rest[2]);
    if (!elliptic.curves().contains(curve)) throw _errInvalidNamedCurve;
    namedCurve = curve;
    if (rest.length < 4) throw _errBufferTooSmall;

    final publicKeyLength = rest[3];
    final offsetAfterKey = 4 + publicKeyLength;
    if (rest.length < offsetAfterKey) throw _errBufferTooSmall;
    publicKey = Uint8List.fromList(rest.sublist(4, offsetAfterKey));

    // Anon connection doesn't contain hashAlgorithm, signatureAlgorithm,
    // signature.
    if (rest.length == offsetAfterKey) return;
    if (rest.length <= offsetAfterKey) throw _errBufferTooSmall;

    var offset = offsetAfterKey;
    final h = hash.Algorithm(rest[offset]);
    if (!hash.algorithms().contains(h)) throw _errInvalidHashAlgorithm;
    hashAlgorithm = h;
    offset++;
    if (rest.length <= offset) throw _errBufferTooSmall;

    final s = signature.Algorithm(rest[offset]);
    if (!signature.algorithms().contains(s))
      throw _errInvalidSignatureAlgorithm;
    signatureAlgorithm = s;
    offset++;
    if (rest.length < offset + 2) throw _errBufferTooSmall;

    final signatureLength = (rest[offset] << 8) | rest[offset + 1];
    offset += 2;
    if (rest.length < offset + signatureLength) throw _errBufferTooSmall;
    signatureBytes = Uint8List.fromList(
      rest.sublist(offset, offset + signatureLength),
    );
  }
}
