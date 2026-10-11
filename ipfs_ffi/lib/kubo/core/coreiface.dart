// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/core/coreiface
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/boxo/files.dart' as $files;
import 'package:ipfs_ffi/boxo/path.dart' as $path;
import 'package:ipfs_ffi/context.dart' as $context;
import 'package:ipfs_ffi/go_cid.dart' as $go_cid;
import 'package:ipfs_ffi/io.dart' as $io;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as $options;

/// Go: `iface.BadPinNode` (valores lidos dos métodos).
final class BadPinNode {
  BadPinNode.$fromJson(Map<String, Object?> j)
      : err = j['Err'] == null ? null : j['Err'] as String,
        path =
            j['Path'] == null ? null : $path.ImmutablePath(j['Path'] as String);

  /// Go: `Err()`.
  final String? err;

  /// Go: `Path()`.
  final $path.ImmutablePath? path;
}

/// Go: `iface.BlockAPI` (handle).
class BlockApi extends GoHandle {
  BlockApi.$h(super.$h);

  /// Go: `func (iface.BlockAPI).Put(context.Context, io.Reader, ...options.BlockPutOption) (iface.BlockStat, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<BlockStat> put($context.Context ctx, Object reader,
      [List<$options.BlockPutOption> opts = const []]) async {
    final $r = await $call('github.com/ipfs/kubo/core/coreiface.BlockAPI.Put',
        [this, ctx, reader, opts]);
    return BlockStat.$fromJson($nn($r) as Map<String, Object?>);
  }

  /// Go: `func (iface.BlockAPI).Get(context.Context, path.Path) (io.Reader, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<$io.Reader> get($context.Context ctx, $path.Path path) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.BlockAPI.Get', [this, ctx, path]);
    return $io.Reader.$h($nn($r) as int);
  }

  /// Go: `func (iface.BlockAPI).Rm(context.Context, path.Path, ...options.BlockRmOption) error`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<void> rm($context.Context ctx, $path.Path path,
      [List<$options.BlockRmOption> opts = const []]) async {
    await $call('github.com/ipfs/kubo/core/coreiface.BlockAPI.Rm',
        [this, ctx, path, opts]);
  }

  /// Go: `func (iface.BlockAPI).Stat(context.Context, path.Path) (iface.BlockStat, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<BlockStat> stat($context.Context ctx, $path.Path path) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.BlockAPI.Stat', [this, ctx, path]);
    return BlockStat.$fromJson($nn($r) as Map<String, Object?>);
  }
}

/// Go: `iface.BlockStat` (valores lidos dos métodos).
final class BlockStat {
  BlockStat.$fromJson(Map<String, Object?> j)
      : path =
            j['Path'] == null ? null : $path.ImmutablePath(j['Path'] as String),
        size = j['Size'] as int;

  /// Go: `Path()`.
  final $path.ImmutablePath? path;

  /// Go: `Size()`.
  final int size;
}

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

  /// Go: `func (iface.CoreAPI).Pin() iface.PinAPI`.
  PinApi pin() {
    final $r =
        $callSync('github.com/ipfs/kubo/core/coreiface.CoreAPI.Pin', [this]);
    return PinApi.$h($nn($r) as int);
  }

  /// Go: `func (iface.CoreAPI).Block() iface.BlockAPI`.
  BlockApi block() {
    final $r =
        $callSync('github.com/ipfs/kubo/core/coreiface.CoreAPI.Block', [this]);
    return BlockApi.$h($nn($r) as int);
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

/// Go: `iface.Pin` (valores lidos dos métodos).
final class Pin {
  Pin.$fromJson(Map<String, Object?> j)
      : name = j['Name'] as String,
        path =
            j['Path'] == null ? null : $path.ImmutablePath(j['Path'] as String),
        type = j['Type'] as String;

  /// Go: `Name()`.
  final String name;

  /// Go: `Path()`.
  final $path.ImmutablePath? path;

  /// Go: `Type()`.
  final String type;
}

/// Go: `iface.PinAPI` (handle).
class PinApi extends GoHandle {
  PinApi.$h(super.$h);

  /// Go: `func (iface.PinAPI).Add(context.Context, path.Path, ...options.PinAddOption) error`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<void> add($context.Context ctx, $path.Path path,
      [List<$options.PinAddOption> opts = const []]) async {
    await $call('github.com/ipfs/kubo/core/coreiface.PinAPI.Add',
        [this, ctx, path, opts]);
  }

  /// Go: `func (iface.PinAPI).Ls(context.Context, chan<- iface.Pin, ...options.PinLsOption) error`.
  Stream<Pin> ls($context.Context ctx,
          [List<$options.PinLsOption> opts = const []]) =>
      $stream('github.com/ipfs/kubo/core/coreiface.PinAPI.Ls', [
        this,
        ctx,
        opts
      ]).map((r) => Pin.$fromJson(r as Map<String, Object?>));

  /// Go: `func (iface.PinAPI).IsPinned(context.Context, path.Path, ...options.PinIsPinnedOption) (string, bool, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<(String, bool)> isPinned($context.Context ctx, $path.Path path,
      [List<$options.PinIsPinnedOption> opts = const []]) async {
    final $l = await $call(
        'github.com/ipfs/kubo/core/coreiface.PinAPI.IsPinned',
        [this, ctx, path, opts]) as List;
    return ($l[0] as String, $l[1] as bool);
  }

  /// Go: `func (iface.PinAPI).Rm(context.Context, path.Path, ...options.PinRmOption) error`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<void> rm($context.Context ctx, $path.Path path,
      [List<$options.PinRmOption> opts = const []]) async {
    await $call('github.com/ipfs/kubo/core/coreiface.PinAPI.Rm',
        [this, ctx, path, opts]);
  }

  /// Go: `func (iface.PinAPI).Update(ctx context.Context, from path.Path, to path.Path, opts ...options.PinUpdateOption) error`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<void> update($context.Context ctx, $path.Path from, $path.Path to,
      [List<$options.PinUpdateOption> opts = const []]) async {
    await $call('github.com/ipfs/kubo/core/coreiface.PinAPI.Update',
        [this, ctx, from, to, opts]);
  }

  /// Go: `func (iface.PinAPI).Verify(context.Context) (<-chan iface.PinStatus, error)`.
  Stream<PinStatus> verify($context.Context ctx) =>
      $stream('github.com/ipfs/kubo/core/coreiface.PinAPI.Verify', [this, ctx])
          .map((r) => PinStatus.$fromJson(r as Map<String, Object?>));
}

/// Go: `iface.PinStatus` (valores lidos dos métodos).
final class PinStatus {
  PinStatus.$fromJson(Map<String, Object?> j)
      : badNodes = [
          for (final e0 in j['BadNodes'] as List)
            BadPinNode.$fromJson(e0 as Map<String, Object?>)
        ],
        err = j['Err'] == null ? null : j['Err'] as String,
        ok = j['Ok'] as bool;

  /// Go: `BadNodes()`.
  final List<BadPinNode> badNodes;

  /// Go: `Err()`.
  final String? err;

  /// Go: `Ok()`.
  final bool ok;
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
