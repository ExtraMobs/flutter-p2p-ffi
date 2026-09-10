import 'dart:io';
import 'dart:typed_data';

/// Fixture sizes used by the large-file Kubo interoperability proof.
const largeFixtureSizesMiB = <int>[50, 100, 200, 500];

/// Creates an exact-size, reproducible ASCII text file without buffering it.
Future<File> writeDeterministicTextFixture({
  required Directory root,
  required int sizeMiB,
  int seed = 0x6d2b79f5,
}) async {
  if (!largeFixtureSizesMiB.contains(sizeMiB)) {
    throw ArgumentError.value(sizeMiB, 'sizeMiB', 'unsupported fixture size');
  }
  final file = File(
    '${root.path}${Platform.pathSeparator}fixture-$sizeMiB-MiB.txt',
  );
  await file.parent.create(recursive: true);
  final sink = file.openWrite();
  final totalBytes = sizeMiB * 1024 * 1024;
  final buffer = Uint8List(64 * 1024);
  var written = 0;
  var state = seed & 0x7fffffff;
  var complete = false;
  try {
    while (written < totalBytes) {
      final length = totalBytes - written < buffer.length
          ? totalBytes - written
          : buffer.length;
      for (var i = 0; i < length; i++) {
        state ^= (state << 13) & 0x7fffffff;
        state ^= state >> 17;
        state ^= (state << 5) & 0x7fffffff;
        buffer[i] = 32 + (state % 95);
      }
      sink.add(buffer.sublist(0, length));
      written += length;
    }
    await sink.flush();
    complete = true;
    return file;
  } finally {
    try {
      await sink.close();
    } finally {
      if (!complete && await file.exists()) await file.delete();
    }
  }
}

/// Compares two files without retaining either file in memory.
Future<bool> filesEqualStreaming(
  File expected,
  File actual, {
  int chunkSize = 64 * 1024,
}) async {
  if (chunkSize <= 0) throw ArgumentError.value(chunkSize, 'chunkSize');
  final expectedLength = await expected.length();
  if (expectedLength != await actual.length()) return false;
  final expectedFile = await expected.open();
  final actualFile = await actual.open();
  try {
    while (true) {
      final left = await expectedFile.read(chunkSize);
      final right = await actualFile.read(chunkSize);
      if (left.length != right.length) return false;
      for (var i = 0; i < left.length; i++) {
        if (left[i] != right[i]) return false;
      }
      if (left.isEmpty) return true;
    }
  } finally {
    await expectedFile.close();
    await actualFile.close();
  }
}
