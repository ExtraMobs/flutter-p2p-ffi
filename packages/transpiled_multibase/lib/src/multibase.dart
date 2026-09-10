// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/cid/multibase.dart
//
// Port of go-multibase's Encode/Decode (github.com/multiformats/go-multibase
// multibase.go, base2.go, base32.go, base256emoji.go). go-multibase itself
// declares Base8/Base10/Base45 as constants but does not implement them
// (its Encode/Decode fall through to ErrUnsupportedEncoding for those) --
// this port matches that exactly rather than inventing behavior upstream
// doesn't have.
import 'dart:convert';
import 'dart:typed_data';

import 'package:base32/base32.dart' as b32;
import 'package:base32/encodings.dart' as b32enc;
import 'package:base_x/base_x.dart' as basex;
import 'package:convert/convert.dart' as pkgconvert;
import 'package:multibase/multibase.dart' as mb;

/// Helpers for multibase encoding/decoding used by Cid and other multiformats.
///
/// [decode] and [encodeWithName] cover all 21 encodings go-multibase
/// actually implements (identity, base2, base16(upper), the 8 base32
/// variants, base36(upper), base58btc/flickr, the 4 base64 variants, and
/// base256emoji), keyed by go-multibase's own prefix characters/names.
///
/// [encode] keeps its narrower `mb.Multibase`-typed signature for existing
/// callers (Cid's own encode path only ever needs base16/32/58btc/64), but
/// is now routed through the same correct implementations as [decode]
/// rather than through `package:multibase` directly.
///
/// **base32 is handled separately, not delegated to `package:multibase`.**
/// Verified empirically (see `test/multibase_base32_test.dart`): for a
/// 123-case sweep of all-zero, leading-zero, and random byte sequences at
/// every length 0..40, `package:multibase`'s `Multibase.base32` codec
/// diverges from RFC 4648 in 107/123 encodings -- not a rare edge case, the
/// general case. It applies a big-integer base-conversion algorithm
/// (correct for base58/base36, where it's the actual defined algorithm) to
/// what RFC 4648 base16/32/64 define as fixed-width *bit-packing* schemes
/// instead -- two unrelated algorithms that happen to both be called
/// "baseN". `package:multibase`'s base16/base32(upper) paths have the same
/// defect; this file no longer uses them at all, using `package:base32`
/// (bit-packing, correct) and `package:convert`'s `hex` codec instead.
class MultibaseUtils {
  // Private constructor to prevent instantiation.
  MultibaseUtils._();

  /// Decodes a multibase-encoded string into raw bytes. The input string
  /// must include the multibase prefix character (which may be the
  /// multi-byte `🚀` for base256emoji).
  static Uint8List decode(String input) {
    if (input.isEmpty) {
      throw const FormatException('cannot decode multibase for zero length string');
    }
    final prefix = input.runes.first;
    final rest = input.substring(String.fromCharCode(prefix).length);
    return _decodeByCode(prefix, rest);
  }

  /// Encodes raw bytes using the requested [base]. Covers the 8 encodings
  /// `package:multibase`'s `Multibase` enum knows about; see
  /// [encodeWithName] for the full 21-encoding set (identity, base2,
  /// base32pad/hex variants, base36, base58flickr, base256emoji, ...).
  static String encode(mb.Multibase base, Uint8List bytes) {
    final code = switch (base) {
      mb.Multibase.base16 => 0x66, // 'f'
      mb.Multibase.base16upper => 0x46, // 'F'
      mb.Multibase.base32 => 0x62, // 'b'
      mb.Multibase.base32upper => 0x42, // 'B'
      mb.Multibase.base58btc => 0x7a, // 'z'
      mb.Multibase.base64 => 0x6d, // 'm'
      mb.Multibase.base64url => 0x75, // 'u'
      mb.Multibase.base64urlpad => 0x55, // 'U'
    };
    return _encodeByCode(code, bytes);
  }

  /// Encodes raw bytes using the requested base name (go-multibase's
  /// `EncodingToStr` values, e.g. `base32hexpadupper`, `base58flickr`,
  /// `base256emoji`). Falls back to base32 if the name is unknown.
  static String encodeWithName(String name, Uint8List bytes) {
    final code = _codeFromName[name.toLowerCase()];
    if (code == null) {
      return _encodeByCode(0x62, bytes); // 'b' == base32
    }
    return _encodeByCode(code, bytes);
  }

  static const Map<String, int> _codeFromName = {
    'identity': 0x00,
    'base2': 0x30,
    // Declared by go-multibase but never implemented (its own Encode/Decode
    // fall through to ErrUnsupportedEncoding for these three) -- mapped to
    // their real prefix chars so dispatch below also throws, matching
    // upstream exactly rather than silently falling back to base32.
    'base8': 0x37,
    'base10': 0x39,
    'base45': 0x52,
    'base16': 0x66,
    'base16upper': 0x46,
    'base32': 0x62,
    'base32upper': 0x42,
    'base32pad': 0x63,
    'base32padupper': 0x43,
    'base32hex': 0x76,
    'base32hexupper': 0x56,
    'base32hexpad': 0x74,
    'base32hexpadupper': 0x54,
    'base36': 0x6b,
    'base36upper': 0x4b,
    'base58btc': 0x7a,
    'base58flickr': 0x5a,
    'base64': 0x6d,
    'base64url': 0x75,
    'base64pad': 0x4d,
    'base64urlpad': 0x55,
    'base256emoji': 0x1f680,
  };

  static String _encodeByCode(int code, Uint8List bytes) {
    switch (code) {
      case 0x00: // identity
        return String.fromCharCode(0x00) + _identityString(bytes);
      case 0x30: // '0' base2
        return '0${_base2Encode(bytes)}';
      case 0x66: // 'f' base16
        return 'f${pkgconvert.hex.encode(bytes)}';
      case 0x46: // 'F' base16upper
        return 'F${pkgconvert.hex.encode(bytes).toUpperCase()}';
      case 0x62: // 'b' base32
        return 'b${_b32Encode(bytes, upper: false, pad: false, hex: false)}';
      case 0x42: // 'B' base32upper
        return 'B${_b32Encode(bytes, upper: true, pad: false, hex: false)}';
      case 0x63: // 'c' base32pad
        return 'c${_b32Encode(bytes, upper: false, pad: true, hex: false)}';
      case 0x43: // 'C' base32padupper
        return 'C${_b32Encode(bytes, upper: true, pad: true, hex: false)}';
      case 0x76: // 'v' base32hex
        return 'v${_b32Encode(bytes, upper: false, pad: false, hex: true)}';
      case 0x56: // 'V' base32hexupper
        return 'V${_b32Encode(bytes, upper: true, pad: false, hex: true)}';
      case 0x74: // 't' base32hexpad
        return 't${_b32Encode(bytes, upper: false, pad: true, hex: true)}';
      case 0x54: // 'T' base32hexpadupper
        return 'T${_b32Encode(bytes, upper: true, pad: true, hex: true)}';
      case 0x6b: // 'k' base36
        return 'k${_base36Lower.encode(bytes)}';
      case 0x4b: // 'K' base36upper
        return 'K${_base36Upper.encode(bytes)}';
      case 0x7a: // 'z' base58btc
        return 'z${_base58Btc.encode(bytes)}';
      case 0x5a: // 'Z' base58flickr
        return 'Z${_base58Flickr.encode(bytes)}';
      case 0x6d: // 'm' base64 (unpadded)
        return 'm${_stripPad(base64.encode(bytes))}';
      case 0x75: // 'u' base64url (unpadded)
        return 'u${_stripPad(base64Url.encode(bytes))}';
      case 0x4d: // 'M' base64pad
        return 'M${base64.encode(bytes)}';
      case 0x55: // 'U' base64urlpad
        return 'U${base64Url.encode(bytes)}';
      case 0x1f680: // base256emoji
        return '🚀${_base256EmojiEncode(bytes)}';
      default:
        throw UnsupportedError(
          'selected encoding not supported (code $code)',
        );
    }
  }

  static Uint8List _decodeByCode(int code, String rest) {
    switch (code) {
      case 0x00: // identity
        return Uint8List.fromList(rest.codeUnits);
      case 0x30: // base2
        return _base2Decode(rest);
      case 0x66: // base16
      case 0x46: // base16upper
        return Uint8List.fromList(pkgconvert.hex.decode(rest.toLowerCase()));
      case 0x62: // base32
      case 0x42: // base32upper
      case 0x63: // base32pad
      case 0x43: // base32padupper
        return _b32Decode(rest, hex: false);
      case 0x76: // base32hex
      case 0x56: // base32hexupper
      case 0x74: // base32hexpad
      case 0x54: // base32hexpadupper
        return _b32Decode(rest, hex: true);
      case 0x6b: // base36
      case 0x4b: // base36upper
        return _base36Lower.decode(rest.toLowerCase());
      case 0x7a: // base58btc
        return _base58Btc.decode(rest);
      case 0x5a: // base58flickr
        return _base58Flickr.decode(rest);
      case 0x6d: // base64 (unpadded)
        return base64.decode(_addPad(rest, 4));
      case 0x75: // base64url (unpadded)
        return base64Url.decode(_addPad(rest, 4));
      case 0x4d: // base64pad
        return base64.decode(rest);
      case 0x55: // base64urlpad
        return base64Url.decode(rest);
      case 0x1f680: // base256emoji
        return _base256EmojiDecode(rest);
      default:
        throw UnsupportedError(
          'selected encoding not supported (code $code)',
        );
    }
  }

  // --- identity -------------------------------------------------------

  static String _identityString(Uint8List bytes) =>
      String.fromCharCodes(bytes);

  // --- base2 ------------------------------------------------------------

  static String _base2Encode(Uint8List bytes) {
    final out = StringBuffer();
    for (final b in bytes) {
      for (var j = 7; j >= 0; j--) {
        out.write((b >> j) & 1);
      }
    }
    return out.toString();
  }

  static Uint8List _base2Decode(String s) {
    final padded = s.length % 8 == 0 ? s : ('0' * (8 - s.length % 8)) + s;
    final out = Uint8List(padded.length ~/ 8);
    for (var i = 0; i < out.length; i++) {
      final byte = int.parse(padded.substring(i * 8, i * 8 + 8), radix: 2);
      out[i] = byte;
    }
    return out;
  }

  // --- base32 family (8 variants; RFC 4648 bit-packing, case-insensitive
  // decode, matching go-base32's `NewEncodingCI`) ------------------------

  static String _b32Encode(
    Uint8List bytes, {
    required bool upper,
    required bool pad,
    required bool hex,
  }) {
    final encoding = hex
        ? b32enc.Encoding.base32Hex
        : b32enc.Encoding.standardRFC4648;
    var out = b32.base32.encode(bytes, encoding: encoding);
    if (!upper) out = out.toLowerCase();
    if (!pad) out = _stripPad(out);
    return out;
  }

  static Uint8List _b32Decode(String s, {required bool hex}) {
    final encoding = hex
        ? b32enc.Encoding.base32Hex
        : b32enc.Encoding.standardRFC4648;
    return b32.base32.decode(s.toUpperCase(), encoding: encoding);
  }

  // --- base36 / base58 (big-integer base conversion; correct algorithm for
  // these, unlike base16/32/64) ------------------------------------------

  static final basex.BaseXCodec _base36Lower = basex.BaseXCodec(
    '0123456789abcdefghijklmnopqrstuvwxyz',
  );
  static final basex.BaseXCodec _base36Upper = basex.BaseXCodec(
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ',
  );
  static final basex.BaseXCodec _base58Btc = basex.BaseXCodec(
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz',
  );
  static final basex.BaseXCodec _base58Flickr = basex.BaseXCodec(
    '123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ',
  );

  // --- base64 helpers -----------------------------------------------------

  static String _stripPad(String s) {
    var end = s.length;
    while (end > 0 && s[end - 1] == '=') {
      end--;
    }
    return s.substring(0, end);
  }

  static String _addPad(String s, int multipleOf) {
    final rem = s.length % multipleOf;
    if (rem == 0) return s;
    return s + ('=' * (multipleOf - rem));
  }

  // --- base256emoji: a direct byte<->emoji lookup table, no arithmetic ---

  static const List<String> _base256EmojiTable = [
    '🚀', '🪐', '☄', '🛰', '🌌', '🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗',
    '🌘', '🌍', '🌏', '🌎', '🐉', '☀', '💻', '🖥', '💾', '💿', '😂', '❤',
    '😍', '🤣', '😊', '🙏', '💕', '😭', '😘', '👍', '😅', '👏', '😁', '🔥',
    '🥰', '💔', '💖', '💙', '😢', '🤔', '😆', '🙄', '💪', '😉', '☺', '👌',
    '🤗', '💜', '😔', '😎', '😇', '🌹', '🤦', '🎉', '💞', '✌', '✨', '🤷',
    '😱', '😌', '🌸', '🙌', '😋', '💗', '💚', '😏', '💛', '🙂', '💓', '🤩',
    '😄', '😀', '🖤', '😃', '💯', '🙈', '👇', '🎶', '😒', '🤭', '❣', '😜',
    '💋', '👀', '😪', '😑', '💥', '🙋', '😞', '😩', '😡', '🤪', '👊', '🥳',
    '😥', '🤤', '👉', '💃', '😳', '✋', '😚', '😝', '😴', '🌟', '😬', '🙃',
    '🍀', '🌷', '😻', '😓', '⭐', '✅', '🥺', '🌈', '😈', '🤘', '💦', '✔',
    '😣', '🏃', '💐', '☹', '🎊', '💘', '😠', '☝', '😕', '🌺', '🎂', '🌻',
    '😐', '🖕', '💝', '🙊', '😹', '🗣', '💫', '💀', '👑', '🎵', '🤞', '😛',
    '🔴', '😤', '🌼', '😫', '⚽', '🤙', '☕', '🏆', '🤫', '👈', '😮', '🙆',
    '🍻', '🍃', '🐶', '💁', '😲', '🌿', '🧡', '🎁', '⚡', '🌞', '🎈', '❌',
    '✊', '👋', '😰', '🤨', '😶', '🤝', '🚶', '💰', '🍓', '💢', '🤟', '🙁',
    '🚨', '💨', '🤬', '✈', '🎀', '🍺', '🤓', '😙', '💟', '🌱', '😖', '👶',
    '🥴', '▶', '➡', '❓', '💎', '💸', '⬇', '😨', '🌚', '🦋', '😷', '🕺',
    '⚠', '🙅', '😟', '😵', '👎', '🤲', '🤠', '🤧', '📌', '🔵', '💅', '🧐',
    '🐾', '🍒', '😗', '🤑', '🌊', '🤯', '🐷', '☎', '💧', '😯', '💆', '👆',
    '🎤', '🙇', '🍑', '❄', '🌴', '💣', '🐸', '💌', '📍', '🥀', '🤢', '👅',
    '💡', '💩', '👐', '📸', '👻', '🤐', '🤮', '🎼', '🥵', '🚩', '🍎', '🍊',
    '👼', '💍', '📣', '🥂',
  ];

  static Map<int, int>? _base256EmojiReverse;

  static String _base256EmojiEncode(Uint8List bytes) {
    final out = StringBuffer();
    for (final b in bytes) {
      out.write(_base256EmojiTable[b]);
    }
    return out.toString();
  }

  static Uint8List _base256EmojiDecode(String s) {
    final reverse = _base256EmojiReverse ??= {
      for (var i = 0; i < _base256EmojiTable.length; i++)
        _base256EmojiTable[i].runes.first: i,
    };
    final runes = s.runes.toList();
    final out = Uint8List(runes.length);
    for (var i = 0; i < runes.length; i++) {
      final v = reverse[runes[i]];
      if (v == null) {
        throw FormatException(
          'illegal base256emoji data at index $i, char: '
          '${String.fromCharCode(runes[i])}',
        );
      }
      out[i] = v;
    }
    return out;
  }
}

class UnsupportedEncodingException implements Exception {
  final Object? cause;
  const UnsupportedEncodingException([this.cause]);
  @override
  String toString() => cause == null ? 'unsupported encoding' : 'unsupported encoding: $cause';
}

extension type const Encoding(int value) {
  static const Encoding identity = Encoding(0x00);
  static const Encoding base2 = Encoding(0x30);
  static const Encoding base8 = Encoding(0x37);
  static const Encoding base10 = Encoding(0x39);
  static const Encoding base45 = Encoding(0x52);
  static const Encoding base16 = Encoding(0x66);
  static const Encoding base16upper = Encoding(0x46);
  static const Encoding base32 = Encoding(0x62);
  static const Encoding base32upper = Encoding(0x42);
  static const Encoding base32pad = Encoding(0x63);
  static const Encoding base32padupper = Encoding(0x43);
  static const Encoding base32hex = Encoding(0x76);
  static const Encoding base32hexupper = Encoding(0x56);
  static const Encoding base32hexpad = Encoding(0x74);
  static const Encoding base32hexpadupper = Encoding(0x54);
  static const Encoding base36 = Encoding(0x6b);
  static const Encoding base36upper = Encoding(0x4b);
  static const Encoding base58btc = Encoding(0x7a);
  static const Encoding base58flickr = Encoding(0x5a);
  static const Encoding base64 = Encoding(0x6d);
  static const Encoding base64url = Encoding(0x75);
  static const Encoding base64pad = Encoding(0x4d);
  static const Encoding base64urlpad = Encoding(0x55);
  static const Encoding base256emoji = Encoding(0x1f680);
}

String encode(Encoding base, Uint8List data) {
  return MultibaseUtils._encodeByCode(base.value, data);
}

(Encoding base, Uint8List data) decode(String data) {
  if (data.isEmpty) {
    throw const FormatException('cannot decode multibase for zero length string');
  }
  final prefix = data.runes.first;
  final rest = data.substring(String.fromCharCode(prefix).length);
  final decoded = MultibaseUtils._decodeByCode(prefix, rest);
  return (Encoding(prefix), decoded);
}
