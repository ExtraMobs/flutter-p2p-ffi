// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:typed_data';

/// The fixed chunk size used by Kubo and Boxo by default (256 KiB).
int defaultBlockSize = 256 * 1024;

/// Maximum Bitswap block size from the protocol specification.
const int blockSizeLimit = 2 * 1024 * 1024;

/// Space reserved by Boxo for UnixFS/protobuf framing.
const int chunkOverheadBudget = 256;

/// Maximum fixed chunk size accepted by Boxo's string parser.
const int chunkSizeLimit = blockSizeLimit - chunkOverheadBudget;

/// Boxo's `ErrSize` sentinel for non-positive parsed sizes.
const errSize = FormatException('chunker size must be greater than 0');

/// Boxo's `ErrSizeMax` sentinel for parsed sizes exceeding the limit.
const errSizeMax = FormatException(
  'chunker parameters may not exceed the maximum chunk size of $chunkSizeLimit',
);

/// Splits a byte stream into fixed-size chunks.
///
/// The final chunk is emitted at EOF, including when it is shorter than
/// [size]. Empty input emits no chunks.
class FixedSizeChunker {
  FixedSizeChunker(this.input, {int? size}) : size = size ?? defaultBlockSize {
    if (this.size <= 0) throw ArgumentError.value(this.size, 'size');
  }

  factory FixedSizeChunker.fromBytes(Uint8List bytes, {int? size}) =>
      FixedSizeChunker(Stream.value(bytes), size: size);

  /// Creates a fixed-size splitter using [defaultBlockSize]. Equivalent to
  /// Go's `DefaultSplitter`.
  factory FixedSizeChunker.defaultSize(Stream<List<int>> input) =>
      FixedSizeChunker(input);

  /// Creates a fixed-size splitter of [size] bytes. Equivalent to Go's
  /// `NewSizeSplitter`.
  factory FixedSizeChunker.size(Stream<List<int>> input, int size) =>
      FixedSizeChunker(input, size: size);

  final Stream<List<int>> input;
  final int size;

  Stream<Uint8List> chunks() async* {
    final pending = BytesBuilder(copy: false);
    await for (final part in input) {
      if (part.isEmpty) continue;
      pending.add(part);
      while (pending.length >= size) {
        final bytes = pending.takeBytes();
        yield Uint8List.fromList(bytes.sublist(0, size));
        pending.add(bytes.sublist(size));
      }
    }
    if (pending.length != 0) yield pending.takeBytes();
  }
}

/// Parses the fixed-size chunker forms accepted by the Boxo importer.
FixedSizeChunker fromString(
  Stream<List<int>> input, [
  String spec = 'default',
]) {
  if (spec.isEmpty || spec == 'default') {
    return FixedSizeChunker.defaultSize(input);
  }
  final parts = spec.split('-');
  if (parts.first != 'size') {
    throw FormatException('unrecognized chunker option: $spec');
  }
  if (parts.length != 2) {
    throw const FormatException(
      'incorrect chunker string format (expected size-{size})',
    );
  }
  // strconv.Atoi accepts decimal digits (and a leading plus), not Dart's
  // whitespace trimming or hexadecimal syntax.
  final digits = parts[1];
  final decimal = RegExp(r'^\+?[0-9]+$').stringMatch(digits);
  final size = decimal == digits ? int.tryParse(digits, radix: 10) : null;
  if (size == null) {
    throw FormatException('invalid chunker size: $spec');
  }
  if (size <= 0) {
    throw errSize;
  }
  if (size > chunkSizeLimit) {
    throw errSizeMax;
  }
  return FixedSizeChunker.size(input, size);
}

