/// Any Go `io.Reader` handle as a Dart `Stream` (hand-written; function 42 of
/// WIRE.md).
///
/// ```dart
/// import 'package:p2p_ffi/go/io_stream.dart' as io;
///
/// final file = files.toFile(await unixfile.newUnixfsFile(ctx, dag, root));
/// await for (final chunk in io.readerStream(file)) {
///   sink.add(chunk);
/// }
/// ```
library;

import 'dart:typed_data';

import 'package:p2p_ffi/src/runtime.dart';

/// Reads [reader] to the end in pieces of up to 256 KiB, in order. The host
/// closes it when it is an `io.Closer`; a libp2p stream only gets its read
/// side closed (`CloseRead`), so it can still answer. Cancel through the context the reader
/// was created with: canceling the subscription does not stop the read.
Stream<Uint8List> readerStream(GoHandle reader) =>
    $stream(42, $W()..h(reader)).map((r) => r.bytes() ?? Uint8List(0));
