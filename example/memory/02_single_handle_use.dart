// Memory 02 · Single-handle deterministic release with .use() and .release().
//
// What: deterministically free a single GoHandle at the end of a synchronous
// block, an async Future block, or when replacing a handle stored in a field.
//
//   dart run example/memory/02_single_handle_use.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ipfs_ffi/go/bytes.dart' as go_bytes;
import 'package:ipfs_ffi/go/os.dart' as os;
import 'package:ipfs_ffi/go/io.dart' as io;
import 'package:ipfs_ffi/ipfs_ffi.dart';

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_mem02_');
  await P2pService.start();
  try {
    print('== 1. Synchronous .use() on a memory buffer ==');
    final length =
        go_bytes.Buffer(Uint8List.fromList(utf8.encode('hello ipfs_ffi')))
            .use((buf) {
      final len = buf.bytes().length;
      print('inside use(): buf.bytes().length = $len, '
          'isReleased = ${buf.isReleased}');
      return len;
    });
    print('returned length = $length (buffer handle already released in Go)');

    print('\n== 2. Combining OS resource .close() with handle .use() ==');
    final filePath = '${tmp.path}/sample.txt';
    File(filePath).writeAsStringSync('deterministic file + handle cleanup');

    // f.close() closes the OS file descriptor in Go;
    // .use() releases the *os.File handle from Go's handle table.
    final content = os.open(filePath).use((f) {
      try {
        return utf8.decode(io.readAll(f));
      } finally {
        f.close();
      }
    });
    print('read from os.File: "$content"');

    print(
        '\n== 3. Asynchronous .use() (waits for the Future before release) ==');
    final asyncBuf = go_bytes.Buffer(Uint8List.fromList([10, 20, 30]));
    final sum = await asyncBuf.use((b) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Still alive after the await!
      final bytes = io.readAll(b);
      return bytes.fold<int>(0, (a, c) => a + c);
    });
    print('async sum = $sum, asyncBuf.isReleased = ${asyncBuf.isReleased}');

    print('\n== 4. Manual .release() when rotating a state field ==');
    var current = go_bytes.Buffer(Uint8List(1024));
    print('initial handle: ${current.$h}');
    // Before replacing `current` with a new handle, release the old one:
    current.release();
    current = go_bytes.Buffer(Uint8List(2048));
    print('rotated handle: ${current.$h} '
        '(new length: ${current.bytes().length})');
    current.release();
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
