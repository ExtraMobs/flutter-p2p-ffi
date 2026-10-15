part of '../runtime.dart';

/// Function 36 (WIRE.md, "Commands"): runs a command of kubo's command tree
/// (the RPC's `/api/v0`) in the ipfs_host, with the app's node.
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

Never _unexpected(String path, int tag, $R r) => throw IpfsException(
    'ipfs $path emitted ${tag == _cmdBytes ? 'bytes' : '${r.any()}'}, '
    'not its declared type');

/// A command that emits one value of its declared type.
Future<T> $cmdOne<T>(
    GoHandle node,
    GoHandle ctx,
    String path,
    List<String> args,
    List<GoHandle> files,
    Map<String, Object?> opts,
    T Function($R r) dec) async {
  late T out;
  var got = false;
  await for (final r in _command(node, ctx, path, args, files, opts)) {
    final tag = r.u8();
    if (tag != _cmdTyped) _unexpected(path, tag, r);
    if (got) {
      throw IpfsException('ipfs $path emitted more than one value '
          '(ipfs_ffi: it belongs in a Stream, see go/gen/commands.go)');
    }
    out = dec(r);
    got = true;
  }
  if (!got) throw IpfsException('ipfs $path emitted no value');
  return out;
}

/// A command that emits a sequence of values of its declared type.
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

/// A command without a declared type: null if it emits nothing, the value
/// (Object?, or bytes) if it emits one, the list if it emits several.
Future<Object?> $cmdDyn(GoHandle node, GoHandle ctx, String path,
    List<String> args, List<GoHandle> files, Map<String, Object?> opts) async {
  final out = await $cmdDynStream(node, ctx, path, args, files, opts).toList();
  return switch (out) { [] => null, [final v] => v, _ => out };
}

/// A command without a declared type that emits a sequence.
Stream<Object?> $cmdDynStream(GoHandle node, GoHandle ctx, String path,
        List<String> args, List<GoHandle> files, Map<String, Object?> opts) =>
    _command(node, ctx, path, args, files, opts).map((r) => switch (r.u8()) {
          _cmdBytes => r.bytes() ?? Uint8List(0),
          _ => r.any(),
        });
