part of 'extension.dart';

// Port of pkg/protocol/extension/key_share.go.
//
// Depends on `pkg/crypto/elliptic` (`elliptic.Curve`), owned by a concurrent
// agent -- see `extension.dart`'s library doc.

/// Port of `KeyShareEntry` (key_share.go:11-14).
final class KeyShareEntry {
  elliptic.Curve group;
  Uint8List keyExchange;

  KeyShareEntry({required this.group, Uint8List? keyExchange})
    : keyExchange = keyExchange ?? Uint8List(0);
}

/// KeyShare represents the "key_share" extension. Only one of the fields
/// can be used at a time. See RFC 8446 section 4.2.8.
///
/// Port of `KeyShare` (key_share.go:17-21) and its methods
/// `TypeValue`/`Marshal`/`Unmarshal` (key_share.go:26-179).
final class KeyShare implements Extension {
  /// ClientHello.
  List<KeyShareEntry>? clientShares;

  /// ServerHello.
  KeyShareEntry? serverShare;

  /// HelloRetryRequest.
  elliptic.Curve? selectedGroup;

  KeyShare({this.clientShares, this.serverShare, this.selectedGroup});

  @override
  TypeValue get typeValue => TypeValue.keyShare;

  @override
  Uint8List marshal() {
    final hasClientShares = clientShares != null; // vector MAY be empty
    final hasServerShare = serverShare != null;
    final hasHelloRetryRequest = selectedGroup != null;

    // There must be exactly one context.
    if (_hasTooManyContexts(
      hasClientShares,
      hasServerShare,
      hasHelloRetryRequest,
    )) {
      throw _errInvalidKeyShareFormat;
    }

    final builder = _CryptobyteBuilder();
    builder.addUint16(typeValue.value);

    if (hasClientShares) {
      final seenGroups = <elliptic.Curve>{};
      for (final e in clientShares!) {
        if (seenGroups.contains(e.group)) throw _errDuplicateKeyShare;
        seenGroups.add(e.group);
        final l = e.keyExchange.length;
        if (l == 0 || l > 0xffff) throw _errInvalidKeyShareFormat;
      }
    }

    if (hasServerShare) {
      final l = serverShare!.keyExchange.length;
      if (l == 0 || l > 0xffff) throw _errInvalidKeyShareFormat;
    }

    builder.addUint16LengthPrefixed((b) {
      if (hasHelloRetryRequest) {
        // KeyShareHelloRetryRequest { NamedGroup selected_group; }
        b.addUint16(selectedGroup!.value);
      } else if (hasServerShare) {
        // KeyShareServerHello { KeyShareEntry server_share; }
        _addKeyShareEntry(b, serverShare!);
      } else {
        // KeyShareClientHello { KeyShareEntry client_shares<0..2^16-1>; }
        b.addUint16LengthPrefixed((b) {
          for (final e in clientShares!) {
            _addKeyShareEntry(b, e);
          }
        });
      }
    });

    return builder.toBytes();
  }

  @override
  void unmarshal(Uint8List data) {
    final val = _CryptobyteReader(data);

    final ext = val.readUint16();
    if (ext != typeValue.value) throw _errInvalidExtensionType;

    final extData = val.readUint16LengthPrefixedReader();
    if (extData.isEmpty) throw _errInvalidKeyShareFormat;

    clientShares = null;
    serverShare = null;
    selectedGroup = null;

    final peek = extData.clone();
    var vecLenOk = false;
    var vecLen = 0;
    try {
      vecLen = peek.readUint16();
      vecLenOk = vecLen == peek.remainingLength;
    } on _CryptobyteFormatException {
      vecLenOk = false;
    }

    // ClientHello: client_shares is a uint16-length-prefixed vector.
    if (vecLenOk) {
      final seenGroups = <elliptic.Curve>{};
      final shares = <KeyShareEntry>[];
      while (!peek.isEmpty) {
        final groupU16 = peek.readUint16();
        final raw = peek.readUint16LengthPrefixed();
        if (raw.isEmpty) throw _errInvalidKeyShareFormat;

        // Go constructs `elliptic.Curve(groupU16)` unchecked here (no
        // membership test against `elliptic.Curves()`, unlike the
        // HelloRetryRequest branch below) -- preserved faithfully.
        final group = elliptic.Curve(groupU16);
        if (seenGroups.contains(group)) throw _errDuplicateKeyShare;
        seenGroups.add(group);

        shares.add(
          KeyShareEntry(group: group, keyExchange: Uint8List.fromList(raw)),
        );
      }
      clientShares = shares;

      // Consume vector (2 bytes length + vecLen).
      extData.skip(2 + vecLen);
      return;
    }

    // HelloRetryRequest: exactly 2 bytes = selected_group.
    if (extData.remainingLength == 2) {
      final groupU16 = extData.readUint16();
      final group = elliptic.Curve(groupU16);
      if (elliptic.curves().contains(group)) {
        selectedGroup = group;
      }
      return;
    }

    // ServerHello: exactly one KeyShareEntry and no trailing bytes.
    final groupU16 = extData.readUint16();
    final raw = extData.readUint16LengthPrefixed();
    if (!extData.isEmpty || raw.isEmpty) throw _errInvalidKeyShareFormat;
    final group = elliptic.Curve(groupU16);
    serverShare = KeyShareEntry(
      group: group,
      keyExchange: Uint8List.fromList(raw),
    );
  }
}

/// Port of `addKeyShareEntry` (key_share.go:172-178).
void _addKeyShareEntry(_CryptobyteBuilder b, KeyShareEntry e) {
  b.addUint16(e.group.value);
  b.addUint16LengthPrefixed((b) {
    b.addBytes(e.keyExchange);
  });
}

/// hasTooManyContexts is used in Marshal(). It returns whether the KeyShare
/// struct has more than exactly one context.
///
/// Port of `hasTooManyContexts` (key_share.go:181-183).
bool _hasTooManyContexts(bool a, bool b, bool c) =>
    (a && b) || (a && c) || (b && c);
