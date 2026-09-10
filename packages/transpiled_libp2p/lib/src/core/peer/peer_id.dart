// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/core/peer/peer_id.dart
//
// Port of go-libp2p's core/peer (peer.go): a peer ID is a multihash of a
// peer's public key -- `identity` (the hash IS the marshaled protobuf
// PublicKey message) when that message is short enough, `sha2-256`
// otherwise.
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:transpiled_base58/transpiled_base58.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_multibase/transpiled_multibase.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

import '../crypto/key_codec.dart';
import '../crypto/key_types.dart';

/// Thrown by [PeerId.validate] for the empty peer ID. Equivalent to
/// go-libp2p's `ErrEmptyPeerID`.
class EmptyPeerIdException implements Exception {
  /// Creates the exception.
  const EmptyPeerIdException();
  @override
  String toString() => 'empty peer ID';
}

/// Thrown by [PeerId.extractPublicKey] when the peer ID isn't an `identity`
/// multihash of a public key. Equivalent to go-libp2p's `ErrNoPublicKey`.
class NoPublicKeyException implements Exception {
  /// Creates the exception.
  const NoPublicKeyException();
  @override
  String toString() => 'public key is not embedded in peer ID';
}

/// Thrown when a multiaddr/Cid doesn't encode a valid peer ID. Equivalent
/// to go-libp2p's `ErrInvalidAddr` (multiaddr context) and the `FromCid`
/// wrong-codec error.
class InvalidPeerIdSourceException implements Exception {
  /// Creates the exception, optionally with a specific [message].
  const InvalidPeerIdSourceException([this.message = 'invalid p2p multiaddr']);

  /// The exception's message.
  final String message;
  @override
  String toString() => message;
}

/// A peer ID's public key is inline-hashed (multihash `identity`, i.e. the
/// hash IS the marshaled key) rather than SHA2-256-hashed when the
/// marshaled protobuf `PublicKey` message is this short or shorter -- see
/// go-libp2p core/peer's `maxInlineKeyLength`. Ed25519 keys are always
/// under this threshold (36 marshaled bytes); RSA keys never are.
const int _maxInlineKeyLength = 42;

/// Represents a peer identifier in the IPFS network. Equivalent to
/// go-libp2p core/peer's `ID` (a multihash of the peer's public key).
class PeerId implements Comparable<PeerId> {
  /// Creates a PeerId from raw bytes.
  PeerId({required this.value});

  /// Casts [bytes] to a [PeerId], validating that they're a well-formed
  /// multihash. Equivalent to go-libp2p's `IDFromBytes`.
  factory PeerId.fromBytes(Uint8List bytes) {
    MultihashUtils.decode(bytes); // throws if not a valid multihash
    return PeerId(value: bytes);
  }

  /// Creates a PeerId from a Base58-encoded string.
  factory PeerId.fromBase58(String base58) {
    return PeerId(value: Base58().base58Decode(base58));
  }

  /// Creates a PeerId from a base36-encoded string.
  ///
  /// Accepts both the bare base36 string and the multibase-prefixed form
  /// starting with `k` (the base36 multibase prefix).
  factory PeerId.fromBase36(String base36) {
    if (base36.isEmpty) {
      throw ArgumentError('Empty base36 string');
    }
    final prefixed = base36[0] == 'k' ? base36 : 'k$base36';
    return PeerId(value: MultibaseUtils.decode(prefixed));
  }

  /// Decodes an encoded peer ID, accepting either the legacy base58
  /// (`Qm...`/`1...`) multihash form or a Cid string (of type
  /// `libp2p-key`). Equivalent to go-libp2p's `Decode`.
  factory PeerId.decode(String s) {
    if (s.startsWith('Qm') || s.startsWith('1')) {
      final bytes = Base58().base58Decode(s);
      MultihashUtils.decode(bytes); // throws if not a valid multihash
      return PeerId(value: bytes);
    }
    return PeerId.fromCid(Cid.decode(s));
  }

  /// Converts a `libp2p-key`-codec Cid to a peer ID. Equivalent to
  /// go-libp2p's `FromCid`.
  factory PeerId.fromCid(Cid cid) {
    if (cid.codec != 'libp2p-key') {
      throw InvalidPeerIdSourceException(
        'can\'t convert Cid of type "${cid.codec}" to a peer ID',
      );
    }
    return PeerId(value: Uint8List.fromList(cid.multihash.toBytes()));
  }

  /// Creates a PeerId from a raw public key, per go-libp2p core/peer's
  /// `IDFromPublicKey`: the key is wrapped in a protobuf `PublicKey{Type,
  /// Data}` message (crypto.proto), then that message is hashed as a
  /// multihash -- `identity` (the hash IS the marshaled message) when the
  /// message is [_maxInlineKeyLength] bytes or shorter, `sha2-256`
  /// otherwise. Ed25519 keys (36 marshaled bytes) always take the inline
  /// path, producing the well-known `12D3Koo...` peer ID family; RSA and
  /// other larger keys always hash, producing the `Qm...` family.
  ///
  /// [type] names the key algorithm: `'Ed25519'`, `'RSA'`, `'Secp256k1'`,
  /// or `'ECDSA'` (case-insensitive). [publicKey] must be exactly 32 bytes
  /// for Ed25519 -- the other algorithms don't have a fixed raw-key length
  /// enforced here.
  factory PeerId.fromPublicKey(Uint8List publicKey, {required String type}) {
    final keyType = switch (type.toLowerCase()) {
      'ed25519' => KeyType.ed25519,
      'rsa' => KeyType.rsa,
      'secp256k1' => KeyType.secp256k1,
      'ecdsa' => KeyType.ecdsa,
      _ => throw UnsupportedError('Unknown public key type: $type'),
    };
    if (keyType == KeyType.ed25519 && publicKey.length != 32) {
      throw ArgumentError(
        'Ed25519 public key must be 32 bytes, got ${publicKey.length}',
      );
    }

    final marshaled = marshalKeyProto(keyType, publicKey);
    return PeerId(value: _sumFromMarshaledKey(marshaled));
  }

  /// Creates a PeerId from a [PubKey] object, per go-libp2p's
  /// `IDFromPublicKey`. Prefer this over [PeerId.fromPublicKey] when a
  /// concrete key object (not just raw bytes) is available.
  factory PeerId.fromPubKey(PubKey pk) {
    return PeerId(value: _sumFromMarshaledKey(marshalPublicKey(pk)));
  }

  /// Creates a PeerId from a [PrivKey]'s public half. Equivalent to
  /// go-libp2p's `IDFromPrivateKey`.
  factory PeerId.fromPrivateKey(PrivKey sk) => PeerId.fromPubKey(sk.getPublic());

  static Uint8List _sumFromMarshaledKey(Uint8List marshaled) {
    final alg = marshaled.length <= _maxInlineKeyLength
        ? 'identity'
        : 'sha2-256';
    return Uint8List.fromList(MultihashUtils.sum(alg, marshaled).toBytes());
  }

  /// The raw bytes of the peer ID.
  final Uint8List value;

  /// Whether this is the empty peer ID.
  bool get isEmpty => value.isEmpty;

  /// Throws [EmptyPeerIdException] if this is the empty peer ID. Equivalent
  /// to go-libp2p's `ID.Validate`.
  void validate() {
    if (isEmpty) throw const EmptyPeerIdException();
  }

  /// Converts the peer ID to a Base58-encoded string.
  String toBase58() {
    return Base58().encode(value);
  }

  /// Converts the peer ID to a multibase-prefixed base36-encoded string.
  ///
  /// The returned string starts with `k`, the base36 multibase prefix, e.g.
  /// `k51qzi5uqu5...`.
  String toBase36() {
    return MultibaseUtils.encodeWithName('base36', value);
  }

  /// A short, human-readable form for logging, e.g. `<peer.ID 12*3nFXfB>`.
  /// Equivalent to go-libp2p's `ID.ShortString`.
  String shortString() {
    final pid = toBase58();
    if (pid.length <= 10) return '<peer.ID $pid>';
    return '<peer.ID ${pid.substring(0, 2)}*${pid.substring(pid.length - 6)}>';
  }

  /// Encodes this peer ID as a `libp2p-key`-codec Cid (multibase base32).
  /// Equivalent to go-libp2p's `ToCid`.
  ///
  /// Unlike Go, which returns a zero-value (undefined) `cid.Cid` for the
  /// empty peer ID rather than an error, this throws -- this codebase's
  /// `Cid` type has no zero-value sentinel by design (see
  /// doc/transpilation/PROGRESS.md's go-cid row).
  Cid toCid() {
    final mh = MultihashUtils.decode(value);
    return Cid.v1('libp2p-key', mh);
  }

  /// Whether this ID was derived from public key [pk]. Equivalent to
  /// go-libp2p's `ID.MatchesPublicKey`.
  bool matchesPublicKey(PubKey pk) {
    try {
      return PeerId.fromPubKey(pk) == this;
    } catch (_) {
      return false;
    }
  }

  /// Whether this ID was derived from private key [sk]. Equivalent to
  /// go-libp2p's `ID.MatchesPrivateKey`.
  bool matchesPrivateKey(PrivKey sk) => matchesPublicKey(sk.getPublic());

  /// Attempts to extract the embedded public key from this ID -- only
  /// possible when the ID is an `identity` multihash (i.e. the hash itself
  /// IS the marshaled key, the case for Ed25519 and other short keys).
  /// Throws [NoPublicKeyException] otherwise. Equivalent to go-libp2p's
  /// `ID.ExtractPublicKey`.
  PubKey extractPublicKey() {
    final decoded = MultihashUtils.decode(value);
    if (decoded.code.toBigInt() != BigInt.zero) {
      // 0x00 == multihash `identity`.
      throw const NoPublicKeyException();
    }
    return unmarshalPublicKey(Uint8List.fromList(decoded.digest));
  }

  /// The raw bytes of the peer ID (`MarshalBinary`/`Marshal`).
  Uint8List marshalBinary() => value;

  /// Restores a [PeerId] from [marshalBinary]'s output.
  static PeerId unmarshalBinary(Uint8List data) => PeerId.fromBytes(data);

  /// The base58 text form of the peer ID (`MarshalText`).
  String marshalText() => toBase58();

  /// Restores a [PeerId] from [marshalText]'s output (or any [PeerId.decode]
  /// -accepted string).
  static PeerId unmarshalText(String data) => PeerId.decode(data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeerId &&
          runtimeType == other.runtimeType &&
          _listsEqual(value, other.value);

  @override
  int get hashCode => _listHashCode(value);

  @override
  String toString() => toBase58();

  /// Bytewise comparison of the raw peer ID bytes, matching go-libp2p's
  /// `IDSlice` sort order (`string(es[i]) < string(es[j])`, a Go string
  /// being its raw bytes).
  @override
  int compareTo(PeerId other) {
    final a = value, b = other.value;
    final n = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }

  /// Checks if this PeerId satisfies a static Proof-of-Work condition (SEC-005).
  ///
  /// The condition is that the SHA-256 hash of the PeerId must have at least
  /// [difficulty] leading zero bits.
  bool verifyPoW({int difficulty = 8}) {
    if (difficulty <= 0) return true;

    // Hash the PeerId bytes
    final hash = _sha256(value);

    // Check leading zero bits
    int leadingZeros = 0;
    for (final byte in hash) {
      if (byte == 0) {
        leadingZeros += 8;
      } else {
        // Count bits in the first non-zero byte
        var b = byte;
        for (int i = 7; i >= 0; i--) {
          if ((b & (1 << i)) == 0) {
            leadingZeros++;
          } else {
            break;
          }
        }
        break;
      }
      if (leadingZeros >= difficulty) break;
    }

    return leadingZeros >= difficulty;
  }

  static Uint8List _sha256(Uint8List data) {
    return Uint8List.fromList(crypto.sha256.convert(data).bytes);
  }
}

/// Converts a peer ID to a `libp2p-key`-codec Cid. Equivalent to
/// go-libp2p's package-level `ToCid` function (kept alongside [PeerId.toCid]
/// for call sites that prefer the free-function form).
Cid peerIdToCid(PeerId id) => id.toCid();

/// Converts a `libp2p-key`-codec Cid to a peer ID. Equivalent to
/// go-libp2p's package-level `FromCid` function (kept alongside
/// [PeerId.fromCid] for call sites that prefer the free-function form).
PeerId peerIdFromCid(Cid cid) => PeerId.fromCid(cid);

bool _listsEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _listHashCode(List<int> list) {
  return list.fold(0, (prev, element) => prev ^ element.hashCode);
}
