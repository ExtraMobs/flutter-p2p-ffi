// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/core/coreiface
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/boxo/files.dart' as $files;
import 'package:ipfs_ffi/boxo/path.dart' as $path;
import 'package:ipfs_ffi/context.dart' as $context;
import 'package:ipfs_ffi/go_cid.dart' as $go_cid;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as $options;

/// Go: `iface.CoreAPI` (handle).
class CoreApi extends GoHandle {
  CoreApi.$h(super.$h);

  /// Go: `func (iface.CoreAPI).Unixfs() iface.UnixfsAPI`.
  UnixfsApi unixfs() {
    final $r =
        $callSync('github.com/ipfs/kubo/core/coreiface.CoreAPI.Unixfs', [this]);
    return UnixfsApi.$h($nn($r) as int);
  }

  /// Go: `func (iface.CoreAPI).ResolvePath(context.Context, path.Path) (path.ImmutablePath, []string, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<($path.ImmutablePath, List<String>)> resolvePath(
      $context.Context ctx, $path.Path path) async {
    final $l = await $call(
        'github.com/ipfs/kubo/core/coreiface.CoreAPI.ResolvePath',
        [this, ctx, path]) as List;
    return (
      $path.ImmutablePath($nn($l[0]) as String),
      [for (final e0 in $l[1] as List) e0 as String]
    );
  }
}

/// Go: `iface.DirEntry`.
final class DirEntry implements GoJson {
  DirEntry(
      {String? name,
      $go_cid.Cid? cid,
      int? size,
      int? type,
      String? target,
      int? mode,
      DateTime? modTime})
      : name = name ?? '',
        cid = cid,
        size = size ?? 0,
        type = type ?? 0,
        target = target ?? '',
        mode = mode ?? 0,
        modTime = modTime;

  DirEntry.$fromJson(Map<String, Object?> j)
      : name = j['Name'] as String,
        cid = j['Cid'] == null ? null : $go_cid.Cid(j['Cid'] as String),
        size = j['Size'] as int,
        type = j['Type'] as int,
        target = j['Target'] as String,
        mode = j['Mode'] as int,
        modTime = j['ModTime'] == null
            ? null
            : DateTime.parse(j['ModTime'] as String);

  /// Go: `Name`.
  String name;

  /// Go: `Cid`.
  $go_cid.Cid? cid;

  /// Go: `Size`.
  int size;

  /// Go: `Type`.
  int type;

  /// Go: `Target`.
  String target;

  /// Go: `Mode`.
  int mode;

  /// Go: `ModTime`.
  DateTime? modTime;

  @override
  Map<String, Object?> $toJson() => {
        'Name': $enc(name),
        'Cid': $enc(cid),
        'Size': $enc(size),
        'Type': $enc(type),
        'Target': $enc(target),
        'Mode': $enc(mode),
        'ModTime': $enc(modTime)
      };
}

/// Go: `iface.UnixfsAPI` (handle).
class UnixfsApi extends GoHandle {
  UnixfsApi.$h(super.$h);

  /// Go: `func (iface.UnixfsAPI).Add(context.Context, files.Node, ...options.UnixfsAddOption) (path.ImmutablePath, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<$path.ImmutablePath> add($context.Context ctx, $files.Node node,
      [List<$options.UnixfsAddOption> opts = const []]) async {
    final $r = await $call('github.com/ipfs/kubo/core/coreiface.UnixfsAPI.Add',
        [this, ctx, node, opts]);
    return $path.ImmutablePath($nn($r) as String);
  }

  /// Go: `func (iface.UnixfsAPI).Get(context.Context, path.Path) (files.Node, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<$files.Node> get($context.Context ctx, $path.Path path) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.UnixfsAPI.Get', [this, ctx, path]);
    return $files.Node.$h($nn($r) as int);
  }

  /// Go: `func (iface.UnixfsAPI).Ls(context.Context, path.Path, chan<- iface.DirEntry, ...options.UnixfsLsOption) error`.
  Stream<DirEntry> ls($context.Context ctx, $path.Path path,
          [List<$options.UnixfsLsOption> opts = const []]) =>
      $stream('github.com/ipfs/kubo/core/coreiface.UnixfsAPI.Ls', [
        this,
        ctx,
        path,
        opts
      ]).map((r) => DirEntry.$fromJson(r as Map<String, Object?>));
}
