// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/pubkey_validator.dart
//
// Port of go-libp2p-record's pubkey.go: a Validator for the DHT's `/pk/
// <peer-id-multihash>` namespace, which stores a peer's public key keyed
// by the peer ID (multihash) it derives.
import 'dart:typed_data';

import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

import 'util.dart';
import 'validator.dart';

/// Validates that a `/pk/<peer-id>` record's value is the public key that
/// derives the peer ID in the key. Equivalent to go-libp2p-record's
/// `PublicKeyValidator`.
class PublicKeyValidator implements Validator {
  /// Creates the validator.
  const PublicKeyValidator();

  @override
  void validate(String key, Uint8List value) {
    final (namespace, path) = splitKey(key);
    if (namespace != 'pk') {
      throw ArgumentError("namespace not 'pk'");
    }

    final keyHash = Uint8List.fromList(path.codeUnits);
    MultihashUtils.decode(keyHash); // throws if not a valid multihash

    final publicKey = unmarshalPublicKey(value);
    final id = PeerId.fromPubKey(publicKey);
    if (!_bytesEqual(keyHash, id.value)) {
      throw ArgumentError('public key does not match storage key');
    }
  }

  @override
  int select(String key, List<Uint8List> values) => 0;
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
