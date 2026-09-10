// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/partialmessages/bitmap.dart
//
// Port of go-libp2p-pubsub's partialmessages/bitmap/bitmap.go: a growable
// bitmap used to track which chunks of a partial message have arrived.
//
// Go's `Bitmap` is `type Bitmap []byte` with `Set` taking the receiver BY
// VALUE and growing it locally via `append` -- since Go slices are a
// value-type header (pointer/len/cap), that local growth is invisible to
// the caller's own variable unless `Set` returned the new slice (it
// doesn't). That looks like a latent bug in the upstream Go code (calling
// `Set` past the current length silently has no lasting effect on the
// caller's bitmap) rather than an intentional contract worth preserving.
// This port instead wraps a `Uint8List` in a class and grows the shared
// backing storage in place, so `set` past the current length behaves as
// the Go code clearly intends: growth stays visible to every holder of
// the same `Bitmap` object, which Dart's reference semantics support
// naturally where Go's value-type slice couldn't.
import 'dart:typed_data';

/// A growable bitmap. Equivalent to go-ipld-prime's `Bitmap` (see this
/// file's header for the one behavioral fix over the Go original).
class Bitmap {
  /// Creates a bitmap backed by [bytes] directly (not copied).
  Bitmap(this._bytes);

  /// Creates a bitmap of [n] bits, all set to one. Equivalent to
  /// go-libp2p-pubsub's `NewBitmapWithOnesCount`.
  factory Bitmap.withOnesCount(int n) {
    final bitmap = Bitmap(Uint8List((n + 7) ~/ 8));
    for (var i = 0; i < n; i++) {
      bitmap.set(i);
    }
    return bitmap;
  }

  Uint8List _bytes;

  /// The number of bytes backing this bitmap.
  int get byteLength => _bytes.length;

  /// The raw bytes backing this bitmap. Must not be mutated directly by
  /// callers who don't own it.
  Uint8List get bytes => _bytes;

  /// The bitwise OR of [left] and [right], sized to the larger of the two.
  /// Equivalent to go-libp2p-pubsub's `Merge`.
  static Bitmap merge(Bitmap left, Bitmap right) {
    final n = left.byteLength > right.byteLength ? left.byteLength : right.byteLength;
    final out = Bitmap(Uint8List(n));
    out.or(left);
    out.or(right);
    return out;
  }

  /// Whether every bit is zero. Equivalent to go-libp2p-pubsub's
  /// `Bitmap.IsZero`.
  bool get isZero => _bytes.every((b) => b == 0);

  /// The number of one bits set. Equivalent to go-libp2p-pubsub's
  /// `Bitmap.OnesCount`.
  int get onesCount {
    var count = 0;
    for (final byte in _bytes) {
      count += _popCount8(byte);
    }
    return count;
  }

  /// Sets bit [index] to one, growing this bitmap's storage first if
  /// needed. Equivalent to go-libp2p-pubsub's `Bitmap.Set`.
  void set(int index) {
    _ensureByteLength((index ~/ 8) + 1);
    _bytes[index ~/ 8] |= 1 << (index % 8);
  }

  /// Whether bit [index] is set (`false` if [index] is beyond this
  /// bitmap's current length). Equivalent to go-libp2p-pubsub's
  /// `Bitmap.Get`.
  bool get(int index) {
    if (index >= _bytes.length * 8) return false;
    return (_bytes[index ~/ 8] & (1 << (index % 8))) != 0;
  }

  /// Sets bit [index] to zero (a no-op if [index] is beyond this bitmap's
  /// current length). Equivalent to go-libp2p-pubsub's `Bitmap.Clear`.
  void clear(int index) {
    if (index >= _bytes.length * 8) return;
    _bytes[index ~/ 8] &= ~(1 << (index % 8)) & 0xFF;
  }

  /// Bitwise ANDs [other] into this bitmap, up to the shorter of the two
  /// lengths. Equivalent to go-libp2p-pubsub's `Bitmap.And`.
  void and(Bitmap other) {
    final n = _bytes.length < other._bytes.length ? _bytes.length : other._bytes.length;
    for (var i = 0; i < n; i++) {
      _bytes[i] &= other._bytes[i];
    }
  }

  /// Bitwise ORs [other] into this bitmap, up to the shorter of the two
  /// lengths. Equivalent to go-libp2p-pubsub's `Bitmap.Or`.
  void or(Bitmap other) {
    final n = _bytes.length < other._bytes.length ? _bytes.length : other._bytes.length;
    for (var i = 0; i < n; i++) {
      _bytes[i] |= other._bytes[i];
    }
  }

  /// Bitwise XORs [other] into this bitmap, up to the shorter of the two
  /// lengths. Equivalent to go-libp2p-pubsub's `Bitmap.Xor`.
  void xor(Bitmap other) {
    final n = _bytes.length < other._bytes.length ? _bytes.length : other._bytes.length;
    for (var i = 0; i < n; i++) {
      _bytes[i] ^= other._bytes[i];
    }
  }

  /// Flips every bit. Equivalent to go-libp2p-pubsub's `Bitmap.Flip`.
  void flip() {
    for (var i = 0; i < _bytes.length; i++) {
      _bytes[i] ^= 0xFF;
    }
  }

  void _ensureByteLength(int minLength) {
    if (_bytes.length >= minLength) return;
    final grown = Uint8List(minLength)..setRange(0, _bytes.length, _bytes);
    _bytes = grown;
  }
}

int _popCount8(int byte) {
  var count = 0;
  var b = byte;
  while (b != 0) {
    count += b & 1;
    b >>= 1;
  }
  return count;
}
