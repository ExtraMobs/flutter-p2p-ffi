part of 'qpack_impl.dart';

// Port of golang.org/x/net/http2/hpack (module golang.org/x/net v0.28.0,
// commit 4542a42604cd159f1adb93c58368079ae37b3bf6): huffman.go, plus the
// `huffmanCodes`/`huffmanCodeLen` tables from tables.go.
//
// MODULE BOUNDARY NOTE FOR THE MAINTAINER: golang.org/x/net is a different
// go.mod than github.com/quic-go/qpack. AGENTS.md's module-boundary rule
// would normally put this in its own
// `packages/transpiled_golang_x_net_http2_hpack/` package. It is embedded
// here as a private part of this library instead, because the task that
// produced this file scoped all changes to `packages/transpiled_qpack/**`
// only. Flagging this so the boundary can be revisited/extracted later if
// wanted -- deliberately not decided unilaterally here.
//
// Only the Huffman codec is ported: `HuffmanDecodeToString`,
// `AppendHuffmanString`, `HuffmanEncodeLength`, and their private
// tree/table support. That is the only part of hpack that qpack's
// encoder.go/decoder.go call (via `hpack.HuffmanEncodeLength`,
// `hpack.AppendHuffmanString`, `hpack.HuffmanDecodeToString`). Go's
// `HuffmanDecode(w io.Writer, v []byte)` variant is NOT ported: qpack never
// calls it, and porting it would require an io.Writer-shaped abstraction in
// a package that is deliberately kept free of `dart:io` for Web/Wasm
// compatibility (this is a pure codec package). The rest of
// golang.org/x/net/http2/hpack (the dynamic HPACK table, hpack.Encoder,
// hpack.Decoder) is unrelated to QPACK -- QPACK has no dynamic table
// support in this port, matching upstream qpack -- and out of scope.

/// Huffman codes table (`huffmanCodes` in tables.go), index = symbol byte
/// value, transcribed verbatim from upstream, entry by entry.
const List<int> _huffmanCodes = <int>[
  0x1ff8,
  0x7fffd8,
  0xfffffe2,
  0xfffffe3,
  0xfffffe4,
  0xfffffe5,
  0xfffffe6,
  0xfffffe7,
  0xfffffe8,
  0xffffea,
  0x3ffffffc,
  0xfffffe9,
  0xfffffea,
  0x3ffffffd,
  0xfffffeb,
  0xfffffec,
  0xfffffed,
  0xfffffee,
  0xfffffef,
  0xffffff0,
  0xffffff1,
  0xffffff2,
  0x3ffffffe,
  0xffffff3,
  0xffffff4,
  0xffffff5,
  0xffffff6,
  0xffffff7,
  0xffffff8,
  0xffffff9,
  0xffffffa,
  0xffffffb,
  0x14,
  0x3f8,
  0x3f9,
  0xffa,
  0x1ff9,
  0x15,
  0xf8,
  0x7fa,
  0x3fa,
  0x3fb,
  0xf9,
  0x7fb,
  0xfa,
  0x16,
  0x17,
  0x18,
  0x0,
  0x1,
  0x2,
  0x19,
  0x1a,
  0x1b,
  0x1c,
  0x1d,
  0x1e,
  0x1f,
  0x5c,
  0xfb,
  0x7ffc,
  0x20,
  0xffb,
  0x3fc,
  0x1ffa,
  0x21,
  0x5d,
  0x5e,
  0x5f,
  0x60,
  0x61,
  0x62,
  0x63,
  0x64,
  0x65,
  0x66,
  0x67,
  0x68,
  0x69,
  0x6a,
  0x6b,
  0x6c,
  0x6d,
  0x6e,
  0x6f,
  0x70,
  0x71,
  0x72,
  0xfc,
  0x73,
  0xfd,
  0x1ffb,
  0x7fff0,
  0x1ffc,
  0x3ffc,
  0x22,
  0x7ffd,
  0x3,
  0x23,
  0x4,
  0x24,
  0x5,
  0x25,
  0x26,
  0x27,
  0x6,
  0x74,
  0x75,
  0x28,
  0x29,
  0x2a,
  0x7,
  0x2b,
  0x76,
  0x2c,
  0x8,
  0x9,
  0x2d,
  0x77,
  0x78,
  0x79,
  0x7a,
  0x7b,
  0x7ffe,
  0x7fc,
  0x3ffd,
  0x1ffd,
  0xffffffc,
  0xfffe6,
  0x3fffd2,
  0xfffe7,
  0xfffe8,
  0x3fffd3,
  0x3fffd4,
  0x3fffd5,
  0x7fffd9,
  0x3fffd6,
  0x7fffda,
  0x7fffdb,
  0x7fffdc,
  0x7fffdd,
  0x7fffde,
  0xffffeb,
  0x7fffdf,
  0xffffec,
  0xffffed,
  0x3fffd7,
  0x7fffe0,
  0xffffee,
  0x7fffe1,
  0x7fffe2,
  0x7fffe3,
  0x7fffe4,
  0x1fffdc,
  0x3fffd8,
  0x7fffe5,
  0x3fffd9,
  0x7fffe6,
  0x7fffe7,
  0xffffef,
  0x3fffda,
  0x1fffdd,
  0xfffe9,
  0x3fffdb,
  0x3fffdc,
  0x7fffe8,
  0x7fffe9,
  0x1fffde,
  0x7fffea,
  0x3fffdd,
  0x3fffde,
  0xfffff0,
  0x1fffdf,
  0x3fffdf,
  0x7fffeb,
  0x7fffec,
  0x1fffe0,
  0x1fffe1,
  0x3fffe0,
  0x1fffe2,
  0x7fffed,
  0x3fffe1,
  0x7fffee,
  0x7fffef,
  0xfffea,
  0x3fffe2,
  0x3fffe3,
  0x3fffe4,
  0x7ffff0,
  0x3fffe5,
  0x3fffe6,
  0x7ffff1,
  0x3ffffe0,
  0x3ffffe1,
  0xfffeb,
  0x7fff1,
  0x3fffe7,
  0x7ffff2,
  0x3fffe8,
  0x1ffffec,
  0x3ffffe2,
  0x3ffffe3,
  0x3ffffe4,
  0x7ffffde,
  0x7ffffdf,
  0x3ffffe5,
  0xfffff1,
  0x1ffffed,
  0x7fff2,
  0x1fffe3,
  0x3ffffe6,
  0x7ffffe0,
  0x7ffffe1,
  0x3ffffe7,
  0x7ffffe2,
  0xfffff2,
  0x1fffe4,
  0x1fffe5,
  0x3ffffe8,
  0x3ffffe9,
  0xffffffd,
  0x7ffffe3,
  0x7ffffe4,
  0x7ffffe5,
  0xfffec,
  0xfffff3,
  0xfffed,
  0x1fffe6,
  0x3fffe9,
  0x1fffe7,
  0x1fffe8,
  0x7ffff3,
  0x3fffea,
  0x3fffeb,
  0x1ffffee,
  0x1ffffef,
  0xfffff4,
  0xfffff5,
  0x3ffffea,
  0x7ffff4,
  0x3ffffeb,
  0x7ffffe6,
  0x3ffffec,
  0x3ffffed,
  0x7ffffe7,
  0x7ffffe8,
  0x7ffffe9,
  0x7ffffea,
  0x7ffffeb,
  0xffffffe,
  0x7ffffec,
  0x7ffffed,
  0x7ffffee,
  0x7ffffef,
  0x7fffff0,
  0x3ffffee,
];

/// Huffman code lengths table (`huffmanCodeLen` in tables.go), index =
/// symbol byte value, transcribed verbatim from upstream, row by row (16
/// entries per row, matching the upstream layout).
const List<int> _huffmanCodeLen = <int>[
  13, 23, 28, 28, 28, 28, 28, 28, 28, 24, 30, 28, 28, 30, 28, 28, //
  28, 28, 28, 28, 28, 28, 30, 28, 28, 28, 28, 28, 28, 28, 28, 28, //
  6, 10, 10, 12, 13, 6, 8, 11, 10, 10, 8, 11, 8, 6, 6, 6, //
  5, 5, 5, 6, 6, 6, 6, 6, 6, 6, 7, 8, 15, 6, 12, 10, //
  13, 6, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, //
  7, 7, 7, 7, 7, 7, 7, 7, 8, 7, 8, 13, 19, 13, 14, 6, //
  15, 5, 6, 5, 6, 5, 6, 6, 6, 5, 7, 7, 6, 6, 6, 5, //
  6, 7, 6, 5, 5, 6, 7, 7, 7, 7, 7, 15, 11, 14, 13, 28, //
  20, 22, 20, 20, 22, 22, 22, 23, 22, 23, 23, 23, 23, 23, 24, 23, //
  24, 24, 22, 23, 24, 23, 23, 23, 23, 21, 22, 23, 22, 23, 23, 24, //
  22, 21, 20, 22, 22, 23, 23, 21, 23, 22, 22, 24, 21, 22, 23, 23, //
  21, 21, 22, 21, 23, 22, 23, 23, 20, 22, 22, 22, 23, 22, 22, 23, //
  26, 26, 20, 19, 22, 23, 22, 25, 26, 26, 26, 27, 27, 26, 24, 25, //
  19, 21, 26, 27, 27, 26, 27, 24, 21, 21, 26, 26, 28, 27, 27, 27, //
  20, 24, 20, 21, 22, 21, 21, 23, 22, 22, 25, 25, 24, 24, 26, 23, //
  26, 27, 26, 26, 27, 27, 27, 27, 27, 28, 27, 27, 27, 27, 27, 26, //
];

/// Error message reproduced verbatim from Go's `hpack.ErrInvalidHuffman`.
const String _invalidHuffmanMessage = 'hpack: invalid Huffman-encoded data';

/// Port of Go's unexported `node` type: a Huffman decode trie node.
/// `children` is non-null only for internal nodes; `codeLen`/`sym` are only
/// meaningful for leaves (`children == null`).
class _HuffmanNode {
  _HuffmanNode.internal()
    : children = List<_HuffmanNode?>.filled(256, null),
      codeLen = 0,
      sym = 0;

  _HuffmanNode.leaf(this.sym, this.codeLen) : children = null;

  final List<_HuffmanNode?>? children;
  final int codeLen;
  final int sym;
}

_HuffmanNode? _lazyRootHuffmanNode;

/// Port of `getRootHuffmanNode`. Go guards the one-time build with
/// `sync.Once` for concurrent goroutines; Dart isolates are single-threaded,
/// so a plain lazy-initialized private variable reproduces the same
/// "build once, reuse forever" behavior without an artificial concurrency
/// primitive.
_HuffmanNode _getRootHuffmanNode() =>
    _lazyRootHuffmanNode ??= _buildRootHuffmanNode();

/// Port of `buildRootHuffmanNode`.
_HuffmanNode _buildRootHuffmanNode() {
  if (_huffmanCodes.length != 256) {
    throw StateError('unexpected size');
  }
  final root = _HuffmanNode.internal();

  for (var sym = 0; sym < 256; sym++) {
    final code = _huffmanCodes[sym];
    var codeLen = _huffmanCodeLen[sym];

    var cur = root;
    while (codeLen > 8) {
      codeLen -= 8;
      final i = (code >> codeLen) & 0xff;
      cur.children![i] ??= _HuffmanNode.internal();
      cur = cur.children![i]!;
    }
    final shift = 8 - codeLen;
    final start = (code << shift) & 0xff;
    final end = 1 << shift;

    final leaf = _HuffmanNode.leaf(sym, codeLen);
    for (var i = start; i < start + end; i++) {
      cur.children![i] = leaf;
    }
  }
  return root;
}

/// Port of `huffmanDecode`/`HuffmanDecodeToString` (qpack only ever calls
/// the to-string form, so that's the only entry point kept public within
/// this library).
///
/// Decodes the Huffman-encoded bytes in [v] to a string. Throws
/// [FormatException] (mirroring `hpack.ErrInvalidHuffman`) on malformed
/// input: an unknown code, an incomplete trailing symbol, or padding bits
/// that are not a prefix of the EOS code, per RFC 7541 section 5.2.
///
/// Implementation note: Go's `cur` bit-accumulator is a fixed-width `uint`
/// that a long input would keep left-shifting past its bit width forever,
/// relying on machine-width wraparound to discard bits that are no longer
/// read. The decode loop never inspects more than the low ~15 bits of `cur`
/// at any point (the inner `while (cbits >= 8)` loop always leaves
/// `cbits < 8` before the next byte is folded in, and no single symbol is
/// longer than [_huffmanCodeLen]'s maximum of 30 bits split across 8-bit
/// tree levels). Masking `cur` to 16 bits after every update keeps only
/// those bits, is exactly equivalent for every value ever read, and avoids
/// depending on Dart `int` overflow semantics that differ between the
/// native VM (64-bit wraparound) and Web compilation targets.
String _huffmanDecodeToString(List<int> v) {
  final root = _getRootHuffmanNode();
  var n = root;
  final out = <int>[];
  var cur = 0;
  var cbits = 0;
  var sbits = 0;

  for (final b in v) {
    cur = ((cur << 8) | (b & 0xff)) & 0xffff;
    cbits += 8;
    sbits += 8;
    while (cbits >= 8) {
      final idx = (cur >> (cbits - 8)) & 0xff;
      final next = n.children?[idx];
      if (next == null) {
        throw const FormatException(_invalidHuffmanMessage);
      }
      n = next;
      if (n.children == null) {
        out.add(n.sym);
        cbits -= n.codeLen;
        n = root;
        sbits = cbits;
      } else {
        cbits -= 8;
      }
    }
  }
  while (cbits > 0) {
    final idx = (cur << (8 - cbits)) & 0xff;
    final next = n.children?[idx];
    if (next == null) {
      throw const FormatException(_invalidHuffmanMessage);
    }
    n = next;
    if (n.children != null || n.codeLen > cbits) {
      break;
    }
    out.add(n.sym);
    cbits -= n.codeLen;
    n = root;
    sbits = cbits;
  }
  if (sbits > 7) {
    // Either there was an incomplete symbol, or overlong padding. Both are
    // decoding errors per RFC 7541 section 5.2.
    throw const FormatException(_invalidHuffmanMessage);
  }
  final mask = (1 << cbits) - 1;
  if ((cur & mask) != mask) {
    // Trailing bits must be a prefix of EOS per RFC 7541 section 5.2.
    throw const FormatException(_invalidHuffmanMessage);
  }
  return String.fromCharCodes(out);
}

/// Port of `AppendHuffmanString`. Appends [s], as encoded in Huffman codes,
/// to [dst] and returns the extended buffer.
///
/// The bit accumulator needs up to 61 valid bits at a time (a leftover of
/// up to 31 bits from the previous flush, plus one more code of up to 30
/// bits, before the `n >= 32` flush check runs again), which exceeds the
/// 53-bit precision Dart guarantees for `int` on Web compilation targets.
/// [Golang.Uint64] is used for the accumulator for that reason, per
/// AGENTS.md's guidance to reuse the validated fixed-width type instead of
/// duplicating overflow-prone shift arithmetic; the final 0-32 leftover
/// bits are extracted into a plain `int` once bounded to 32 bits, which is
/// always precision-safe.
List<int> _appendHuffmanString(List<int> dst, String s) {
  var x = Golang.Uint64(0);
  var n = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i) & 0xff;
    final codeLen = _huffmanCodeLen[c];
    n += codeLen;
    x = (x << (codeLen % 64)) | Golang.Uint64(_huffmanCodes[c]);
    if (n >= 32) {
      n %= 32;
      final y = ((x >> n) & Golang.Uint64(0xffffffff)).toBigInt().toInt();
      dst
        ..add((y >> 24) & 0xff)
        ..add((y >> 16) & 0xff)
        ..add((y >> 8) & 0xff)
        ..add(y & 0xff);
    }
  }
  // Add padding bits if necessary.
  final over = n % 8;
  if (over > 0) {
    const eosPadByte = 0xff; // eosCode(0x3fffffff) >> (eosNBits(30) - 8)
    final pad = 8 - over;
    x = (x << pad) | Golang.Uint64(eosPadByte >> over);
    n += pad; // 8 now divides into n exactly
  }
  // n in (0, 8, 16, 24, 32); the low `n` bits of x are the pending output.
  final lowWord = (x & Golang.Uint64(0xffffffff)).toBigInt().toInt();
  switch (n ~/ 8) {
    case 0:
      return dst;
    case 1:
      dst.add(lowWord & 0xff);
      return dst;
    case 2:
      dst
        ..add((lowWord >> 8) & 0xff)
        ..add(lowWord & 0xff);
      return dst;
    case 3:
      dst
        ..add((lowWord >> 16) & 0xff)
        ..add((lowWord >> 8) & 0xff)
        ..add(lowWord & 0xff);
      return dst;
    default:
      dst
        ..add((lowWord >> 24) & 0xff)
        ..add((lowWord >> 16) & 0xff)
        ..add((lowWord >> 8) & 0xff)
        ..add(lowWord & 0xff);
      return dst;
  }
}

/// Port of `HuffmanEncodeLength`. Returns the number of bytes required to
/// encode [s] in Huffman codes, rounded up to a byte boundary.
int _huffmanEncodeLength(String s) {
  var n = 0;
  for (var i = 0; i < s.length; i++) {
    n += _huffmanCodeLen[s.codeUnitAt(i) & 0xff];
  }
  return (n + 7) ~/ 8;
}
