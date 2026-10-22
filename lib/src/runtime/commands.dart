part of '../runtime.dart';

/// Function 36 (WIRE.md, "Commands"): runs a command of kubo's command tree
/// (the RPC's `/api/v0`) in the p2p_host, with the app's node.
const _fnCommand = 36;

// Tag of each emitted item (WIRE.md, "Commands").
// 1 = a dynamic value, read by r.any().
const _cmdTyped = 0, _cmdBytes = 2;

Stream<$R> _command(GoHandle node, GoHandle ctx, String path, List<String> args,
    List<GoHandle> files, Map<String, Object?> opts) {
  final set = [
    for (final e in opts.entries)
      if (e.value != null) e
  ];
  final w = $W()
    ..h(node)
    ..h(ctx)
    ..str(path)
    ..list(args, (w, a) => w.str(a))
    ..list(files, (w, f) => w.h(f))
    ..i32(set.length);
  for (final e in set) {
    w
      ..str(e.key)
      ..any(e.value);
  }
  return $stream(_fnCommand, w);
}

Never _unexpected(String path, int tag, $R r) => throw GolangException(
    'ipfs $path emitted ${tag == _cmdBytes ? 'bytes' : '${r.any()}'}, '
    'not its declared type');

/// A command that emits values of its declared type (every command is a
/// Stream: callers pick `.single`, `.first` or `toList()`).
Stream<T> $cmdStream<T>(
        GoHandle node,
        GoHandle ctx,
        String path,
        List<String> args,
        List<GoHandle> files,
        Map<String, Object?> opts,
        T Function($R r) dec) =>
    _command(node, ctx, path, args, files, opts).map((r) {
      final tag = r.u8();
      if (tag != _cmdTyped) _unexpected(path, tag, r);
      return dec(r);
    });

/// A command that emits bytes (an `io.Reader`: `cat`, `files read`...).
Stream<Uint8List> $cmdBytes(GoHandle node, GoHandle ctx, String path,
        List<String> args, List<GoHandle> files, Map<String, Object?> opts) =>
    _command(node, ctx, path, args, files, opts).map((r) {
      final tag = r.u8();
      if (tag != _cmdBytes) _unexpected(path, tag, r);
      return r.bytes() ?? Uint8List(0);
    });

/// A command without a declared type: each value as Object? (or bytes).
Stream<Object?> $cmdDynStream(GoHandle node, GoHandle ctx, String path,
        List<String> args, List<GoHandle> files, Map<String, Object?> opts) =>
    _command(node, ctx, path, args, files, opts).map((r) => switch (r.u8()) {
          _cmdBytes => r.bytes() ?? Uint8List(0),
          _ => r.any(),
        });
