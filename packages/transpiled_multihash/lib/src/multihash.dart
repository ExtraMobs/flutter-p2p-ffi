// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/cid/multihash.dart
import 'dart:typed_data';

// Logical schema fixed_types.Golang.
// ignore: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:crypto/crypto.dart' as pkgcrypto;
import 'package:pointycastle/export.dart' as pc;
import 'package:transpiled_varint/transpiled_varint.dart' as varint;
import 'package:convert/convert.dart' as pkgconvert;
import 'package:base_x/base_x.dart' as basex;

class TooShortException implements FormatException {
  const TooShortException([this.message = 'multihash too short. must be >= 2 bytes']);
  @override
  final String message;
  @override
  int? get offset => null;
  @override
  Object? get source => null;
  @override
  String toString() => message;
}

class InconsistentLenException implements FormatException {
  const InconsistentLenException([
    this.expected,
    this.got,
    String? message,
  ]) : message = message ??
            (expected != null && got != null
                ? 'multihash length inconsistent: expected $expected; got $got'
                : 'multihash length inconsistent');

  final int? expected;
  final int? got;

  @override
  final String message;
  @override
  int? get offset => null;
  @override
  Object? get source => null;
  @override
  String toString() => message;
}

extension type const Multihash(Uint8List bytes) {
  String hexString() => pkgconvert.hex.encode(bytes);
  String b58String() => basex.BaseXCodec('123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz').encode(bytes);
}

const int id = 0x00;
const int sha1 = 0x11;
const int sha2_256 = 0x12;
const int sha2_512 = 0x13;
const int sha3_512 = 0x14;
const int sha3_384 = 0x15;
const int sha3_256 = 0x16;
const int sha3_224 = 0x17;
const int shake_128 = 0x18;
const int shake_256 = 0x19;
const int keccak_224 = 0x1a;
const int keccak_256 = 0x1b;
const int keccak_384 = 0x1c;
const int keccak_512 = 0x1d;
const int blake3 = 0x1e;
const int murmur3_x64_64 = 0x22;
const int dbl_sha2_256 = 0x56;
const int md5 = 0xd5;

Uint8List sum(Uint8List data, Golang.Uint64 code, [int length = -1]) {
  final name = codes[code] ?? '';
  if (name.isEmpty) throw UnsupportedError('Hash function not supported: $code');
  final fullDigest = MultihashUtils._digestFor(name, data);
  var digest = fullDigest;
  if (length >= 0) {
    if (length > fullDigest.length) {
      throw ArgumentError('requested length was too large for digest');
    }
    digest = Uint8List.fromList(fullDigest.sublist(0, length));
  }
  return encode(digest, code);
}


/// Helpers for computing and decoding multihashes.
///
/// Compatibility helpers for existing Dart consumers of the Go primitives.
class MultihashUtils {
  // Private constructor to prevent instantiation.
  MultihashUtils._();

  /// Encodes [hash] with the SHA2-256 multihash function.
  static DecodedMultihash sha256(Uint8List hash) {
    if (hash.length != 32) {
      throw ArgumentError('SHA2-256 digest must be 32 bytes');
    }
    return encode('sha2-256', hash);
  }

  /// Encodes raw [hash] bytes with the named multihash function.
  ///
  /// Supported names include `sha2-256`, `sha2-512`, `blake2b-256`, etc.
  static DecodedMultihash encode(String name, Uint8List hash) =>
      decode(encodeName(hash, name));

  /// Decodes a multihash byte array.
  static DecodedMultihash decode(Uint8List bytes) => _decode(bytes);

  /// Computes the digest of [data] using the named hash function and wraps
  /// it as a multihash -- the Dart equivalent of go-multihash's
  /// `multihash.Sum(data, code, length)`.
  ///
  /// Supported names: `identity`, `sha1`, `md5`, `sha2-256`, `sha2-512`,
  /// `dbl-sha2-256`, `sha3-224/256/384/512`, `keccak-224/256/384/512`.
  /// BLAKE2b/BLAKE2s, BLAKE3, SHAKE, and MURMUR3 are not yet implemented --
  /// low priority for content-addressing, where SHA2-256 dominates in
  /// practice (see doc/transpilation/PROGRESS.md, go-multihash row).
  static DecodedMultihash sum(String name, Uint8List data) {
    final digest = _digestFor(name, data);
    return encode(name, digest);
  }

  static Uint8List _digestFor(String name, Uint8List data) {
    switch (name) {
      case 'identity':
        return data;
      case 'sha1':
        return Uint8List.fromList(pkgcrypto.sha1.convert(data).bytes);
      case 'md5':
        return Uint8List.fromList(pkgcrypto.md5.convert(data).bytes);
      case 'sha2-256':
        return Uint8List.fromList(pkgcrypto.sha256.convert(data).bytes);
      case 'sha2-512':
        return Uint8List.fromList(pkgcrypto.sha512.convert(data).bytes);
      case 'dbl-sha2-256':
        final once = pkgcrypto.sha256.convert(data).bytes;
        return Uint8List.fromList(pkgcrypto.sha256.convert(once).bytes);
      case 'sha3-224':
        return pc.SHA3Digest(224).process(data);
      case 'sha3-256':
        return pc.SHA3Digest(256).process(data);
      case 'sha3-384':
        return pc.SHA3Digest(384).process(data);
      case 'sha3-512':
        return pc.SHA3Digest(512).process(data);
      case 'keccak-224':
        return pc.KeccakDigest(224).process(data);
      case 'keccak-256':
        return pc.KeccakDigest(256).process(data);
      case 'keccak-384':
        return pc.KeccakDigest(384).process(data);
      case 'keccak-512':
        return pc.KeccakDigest(512).process(data);
      default:
        throw UnsupportedError('Hash function not supported: $name');
    }
  }
}

/// Go DecodedMultihash; code retains its uint64 domain on every runtime.
class DecodedMultihash {
  /// Creates the decoded fields, preserving the digest slice.
  const DecodedMultihash({
    required this.code,
    required this.name,
    required this.length,
    required this.digest,
  });

  /// Numeric hash function code, including unregistered codes.
  final Golang.Uint64 code;

  /// Registered name, or the empty string for unknown codes.
  final String name;

  /// Advertised digest length in bytes.
  final int length;

  /// Digest slice; decoded values alias the input buffer.
  final Uint8List digest;

  /// Compatibility spelling for existing Dart consumers.
  int get size => length;

  /// Re-encodes the digest; Go Encode derives length from the digest itself.
  Uint8List toBytes() => encode(digest, code);
}

/// Go Encode: accepts any uint64 code and derives length from the digest.
Uint8List encode(Uint8List digest, Golang.Uint64 code) {
  final length = Golang.Uint64(digest.length);
  final bytes = Uint8List(
    varint.uvarintSize(code) + varint.uvarintSize(length) + digest.length,
  );
  var written = varint.putUvarint(bytes, code);
  written += varint.putUvarint(Uint8List.sublistView(bytes, written), length);
  bytes.setRange(written, bytes.length, digest);
  return bytes;
}

/// Go EncodeName: missing map entries have the uint64 zero value (identity).
Uint8List encodeName(Uint8List digest, String name) =>
    encode(digest, names[name] ?? Golang.Uint64());

/// Go Names, including the deprecated sha3 alias and Blake2 init entries.
final Map<String, Golang.Uint64> names = {
  for (final entry in codes.entries) entry.value: entry.key,
  'sha3': Golang.Uint64(0x14),
};


/// Go Decode: parses exactly one multihash, rejecting trailing bytes.
DecodedMultihash decode(Uint8List bytes) => _decode(bytes);

DecodedMultihash _decode(Uint8List bytes) {
  final (consumed, code, digest) = _readMultihashFromBuf(bytes);
  final decoded = DecodedMultihash(
    code: code,
    name: codes[code] ?? '',
    digest: digest,
    length: digest.length,
  );
  if (consumed != bytes.length) {
    throw InconsistentLenException(decoded.length, consumed);
  }
  return decoded;
}

/// Go Cast: validates through Decode and returns the original byte slice.
Uint8List cast(Uint8List bytes) {
  decode(bytes);
  return bytes;
}

/// Go MHFromBytes: consumes one multihash, leaving any trailing bytes unread.
/// The returned multihash is a view over the input, as in the Go byte slice.
(int, Uint8List) mhFromBytes(Uint8List bytes) {
  final (consumed, _, _) = _readMultihashFromBuf(bytes);
  return (consumed, Uint8List.sublistView(bytes, 0, consumed));
}

/// Go Codes, including entries installed by init. Unknown codes remain valid.
final Map<Golang.Uint64, String> codes = <int, String>{
  0: 'identity',
  0x11: 'sha1',
  0x12: 'sha2-256',
  0x13: 'sha2-512',
  0x14: 'sha3-512',
  0x15: 'sha3-384',
  0x16: 'sha3-256',
  0x17: 'sha3-224',
  0x18: 'shake-128',
  0x19: 'shake-256',
  0x1a: 'keccak-224',
  0x1b: 'keccak-256',
  0x1c: 'keccak-384',
  0x1d: 'keccak-512',
  0x1e: 'blake3',
  0x22: 'murmur3-x64-64',
  0x56: 'dbl-sha2-256',
  0xd5: 'md5',
  0x1012: 'sha2-256-trunc254-padded',
  0x1100: 'x11',
  0xb401: 'poseidon-bls12_381-a2-fc1',
  for (var c = 0xb201; c <= 0xb240; c++) c: 'blake2b-${(c - 0xb201 + 1) * 8}',
  for (var c = 0xb241; c <= 0xb260; c++) c: 'blake2s-${(c - 0xb241 + 1) * 8}',
}.map((code, name) => MapEntry(Golang.Uint64(code), name));

/// Port of readMultihashFromBuf; digest aliases the caller's byte buffer.
(int, Golang.Uint64, Uint8List) _readMultihashFromBuf(Uint8List bytes) {
  if (bytes.length < 2) {
    throw const TooShortException();
  }
  final (code, codeSize) = varint.fromUvarint(bytes);
  final (length, lengthSize) = varint.fromUvarint(
    Uint8List.sublistView(bytes, codeSize),
  );
  if (length > Golang.Uint64(0x7fffffff)) {
    throw const FormatException('digest too long, supporting only <= 2^31-1');
  }
  final start = codeSize + lengthSize;
  if (length > Golang.Uint64(bytes.length - start)) {
    throw const FormatException(
      'length greater than remaining number of bytes in buffer',
    );
  }
  final size = length
      .toBigInt()
      .toInt(); // Bounded by MaxInt32 and input above.
  return (
    start + size,
    code,
    Uint8List.sublistView(bytes, start, start + size),
  );
}
