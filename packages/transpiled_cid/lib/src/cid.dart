// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/cid/cid.dart
import 'dart:typed_data';

// Logical schema fixed_types.Golang.
// ignore: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:crypto/crypto.dart';
import 'package:multibase/multibase.dart' as mb;

import 'package:transpiled_multibase/transpiled_multibase.dart';
import 'package:transpiled_multicodec/transpiled_multicodec.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';
import 'package:transpiled_varint/transpiled_varint.dart';

// Optional textual projection onto the existing int-based registry. The
// original Uint64 remains authoritative even when no native lookup is possible.
String _codecName(Golang.Uint64 code) {
  final exact = code.toBigInt();
  final native = exact.toInt();
  return BigInt.from(native) == exact && Multicodec.supportsByCode(native)
      ? Multicodec.name(native)
      : 'unknown';
}

/// A Content Identifier (Cid) for content-addressed data in IPFS.
///
/// CIDs are self-describing content addresses that combine a cryptographic hash
/// of the content with metadata about the hashing algorithm and data encoding.
///
/// - **CIDv0**: legacy format, always SHA2-256 + DAG-PB, base58btc encoded.
/// - **CIDv1**: modern format with flexible codecs and multibase encoding.
///
/// Example:
/// ```dart
/// final data = Uint8List.fromList(utf8.encode('Hello IPFS'));
/// final cid = await Cid.fromContent(data);
/// print(cid.encode()); // bafkrei...
/// ```

class Cid {
  Uint8List bytes() => toBytes();
  /// Creates a Cid with the specified components.
  Cid({
    required this.version,
    required this.multihash,
    String? codec,
    this.multibaseType,
  }) : codecCode = Golang.Uint64(Multicodec.code(codec ?? 'raw'));

  /// Creates a Cid retaining the numeric codec, including unregistered codes.
  const Cid.numeric({
    required this.version,
    required this.multihash,
    required this.codecCode,
    this.multibaseType,
  });

  /// Creates a CIDv0 from a 32-byte SHA2-256 hash.
  factory Cid.v0(Uint8List hashBytes) {
    if (hashBytes.length != 32) {
      throw ArgumentError('CIDv0 requires a 32-byte SHA2-256 hash');
    }
    return Cid(
      version: 0,
      multihash: MultihashUtils.sha256(hashBytes),
      codec: 'dag-pb',
      multibaseType: mb.Multibase.base58btc,
    );
  }

  /// Creates a CIDv1 from a codec name and a multihash info.
  factory Cid.v1(
    String codec,
    DecodedMultihash multihash, {
    mb.Multibase base = mb.Multibase.base32,
  }) {
    return Cid(
      version: 1,
      codec: codec,
      multihash: multihash,
      multibaseType: base,
    );
  }

  /// Creates a Cid by hashing [data].
  ///
  /// [codec] defaults to `raw` and is ignored when [version] is 0 (always
  /// `dag-pb`, per the CIDv0 spec). [hashType] defaults to `sha2-256`; no
  /// other hash function is currently supported.
  static Future<Cid> fromContent(
    Uint8List data, {
    String codec = 'raw',
    String hashType = 'sha2-256',
    int version = 1,
  }) async {
    if (hashType != 'sha2-256') {
      throw UnsupportedError('Hash type $hashType not supported');
    }
    final digest = Uint8List.fromList(sha256.convert(data).bytes);
    if (version == 0) {
      return Cid.v0(digest);
    }
    final mh = MultihashUtils.sha256(digest);
    return Cid.v1(codec, mh);
  }

  /// Computes a Cid for [data] (async convenience wrapper over
  /// [fromContent], kept for API parity with call sites that expect this
  /// name).
  static Future<Cid> computeForData(Uint8List data, {String format = 'raw'}) {
    return fromContent(data, codec: format);
  }

  /// Computes a Cid for [data] synchronously (SHA2-256, CIDv1 only).
  ///
  /// Prefer [fromContent] when `hashType`/`version` flexibility or async
  /// hashing is needed; this exists for call sites that cannot await.
  static Cid computeForDataSync(Uint8List data, {String codec = 'raw'}) {
    final digest = Uint8List.fromList(sha256.convert(data).bytes);
    final mh = MultihashUtils.sha256(digest);
    return Cid.v1(codec, mh);
  }

  /// Reconstructs a Cid from a [prefix] (version + codec + multihash
  /// function + hash length) and the raw block [data].
  ///
  /// Version, codec, hash function and digest length all come from [prefix].
  /// Used by Bitswap/GraphSync to
  /// let a receiver reconstruct a Cid from [Block.toPrefixBytes] plus the
  /// block bytes.
  static Future<Cid> fromPrefixBytes(Uint8List prefix, Uint8List data) async =>
      Prefix.fromBytes(prefix).sum(data);

  /// Parses a Cid from its raw binary representation.
  static Cid fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) throw ArgumentError('Empty bytes');

    // CIDv0: 34 bytes starting with 0x12 0x20 (sha2-256, 32-byte digest)
    if (bytes.length >= 34 && bytes[0] == 0x12 && bytes[1] == 0x20) {
      return Cid(
        version: 0,
        multihash: MultihashUtils.decode(bytes.sublist(0, 34)),
        codec: 'dag-pb',
        multibaseType: mb.Multibase.base58btc,
      );
    }

    // CIDv1: first byte is 0x01
    if (bytes[0] == 0x01) {
      var index = 1;
      final (codecCode, codecLen) = fromUvarint(
        Uint8List.sublistView(bytes, index),
      );
      index += codecLen;

      final (_, multihashBytes) = mhFromBytes(
        Uint8List.sublistView(bytes, index),
      );
      final mh = MultihashUtils.decode(multihashBytes);

      return Cid.numeric(
        version: 1,
        multihash: mh,
        codecCode: codecCode,
        multibaseType: mb.Multibase.base32,
      );
    }

    throw const FormatException('Invalid Cid version');
  }

  /// Decodes a Cid from its string representation.
  static Cid decode(String cidStr) {
    if (cidStr.isEmpty) {
      throw ArgumentError('Empty Cid string');
    }

    if (cidStr.startsWith('Qm')) {
      // CIDv0 is base58btc without the multibase prefix character.
      final decoded = MultibaseUtils.decode('z$cidStr');
      return fromBytes(decoded);
    }

    final decoded = MultibaseUtils.decode(cidStr);
    return fromBytes(decoded);
  }

  /// The Cid version (0 or 1).
  final int version;

  /// The multihash containing the hash algorithm and digest.
  final DecodedMultihash multihash;

  /// The content codec (e.g., 'dag-pb', 'raw', 'dag-cbor').
  String get codec => _codecName(codecCode);

  /// Canonical numeric codec; names never determine parsed Cid identity.
  final Golang.Uint64 codecCode;

  /// The multibase encoding type for string representation.
  final mb.Multibase? multibaseType;

  /// Encodes the Cid to its string representation.
  String encode() => encodeWithBase(multibaseType);

  /// Encodes the Cid using the requested [base].
  ///
  /// CIDv0 is always returned as base58btc regardless of the requested base.
  /// CIDv1 defaults to base32 when [base] is null.
  String encodeWithBase(mb.Multibase? base) {
    if (version == 0) {
      final mhBytes = multihash.toBytes();
      final encoded = MultibaseUtils.encode(mb.Multibase.base58btc, mhBytes);
      return encoded.substring(1);
    }

    final bytes = toBytes();
    final baseType = base ?? multibaseType ?? mb.Multibase.base32;
    return MultibaseUtils.encode(baseType, bytes);
  }

  /// Encodes the Cid using the base identified by [baseName].
  String encodeWithBaseName(String baseName) {
    final base = _multibaseFromName(baseName);
    return encodeWithBase(base);
  }

  /// Returns the raw binary representation of the Cid.
  Uint8List toBytes() {
    if (version == 0) {
      return multihash.toBytes();
    }

    final builder = BytesBuilder();
    builder.addByte(0x01);
    builder.add(toUvarint(codecCode));
    builder.add(multihash.toBytes());
    return builder.toBytes();
  }

  /// Returns the Cid prefix bytes (version + codec + multihash function + hash
  /// length), omitting the digest itself.
  Uint8List toPrefixBytes() {
    final bytes = toBytes();
    final digestLength = multihash.size;
    if (bytes.length <= digestLength) {
      return bytes;
    }
    return Uint8List.fromList(bytes.sublist(0, bytes.length - digestLength));
  }

  /// This Cid's shape -- version, codec, hash function, and hash length --
  /// without the digest content. Equivalent to go-cid's `Cid.Prefix()`.
  Prefix get prefix => Prefix.numeric(
    version: version,
    codecCode: version == 0 ? Golang.Uint64(0x70) : codecCode,
    mhTypeCode: multihash.code,
    mhLength: multihash.size,
  );

  /// Validates the Cid's structural invariants (version, codec, multihash
  /// size). Does not verify the multihash against any content -- for that,
  /// hash the content and compare, e.g. via [Block.validate] on the
  /// consuming side.
  bool validate() {
    if (version != 0 && version != 1) return false;
    if (version == 0 && codec != 'dag-pb') return false;
    if (multihash.size <= 0) return false;
    return true;
  }

  /// Returns true if this Cid is defined. Equivalent to go-cid's `Cid.Defined()`.
  bool get defined => validate();

  /// Returns the encoded Cid string.
  @override
  String toString() => encode();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cid &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          codecCode == other.codecCode &&
          _bytesEqual(multihash.toBytes(), other.multihash.toBytes());

  @override
  int get hashCode =>
      Object.hash(version, codecCode, Object.hashAll(multihash.toBytes()));

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static mb.Multibase _multibaseFromName(String name) {
    switch (name.toLowerCase()) {
      case 'base16':
      case 'base16lower':
        return mb.Multibase.base16;
      case 'base16upper':
        return mb.Multibase.base16upper;
      case 'base32':
      case 'base32lower':
        return mb.Multibase.base32;
      case 'base32upper':
        return mb.Multibase.base32upper;
      case 'base58':
      case 'base58btc':
        return mb.Multibase.base58btc;
      case 'base64':
        return mb.Multibase.base64;
      case 'base64url':
        return mb.Multibase.base64url;
      case 'base64urlpad':
        return mb.Multibase.base64urlpad;
      default:
        return mb.Multibase.base32;
    }
  }
}

/// A Cid's shape -- version, codec, hash function, and hash length --
/// without any digest content. Lets you describe the kind of Cid to produce
/// once and reuse it to hash many different pieces of data. Equivalent to
/// go-cid's `Prefix` type.
class Prefix {
  /// Creates a prefix.
  Prefix({
    required this.version,
    required String codec,
    required String mhType,
    required this.mhLength,
  }) : codecCode = Golang.Uint64(Multicodec.code(codec)),
       mhTypeCode = Golang.Uint64(Multicodec.code(mhType));

  /// Creates a prefix preserving numeric codec and hash function codes.
  const Prefix.numeric({
    required this.version,
    required this.codecCode,
    required this.mhTypeCode,
    required this.mhLength,
  });

  /// Decodes the four-varint Cid prefix used by Bitswap payload blocks.
  factory Prefix.fromBytes(Uint8List bytes) {
    var offset = 0;
    final (version, versionLength) = fromUvarint(
      Uint8List.sublistView(bytes, offset),
    );
    offset += versionLength;
    final (codecCode, codecLength) = fromUvarint(
      Uint8List.sublistView(bytes, offset),
    );
    offset += codecLength;
    final (mhCode, mhCodeLength) = fromUvarint(
      Uint8List.sublistView(bytes, offset),
    );
    offset += mhCodeLength;
    final (mhLength, lengthLength) = fromUvarint(
      Uint8List.sublistView(bytes, offset),
    );
    offset += lengthLength;
    return Prefix.numeric(
      version: Golang.Int64.fromUint64(version).toIntExact(),
      codecCode: codecCode,
      mhTypeCode: mhCode,
      mhLength: Golang.Int64.fromUint64(mhLength).toIntExact(),
    );
  }

  /// The Cid version (0 or 1).
  final int version;

  /// The content codec (e.g. `dag-pb`, `raw`, `dag-cbor`).
  String get codec => _codecName(codecCode);

  /// Numeric content codec, including unknown registry values.
  final Golang.Uint64 codecCode;

  /// The multihash function name (e.g. `sha2-256`).
  String get mhType => codes[mhTypeCode] ?? '';

  /// Numeric multihash function, including unknown registry values.
  final Golang.Uint64 mhTypeCode;

  /// The digest length in bytes.
  final int mhLength;

  /// Hashes [data] with [mhType] and builds a Cid with this prefix's
  /// [version] and [codec]. Equivalent to go-cid's `Prefix.Sum(data)`.
  Uint8List bytes() {
    final builder = BytesBuilder();
    builder.add(toUvarint(Golang.Uint64(version)));
    builder.add(toUvarint(codecCode));
    builder.add(toUvarint(mhTypeCode));
    builder.add(toUvarint(Golang.Uint64(mhLength)));
    return builder.toBytes();
  }

  Cid sum(Uint8List data) {
    final length = mhTypeCode == Golang.Uint64() ? -1 : mhLength;
    if (version == 0 &&
        (mhTypeCode != Golang.Uint64(0x12) ||
            (mhLength != 32 && mhLength != -1))) {
      throw const FormatException('invalid v0 prefix');
    }
    final full = MultihashUtils.sum(mhType, data);
    if (length > full.digest.length) {
      throw RangeError.range(length, 0, full.digest.length, 'mhLength');
    }
    final mh = length < 0 || length == full.digest.length
        ? full
        : MultihashUtils.encode(
            mhType,
            Uint8List.fromList(full.digest.sublist(0, length)),
          );
    if (version == 0) {
      return Cid.v0(Uint8List.fromList(mh.digest));
    }
    if (version != 1) throw const FormatException('invalid cid version');
    return Cid.numeric(version: 1, codecCode: codecCode, multihash: mh);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Prefix &&
          version == other.version &&
          codecCode == other.codecCode &&
          mhTypeCode == other.mhTypeCode &&
          mhLength == other.mhLength;

  @override
  int get hashCode => Object.hash(version, codecCode, mhTypeCode, mhLength);
}

class InvalidCidException implements Exception {
  final Object? cause;
  const InvalidCidException([this.cause]);
  @override
  String toString() => cause == null ? 'invalid cid' : 'invalid cid: $cause';
}

class CidTooShortException implements Exception {
  const CidTooShortException();
  @override
  String toString() => 'cid too short';
}

class InvalidEncodingException implements Exception {
  final Object? cause;
  const InvalidEncodingException([this.cause]);
  @override
  String toString() => cause == null ? 'invalid base encoding' : 'invalid base encoding: $cause';
}
