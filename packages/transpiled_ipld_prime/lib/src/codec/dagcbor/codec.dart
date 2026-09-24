// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-ipld-prime/codec/dagcbor.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:transpiled_cid/transpiled_cid.dart';

import '../../datamodel/kind.dart';
import '../../datamodel/node.dart';
import '../../datamodel/node_builder.dart';
import '../../linking/cid/cid_link.dart';
import '../../multicodec/registry.dart';
import '../api.dart';

/// Tag number for IPLD links in CBOR.
const int linkTag = 42;

const int _defaultAllocationBudget = 1048576 * 10;
const int _defaultMaxCollectionPrealloc = 1024;
const int _defaultMaxDepth = 1024;
const int _mapEntryCost = 8;
const int _listEntryCost = 4;

/// Thrown when a link's multibase prefix is not 0x00.
const FormatException errInvalidMultibase = FormatException(
  'invalid multibase on IPLD link',
);

/// Thrown when the allocation budget is exhausted during decoding.
const FormatException errAllocationBudgetExceeded = FormatException(
  'message structure demanded too many resources to process',
);

/// Thrown when the nesting depth exceeds maxDepth.
const FormatException errDecodeDepthExceeded = FormatException(
  'message structure exceeded maximum nesting depth',
);

/// Thrown when unexpected bytes remain after the end of the CBOR object.
const FormatException errTrailingBytes = FormatException(
  'unexpected content after end of cbor object',
);

/// Registers DAG-CBOR (multicodec 0x71) in [registry].
void registerDagCborCodec([Registry? registry]) {
  final target = registry ?? defaultRegistry;
  target.registerEncoder(0x71, encode);
  target.registerDecoder(0x71, decode);
}

/// Options customizing the behavior of DAG-CBOR encoding.
final class EncodeOptions {
  const EncodeOptions({
    this.allowLinks = true,
    this.mapSortMode = MapSortMode.rfc7049,
  });

  /// If true, allow encoding of Link nodes as CBOR tag(42); otherwise reject them.
  final bool allowLinks;

  /// Control the sorting of map keys.
  final MapSortMode mapSortMode;

  /// Walks [n] and serializes it to [w].
  void encode(Node n, Sink<List<int>> w) {
    marshal(n, w, this);
  }
}

/// Walk [n] and serialize it using default DAG-CBOR options.
void encode(Node n, Sink<List<int>> w) {
  const EncodeOptions(
    allowLinks: true,
    mapSortMode: MapSortMode.rfc7049,
  ).encode(n, w);
}

/// Alias for [encode] specific to DAG-CBOR.
void encodeDagCbor(Node n, Sink<List<int>> w) => encode(n, w);

/// Deprecated function name for encoding matching Go's `Marshal`.
void marshal(Node n, Sink<List<int>> sink, EncodeOptions options) {
  _encodeNode(n, sink, options);
}

void _encodeNode(Node n, Sink<List<int>> sink, EncodeOptions options) {
  switch (n.kind()) {
    case Kind.invalid:
      throw const FormatException('cannot traverse a node that is absent');
    case Kind.null_:
      sink.add(const [0xf6]);
    case Kind.bool_:
      sink.add([n.asBool() ? 0xf5 : 0xf4]);
    case Kind.int_:
      final v = n.asInt();
      if (v >= 0) {
        _writeHeader(0, v, sink);
      } else {
        _writeHeader(1, -1 - v, sink);
      }
    case Kind.float:
      final v = n.asFloat();
      final bd = ByteData(8)..setFloat64(0, v, Endian.big);
      sink.add([0xfb, ...bd.buffer.asUint8List()]);
    case Kind.string:
      final bytes = utf8.encode(n.asString());
      _writeHeader(3, bytes.length, sink);
      sink.add(bytes);
    case Kind.bytes:
      final bytes = n.asBytes();
      _writeHeader(2, bytes.length, sink);
      sink.add(bytes);
    case Kind.link:
      if (!options.allowLinks) {
        throw const FormatException('cannot Marshal ipld links to CBOR');
      }
      final link = n.asLink();
      if (link is! CidLink) {
        throw const FormatException(
          'schemafree link emission only supported by this codec for CID type links',
        );
      }
      final rawCid = link.cid.toBytes();
      if (rawCid.isEmpty) {
        throw const FormatException(
          'encoding undefined CIDs are not supported by this codec',
        );
      }
      // Tag 42: 0xd8, 0x2a followed by byte string prefixed with 0x00
      sink.add(const [0xd8, 0x2a]);
      _writeHeader(2, rawCid.length + 1, sink);
      sink.add([0x00, ...rawCid]);
    case Kind.list:
      final len = n.length();
      _writeHeader(4, len, sink);
      for (var i = 0; i < len; i++) {
        final val = n.lookupByIndex(i);
        _encodeNode(val, sink, options);
      }
    case Kind.map:
      _encodeMap(n, sink, options);
  }
}

void _encodeMap(Node n, Sink<List<int>> sink, EncodeOptions options) {
  final len = n.length();
  _writeHeader(5, len, sink);
  final entries = <({String key, Node value, Uint8List keyBytes})>[];
  final it = n.mapIterator()!;
  while (!it.done()) {
    final (kNode, vNode) = it.next();
    final kStr = kNode.asString();
    entries.add((
      key: kStr,
      value: vNode,
      keyBytes: Uint8List.fromList(utf8.encode(kStr)),
    ));
  }
  if (entries.length != len) {
    throw const FormatException(
      'map Length() does not match number of MapIterator() entries',
    );
  }

  switch (options.mapSortMode) {
    case MapSortMode.none:
      break;
    case MapSortMode.lexical:
      entries.sort((a, b) => a.key.compareTo(b.key));
    case MapSortMode.rfc7049:
      entries.sort((a, b) {
        if (a.keyBytes.length != b.keyBytes.length) {
          return a.keyBytes.length.compareTo(b.keyBytes.length);
        }
        for (var i = 0; i < a.keyBytes.length; i++) {
          if (a.keyBytes[i] != b.keyBytes[i]) {
            return a.keyBytes[i].compareTo(b.keyBytes[i]);
          }
        }
        return 0;
      });
  }

  for (final entry in entries) {
    _writeHeader(3, entry.keyBytes.length, sink);
    sink.add(entry.keyBytes);
    _encodeNode(entry.value, sink, options);
  }
}

void _writeHeader(int major, int value, Sink<List<int>> sink) {
  if (value < 0) throw RangeError.value(value, 'value');
  if (value < 24) {
    sink.add([(major << 5) | value]);
  } else if (value <= 0xff) {
    sink.add([(major << 5) | 24, value]);
  } else if (value <= 0xffff) {
    sink.add([(major << 5) | 25, (value >> 8) & 0xff, value & 0xff]);
  } else if (value <= 0xffffffff) {
    sink.add([
      (major << 5) | 26,
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ]);
  } else {
    sink.add([
      (major << 5) | 27,
      (value >> 56) & 0xff,
      (value >> 48) & 0xff,
      (value >> 40) & 0xff,
      (value >> 32) & 0xff,
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ]);
  }
}

final class BoundaryLength {
  const BoundaryLength(this.upperBound, this.length);
  final int upperBound;
  final int length;
}

const List<BoundaryLength> lengthBoundaries = [
  BoundaryLength(24, 1),
  BoundaryLength(256, 2),
  BoundaryLength(65536, 3),
  BoundaryLength(4294967296, 5),
  BoundaryLength(0, 9),
];

int uintLength(int ii) {
  for (final lb in lengthBoundaries) {
    if (lb.upperBound != 0 && ii < lb.upperBound) {
      return lb.length;
    }
  }
  return lengthBoundaries.last.length;
}

/// Calculates the length in bytes that the encoded form of [n] will occupy.
int encodedLength(Node n) {
  switch (n.kind()) {
    case Kind.invalid:
      throw const FormatException('cannot traverse a node that is absent');
    case Kind.null_:
      return 1;
    case Kind.bool_:
      return 1;
    case Kind.int_:
      var v = n.asInt();
      if (v < 0) v = -v - 1;
      return uintLength(v);
    case Kind.float:
      return 9;
    case Kind.string:
      final bytes = utf8.encode(n.asString());
      return uintLength(bytes.length) + bytes.length;
    case Kind.bytes:
      final bytes = n.asBytes();
      return uintLength(bytes.length) + bytes.length;
    case Kind.link:
      final v = n.asLink();
      if (v is! CidLink) {
        throw const FormatException(
          'schemafree link emission only supported by this codec for CID type links',
        );
      }
      final bl = v.cid.toBytes().length + 1;
      return 2 + uintLength(bl) + bl;
    case Kind.list:
      final nl = n.length();
      var length = uintLength(nl);
      for (var i = 0; i < nl; i++) {
        length += encodedLength(n.lookupByIndex(i));
      }
      return length;
    case Kind.map:
      final len = n.length();
      var length = uintLength(len);
      final it = n.mapIterator()!;
      while (!it.done()) {
        final (k, val) = it.next();
        final kBytes = utf8.encode(k.asString());
        length += uintLength(kBytes.length) + kBytes.length;
        length += encodedLength(val);
      }
      return length;
  }
}

/// Options customizing the behavior of DAG-CBOR decoding.
final class DecodeOptions {
  const DecodeOptions({
    this.allowLinks = true,
    this.relaxedDecode = false,
    this.dontParseBeyondEnd = false,
    this.allocationBudget = 0,
    this.maxCollectionPrealloc = 0,
    this.maxDepth = 0,
  });

  /// If true, parse DAG-CBOR tag(42) as Link nodes, otherwise reject them.
  final bool allowLinks;

  /// RelaxedDecode allows some legacy non-canonical CBOR forms.
  final bool relaxedDecode;

  /// If true, the decoder stops reading from the stream at the end of a full CBOR object.
  final bool dontParseBeyondEnd;

  /// Maximum budget for the decoder.
  final int allocationBudget;

  /// Maximum size hint passed to beginMap/beginList.
  final int maxCollectionPrealloc;

  /// Maximum nesting depth.
  final int maxDepth;

  int get effectiveBudget =>
      allocationBudget > 0 ? allocationBudget : _defaultAllocationBudget;
  int get effectiveMaxPrealloc =>
      maxCollectionPrealloc > 0
          ? maxCollectionPrealloc
          : _defaultMaxCollectionPrealloc;
  int get effectiveMaxDepth =>
      maxDepth > 0 ? maxDepth : _defaultMaxDepth;

  /// Deserializes data from [r] into [na].
  void decode(NodeAssembler na, Iterable<int> r) {
    final bytes = r is Uint8List
        ? r
        : Uint8List.fromList(r.toList(growable: false));
    final decoder = _CborDecoder(bytes, this);
    decoder.decodeRoot(na);
    if (!dontParseBeyondEnd && decoder.offset < bytes.length) {
      throw errTrailingBytes;
    }
  }
}

/// Deserializes data from [r] and feeds it into [na].
void decode(NodeAssembler na, Iterable<int> r) {
  const DecodeOptions(allowLinks: true).decode(na, r);
}

/// Alias for [decode] specific to DAG-CBOR.
void decodeDagCbor(NodeAssembler na, Iterable<int> r) => decode(na, r);

/// Deprecated function name matching Go's `Unmarshal`.
void unmarshal(
  NodeAssembler na,
  Iterable<int> reader,
  DecodeOptions options,
) {
  options.decode(na, reader);
}

final class _CborDecoder {
  _CborDecoder(this.bytes, this.options) : budget = options.effectiveBudget;

  final Uint8List bytes;
  final DecodeOptions options;
  int offset = 0;
  int budget;
  int depth = 0;

  void decodeRoot(NodeAssembler na) {
    if (offset >= bytes.length) {
      throw const FormatException('unexpected EOF');
    }
    _decodeValue(na, null);
  }

  void _decodeValue(NodeAssembler na, int? currentTag) {
    if (offset >= bytes.length) {
      throw const FormatException('unexpected EOF');
    }
    final initial = bytes[offset++];
    final major = initial >> 5;
    final additional = initial & 0x1f;

    if (additional == 31) {
      throw const FormatException(
        'indefinite length CBOR is not allowed in DAG-CBOR',
      );
    }

    final val = _readArgument(additional);

    switch (major) {
      case 0: // Unsigned integer
        _spend(1);
        na.assignInt(val);
      case 1: // Negative integer
        _spend(1);
        na.assignInt(-1 - val);
      case 2: // Byte string
        _spend(val);
        if (offset + val > bytes.length) {
          throw const FormatException('unexpected EOF reading bytes');
        }
        final b = Uint8List.sublistView(bytes, offset, offset + val);
        offset += val;
        if (currentTag == linkTag) {
          if (!options.allowLinks) {
            throw FormatException('unhandled cbor tag $currentTag');
          }
          if (b.isEmpty || b[0] != 0) {
            throw errInvalidMultibase;
          }
          final cid = Cid.fromBytes(Uint8List.sublistView(b, 1));
          na.assignLink(CidLink(cid));
        } else if (currentTag != null) {
          throw FormatException('unhandled cbor tag $currentTag');
        } else {
          na.assignBytes(b);
        }
      case 3: // Text string
        _spend(val);
        if (offset + val > bytes.length) {
          throw const FormatException('unexpected EOF reading text');
        }
        final s = utf8.decode(
          Uint8List.sublistView(bytes, offset, offset + val),
        );
        offset += val;
        if (currentTag != null) {
          throw FormatException('unhandled cbor tag $currentTag');
        }
        na.assignString(s);
      case 4: // Array
        if (currentTag != null) {
          throw FormatException('unhandled cbor tag $currentTag');
        }
        if (depth >= options.effectiveMaxDepth) {
          throw errDecodeDepthExceeded;
        }
        _spend(val * _listEntryCost);
        final alloc = val > options.effectiveMaxPrealloc
            ? options.effectiveMaxPrealloc
            : val;
        final la = na.beginList(alloc);
        depth++;
        for (var i = 0; i < val; i++) {
          _decodeValue(la.assembleValue(), null);
        }
        depth--;
        la.finish();
      case 5: // Map
        if (currentTag != null) {
          throw FormatException('unhandled cbor tag $currentTag');
        }
        if (depth >= options.effectiveMaxDepth) {
          throw errDecodeDepthExceeded;
        }
        _spend(val);
        final alloc = val > options.effectiveMaxPrealloc
            ? options.effectiveMaxPrealloc
            : val;
        final ma = na.beginMap(alloc);
        depth++;
        final seenKeys = <String>{};
        for (var i = 0; i < val; i++) {
          if (offset >= bytes.length) {
            throw const FormatException('unexpected EOF reading map key');
          }
          final kInitial = bytes[offset++];
          final kMajor = kInitial >> 5;
          final kAdd = kInitial & 0x1f;
          if (kAdd == 31) {
            throw const FormatException(
              'indefinite length CBOR is not allowed in DAG-CBOR',
            );
          }
          if (kMajor != 3) {
            throw const FormatException('unexpected token while expecting map key');
          }
          final kLen = _readArgument(kAdd);
          _spend(kLen + _mapEntryCost);
          if (offset + kLen > bytes.length) {
            throw const FormatException('unexpected EOF reading map key text');
          }
          final key = utf8.decode(
            Uint8List.sublistView(bytes, offset, offset + kLen),
          );
          offset += kLen;
          if (!options.relaxedDecode) {
            if (!seenKeys.add(key)) {
              throw FormatException('duplicate map key "$key"');
            }
          }
          final entryAssembler = ma.assembleEntry(key);
          _decodeValue(entryAssembler, null);
        }
        depth--;
        ma.finish();
      case 6: // Tag
        if (val != linkTag) {
          throw FormatException('unhandled cbor tag $val');
        }
        _decodeValue(na, val);
      case 7: // Simple / Float
        _spend(1);
        switch (additional) {
          case 20:
            na.assignBool(false);
          case 21:
            na.assignBool(true);
          case 22:
            na.assignNull();
          case 23:
            // Undefined in CBOR -> coerced to null in DAG-CBOR
            na.assignNull();
          case 25: // Float16
            final f16 = _readUint16();
            final f = _halfToDouble(f16);
            if (!options.relaxedDecode && (f.isNaN || f.isInfinite)) {
              throw const FormatException(
                'NaN and Infinity are not permitted in strict DAG-CBOR',
              );
            }
            na.assignFloat(f);
          case 26: // Float32
            final f32 = _readFloat32();
            if (!options.relaxedDecode && (f32.isNaN || f32.isInfinite)) {
              throw const FormatException(
                'NaN and Infinity are not permitted in strict DAG-CBOR',
              );
            }
            na.assignFloat(f32);
          case 27: // Float64
            final f64 = _readFloat64();
            if (!options.relaxedDecode && (f64.isNaN || f64.isInfinite)) {
              throw const FormatException(
                'NaN and Infinity are not permitted in strict DAG-CBOR',
              );
            }
            na.assignFloat(f64);
          default:
            throw FormatException('unsupported simple value $additional');
        }
      default:
        throw FormatException('unsupported CBOR major type $major');
    }
  }

  int _readArgument(int additional) {
    if (additional < 24) return additional;
    switch (additional) {
      case 24:
        if (offset >= bytes.length) throw const FormatException('unexpected EOF');
        final val = bytes[offset++];
        if (!options.relaxedDecode && val < 24) {
          throw const FormatException('non-minimal integer encoding in CBOR');
        }
        return val;
      case 25:
        final val = _readUint16();
        if (!options.relaxedDecode && val <= 0xff) {
          throw const FormatException('non-minimal integer encoding in CBOR');
        }
        return val;
      case 26:
        final val = _readUint32();
        if (!options.relaxedDecode && val <= 0xffff) {
          throw const FormatException('non-minimal integer encoding in CBOR');
        }
        return val;
      case 27:
        final val = _readUint64();
        if (!options.relaxedDecode && val <= 0xffffffff) {
          throw const FormatException('non-minimal integer encoding in CBOR');
        }
        return val;
      default:
        throw FormatException('invalid CBOR additional info: $additional');
    }
  }

  int _readUint16() {
    if (offset + 2 > bytes.length) throw const FormatException('unexpected EOF');
    final val = (bytes[offset] << 8) | bytes[offset + 1];
    offset += 2;
    return val;
  }

  int _readUint32() {
    if (offset + 4 > bytes.length) throw const FormatException('unexpected EOF');
    final val = (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    offset += 4;
    return val;
  }

  int _readUint64() {
    if (offset + 8 > bytes.length) throw const FormatException('unexpected EOF');
    var val = 0;
    for (var i = 0; i < 8; i++) {
      val = (val << 8) | bytes[offset + i];
    }
    offset += 8;
    return val;
  }

  double _readFloat32() {
    if (offset + 4 > bytes.length) throw const FormatException('unexpected EOF');
    final bd = ByteData.sublistView(bytes, offset, offset + 4);
    offset += 4;
    return bd.getFloat32(0, Endian.big);
  }

  double _readFloat64() {
    if (offset + 8 > bytes.length) throw const FormatException('unexpected EOF');
    final bd = ByteData.sublistView(bytes, offset, offset + 8);
    offset += 8;
    return bd.getFloat64(0, Endian.big);
  }

  void _spend(int amount) {
    budget -= amount;
    if (budget < 0) {
      throw errAllocationBudgetExceeded;
    }
  }

  static double _halfToDouble(int h) {
    final s = (h >> 15) & 0x0001;
    final e = (h >> 10) & 0x001f;
    final f = h & 0x03ff;
    if (e == 0) {
      if (f == 0) return s != 0 ? -0.0 : 0.0;
      return (s != 0 ? -1.0 : 1.0) * math.pow(2, -14) * (f / 1024.0);
    } else if (e == 31) {
      if (f == 0) return s != 0 ? double.negativeInfinity : double.infinity;
      return double.nan;
    }
    return (s != 0 ? -1.0 : 1.0) * math.pow(2, e - 15) * (1.0 + f / 1024.0);
  }
}
