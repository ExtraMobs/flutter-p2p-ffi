part of 'extension.dart';

// Port of pkg/protocol/extension/pre_shared_key.go.

const int _minPskBinderSize = 32;

/// PskIdentity represents the PSK identitiy in the "pre_shared_key"
/// extension for DTLS 1.3.
///
/// Port of `PskIdentity` (pre_shared_key.go:26-29).
final class PskIdentity {
  Uint8List identity;
  int obfuscatedTicketAge;

  PskIdentity(this.identity, this.obfuscatedTicketAge);
}

/// PskBinderEntry represents the binder related to a PSK identity in the
/// "pre_shared_key" extension for DTLS 1.3.
///
/// Port of `PskBinderEntry` (pre_shared_key.go:32), a `[]byte` newtype;
/// represented directly as `Uint8List` (a Dart `typedef` shim is vetoed by
/// AGENTS.md, and nothing about this type needs distinct behavior from a
/// plain byte buffer).
typedef PskBinderEntry = Uint8List;

/// PreSharedKey represents the "pre_shared_key" extension for DTLS 1.3. This
/// extension is used in both ClientHello and ServerHello messages, but only
/// the relevant fields should be populated for each context. See RFC 8446
/// section 4.2.11.
/// https://datatracker.ietf.org/doc/html/rfc8446#section-4.2.11
///
/// Port of `PreSharedKey` (pre_shared_key.go:14-21) and its methods
/// `TypeValue`/`Marshal`/`Unmarshal` (pre_shared_key.go:37-141).
final class PreSharedKey implements Extension {
  /// ClientHello only - offered PSK identities.
  List<PskIdentity> identities;

  /// ClientHello only - binder values associated with a PSK identity.
  List<PskBinderEntry> binders;

  /// ServerHello only - index of selected identity.
  int selectedIdentity;

  PreSharedKey({
    List<PskIdentity>? identities,
    List<PskBinderEntry>? binders,
    this.selectedIdentity = 0,
  }) : identities = identities ?? [],
       binders = binders ?? [];

  @override
  TypeValue get typeValue => TypeValue.preSharedKey;

  @override
  Uint8List marshal() {
    final out = _CryptobyteBuilder();
    out.addUint16(typeValue.value);

    // ServerHello.
    if (identities.isEmpty || binders.isEmpty) {
      out.addUint16LengthPrefixed((b) {
        b.addUint16(selectedIdentity);
      });
      return out.toBytes();
    }

    // ClientHello.
    out.addUint16LengthPrefixed((b) {
      b.addUint16LengthPrefixed((b) {
        for (final pskIdentity in identities) {
          if (pskIdentity.identity.isEmpty) throw _errPreSharedKeyFormat;
          b.addUint16LengthPrefixed((b) {
            b.addBytes(pskIdentity.identity);
          });
          b.addUint32(pskIdentity.obfuscatedTicketAge);
        }
      });
      b.addUint16LengthPrefixed((b) {
        for (final binder in binders) {
          if (binder.length < _minPskBinderSize) {
            throw _errPreSharedKeyFormat;
          }
          b.addUint8LengthPrefixed((b) {
            b.addBytes(binder);
          });
        }
      });
    });

    return out.toBytes();
  }

  @override
  void unmarshal(Uint8List data) {
    final val = _CryptobyteReader(data);
    final extension = val.readUint16();
    if (extension != typeValue.value) throw _errInvalidExtensionType;

    final extData = val.readUint16LengthPrefixedReader();

    // ServerHello.
    if (extData.remainingLength == 2) {
      selectedIdentity = extData.readUint16();
      return;
    }

    // ClientHello.
    final identitiesReader = extData.readUint16LengthPrefixedReader();
    if (identitiesReader.isEmpty) throw _errPreSharedKeyFormat;

    identities = [];
    while (!identitiesReader.isEmpty) {
      final identity = identitiesReader.readUint16LengthPrefixed();
      final ticket = identitiesReader.readUint32();
      if (identity.isEmpty) throw _errPreSharedKeyFormat;
      identities.add(PskIdentity(Uint8List.fromList(identity), ticket));
    }

    final bindersReader = extData.readUint16LengthPrefixedReader();
    if (bindersReader.isEmpty) throw _errPreSharedKeyFormat;

    binders = [];
    while (!bindersReader.isEmpty) {
      final binder = bindersReader.readUint8LengthPrefixed();
      if (binder.length < _minPskBinderSize) throw _errPreSharedKeyFormat;
      binders.add(Uint8List.fromList(binder));
    }

    // Ensure there is one binder value per identity in list, and check for
    // trailing bytes.
    if (binders.length != identities.length || !extData.isEmpty) {
      throw _errPreSharedKeyFormat;
    }
  }
}
