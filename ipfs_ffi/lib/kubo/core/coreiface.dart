// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/core/coreiface
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/boxo/files.dart' as $files;
import 'package:ipfs_ffi/boxo/ipns.dart' as $ipns;
import 'package:ipfs_ffi/boxo/path.dart' as $path;
import 'package:ipfs_ffi/context.dart' as $context;
import 'package:ipfs_ffi/go_cid.dart' as $go_cid;
import 'package:ipfs_ffi/go_ipld_format.dart' as $go_ipld_format;
import 'package:ipfs_ffi/go_libp2p/core/peer.dart' as $peer;
import 'package:ipfs_ffi/go_multiaddr.dart' as $go_multiaddr;
import 'package:ipfs_ffi/io.dart' as $io;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as $options;

/// Go: `iface.APIDagService` (handle).
class ApiDagService extends $go_ipld_format.DagService {
  ApiDagService.$h(super.$h) : super.$h();

  /// Go: `func (format.NodeGetter).Get(context.Context, cid.Cid) (format.Node, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<$go_ipld_format.Node> get(
      $context.Context ctx, $go_cid.Cid cid) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.APIDagService.Get',
        [this, ctx, cid]);
    return $go_ipld_format.Node.$h($nn($r) as int);
  }

  /// Go: `func (format.NodeGetter).GetMany(context.Context, []cid.Cid) <-chan *format.NodeOption`.
  Stream<$go_ipld_format.NodeOption> getMany(
          $context.Context ctx, List<$go_cid.Cid> cids) =>
      $stream('github.com/ipfs/kubo/core/coreiface.APIDagService.GetMany', [
        this,
        ctx,
        cids
      ]).map((r) =>
          $go_ipld_format.NodeOption.$fromJson(r as Map<String, Object?>));

  /// Go: `func (format.NodeAdder).Add(context.Context, format.Node) error`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<void> add($context.Context ctx, $go_ipld_format.Node node) async {
    await $call('github.com/ipfs/kubo/core/coreiface.APIDagService.Add',
        [this, ctx, node]);
  }

  /// Go: `func (format.NodeAdder).AddMany(context.Context, []format.Node) error`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<void> addMany(
      $context.Context ctx, List<$go_ipld_format.Node> nodes) async {
    await $call('github.com/ipfs/kubo/core/coreiface.APIDagService.AddMany',
        [this, ctx, nodes]);
  }

  /// Go: `func (format.DAGService).Remove(context.Context, cid.Cid) error`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<void> remove($context.Context ctx, $go_cid.Cid cid) async {
    await $call('github.com/ipfs/kubo/core/coreiface.APIDagService.Remove',
        [this, ctx, cid]);
  }

  /// Go: `func (format.DAGService).RemoveMany(context.Context, []cid.Cid) error`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<void> removeMany($context.Context ctx, List<$go_cid.Cid> cids) async {
    await $call('github.com/ipfs/kubo/core/coreiface.APIDagService.RemoveMany',
        [this, ctx, cids]);
  }

  /// Go: `func (iface.APIDagService).Pinning() format.NodeAdder`.
  $go_ipld_format.NodeAdder pinning() {
    $check(_d22($h, $out));
    return $go_ipld_format.NodeAdder.$h($nnH($out.value));
  }
}

/// Go: `iface.AddEvent`.
final class AddEvent implements GoJson {
  AddEvent(
      {String? name,
      $path.ImmutablePath? path,
      int? bytes,
      String? size,
      int? mode,
      int? mtime,
      int? mtimeNsecs})
      : name = name ?? '',
        path = path,
        bytes = bytes ?? 0,
        size = size ?? '',
        mode = mode ?? 0,
        mtime = mtime ?? 0,
        mtimeNsecs = mtimeNsecs ?? 0;

  AddEvent.$fromJson(Map<String, Object?> j)
      : name = j['Name'] as String,
        path =
            j['Path'] == null ? null : $path.ImmutablePath(j['Path'] as String),
        bytes = j['Bytes'] as int,
        size = j['Size'] as String,
        mode = j['Mode'] as int,
        mtime = j['Mtime'] as int,
        mtimeNsecs = j['MtimeNsecs'] as int;

  /// Go: `Name`.
  String name;

  /// Go: `Path`.
  $path.ImmutablePath? path;

  /// Go: `Bytes`.
  int bytes;

  /// Go: `Size`.
  String size;

  /// Go: `Mode`.
  int mode;

  /// Go: `Mtime`.
  int mtime;

  /// Go: `MtimeNsecs`.
  int mtimeNsecs;

  @override
  Map<String, Object?> $toJson() => {
        'Name': $enc(name),
        'Path': $enc(path),
        'Bytes': $enc(bytes),
        'Size': $enc(size),
        'Mode': $enc(mode),
        'Mtime': $enc(mtime),
        'MtimeNsecs': $enc(mtimeNsecs)
      };
}

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

/// Go: `iface.ConnectionInfo` (valores lidos dos métodos).
final class ConnectionInfo {
  ConnectionInfo.$fromJson(Map<String, Object?> j)
      : address = j['Address'] == null
            ? null
            : $go_multiaddr.Multiaddr(j['Address'] as String),
        direction = j['Direction'] as int,
        id = j['ID'] == null ? null : $peer.Id(j['ID'] as String),
        latency = j['Latency'] == null ? null : j['Latency'] as int,
        streams = j['Streams'] == null
            ? null
            : [for (final e0 in j['Streams'] as List) e0 as String];

  /// Go: `Address()`.
  final $go_multiaddr.Multiaddr? address;

  /// Go: `Direction()`.
  final int direction;

  /// Go: `ID()`.
  final $peer.Id? id;

  /// Go: `Latency()`.
  final int? latency;

  /// Go: `Streams()`.
  final List<String>? streams;
}

/// Go: `iface.CoreAPI` (handle).
class CoreApi extends GoHandle {
  CoreApi.$h(super.$h);

  /// Go: `func (iface.CoreAPI).Unixfs() iface.UnixfsAPI`.
  UnixfsApi unixfs() {
    $check(_d5($h, $out));
    return UnixfsApi.$h($nnH($out.value));
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
    $check(_d11($h, $out));
    return PinApi.$h($nnH($out.value));
  }

  /// Go: `func (iface.CoreAPI).Block() iface.BlockAPI`.
  BlockApi block() {
    $check(_d12($h, $out));
    return BlockApi.$h($nnH($out.value));
  }

  /// Go: `func (iface.CoreAPI).Key() iface.KeyAPI`.
  KeyApi key() {
    $check(_d17($h, $out));
    return KeyApi.$h($nnH($out.value));
  }

  /// Go: `func (iface.CoreAPI).Swarm() iface.SwarmAPI`.
  SwarmApi swarm() {
    $check(_d18($h, $out));
    return SwarmApi.$h($nnH($out.value));
  }

  /// Go: `func (iface.CoreAPI).Routing() iface.RoutingAPI`.
  RoutingApi routing() {
    $check(_d19($h, $out));
    return RoutingApi.$h($nnH($out.value));
  }

  /// Go: `func (iface.CoreAPI).Name() iface.NameAPI`.
  NameApi name() {
    $check(_d20($h, $out));
    return NameApi.$h($nnH($out.value));
  }

  /// Go: `func (iface.CoreAPI).Dag() iface.APIDagService`.
  ApiDagService dag() {
    $check(_d21($h, $out));
    return ApiDagService.$h($nnH($out.value));
  }

  /// Go: `func (iface.CoreAPI).ResolveNode(context.Context, path.Path) (format.Node, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<$go_ipld_format.Node> resolveNode(
      $context.Context ctx, $path.Path path) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.CoreAPI.ResolveNode',
        [this, ctx, path]);
    return $go_ipld_format.Node.$h($nn($r) as int);
  }

  /// Go: `func (iface.CoreAPI).PubSub() iface.PubSubAPI`.
  PubSubApi pubSub() {
    $check(_d33($h, $out));
    return PubSubApi.$h($nnH($out.value));
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

/// Go: `iface.IpnsResult`.
final class IpnsResult implements GoJson {
  IpnsResult({$path.Path? path, String? err})
      : path = path,
        err = err;

  IpnsResult.$fromJson(Map<String, Object?> j)
      : path = j['Path'] == null ? null : $path.Path(j['Path'] as String),
        err = j['Err'] == null ? null : j['Err'] as String;

  /// Go: `Path`.
  $path.Path? path;

  /// Go: `Err`.
  String? err;

  @override
  Map<String, Object?> $toJson() => {'Path': $enc(path), 'Err': $enc(err)};
}

/// Go: `iface.Key` (valores lidos dos métodos).
final class Key {
  Key.$fromJson(Map<String, Object?> j)
      : id = j['ID'] == null ? null : $peer.Id(j['ID'] as String),
        name = j['Name'] as String,
        path = j['Path'] == null ? null : $path.Path(j['Path'] as String);

  /// Go: `ID()`.
  final $peer.Id? id;

  /// Go: `Name()`.
  final String name;

  /// Go: `Path()`.
  final $path.Path? path;
}

/// Go: `iface.KeyAPI` (handle).
class KeyApi extends GoHandle {
  KeyApi.$h(super.$h);

  /// Go: `func (iface.KeyAPI).Self(ctx context.Context) (iface.Key, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<Key> self($context.Context ctx) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.KeyAPI.Self', [this, ctx]);
    return Key.$fromJson($nn($r) as Map<String, Object?>);
  }

  /// Go: `func (iface.KeyAPI).Generate(ctx context.Context, name string, opts ...options.KeyGenerateOption) (iface.Key, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<Key> generate($context.Context ctx, String name,
      [List<$options.KeyGenerateOption> opts = const []]) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.KeyAPI.Generate',
        [this, ctx, name, opts]);
    return Key.$fromJson($nn($r) as Map<String, Object?>);
  }

  /// Go: `func (iface.KeyAPI).Rename(ctx context.Context, oldName string, newName string, opts ...options.KeyRenameOption) (iface.Key, bool, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<(Key, bool)> rename(
      $context.Context ctx, String oldName, String newName,
      [List<$options.KeyRenameOption> opts = const []]) async {
    final $l = await $call('github.com/ipfs/kubo/core/coreiface.KeyAPI.Rename',
        [this, ctx, oldName, newName, opts]) as List;
    return (Key.$fromJson($nn($l[0]) as Map<String, Object?>), $l[1] as bool);
  }

  /// Go: `func (iface.KeyAPI).List(ctx context.Context) ([]iface.Key, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<List<Key>> list($context.Context ctx) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.KeyAPI.List', [this, ctx]);
    return [
      for (final e0 in $r as List) Key.$fromJson(e0 as Map<String, Object?>)
    ];
  }

  /// Go: `func (iface.KeyAPI).Remove(ctx context.Context, name string) (iface.Key, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<Key> remove($context.Context ctx, String name) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.KeyAPI.Remove', [this, ctx, name]);
    return Key.$fromJson($nn($r) as Map<String, Object?>);
  }

  /// Go: `func (iface.KeyAPI).Sign(ctx context.Context, name string, data []byte) (iface.Key, []byte, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<(Key, Uint8List)> sign(
      $context.Context ctx, String name, Uint8List data) async {
    final $l = await $call('github.com/ipfs/kubo/core/coreiface.KeyAPI.Sign',
        [this, ctx, name, data]) as List;
    return (Key.$fromJson($nn($l[0]) as Map<String, Object?>), $bytes($l[1]));
  }

  /// Go: `func (iface.KeyAPI).Verify(ctx context.Context, keyOrName string, signature []byte, data []byte) (iface.Key, bool, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<(Key, bool)> verify($context.Context ctx, String keyOrName,
      Uint8List signature, Uint8List data) async {
    final $l = await $call('github.com/ipfs/kubo/core/coreiface.KeyAPI.Verify',
        [this, ctx, keyOrName, signature, data]) as List;
    return (Key.$fromJson($nn($l[0]) as Map<String, Object?>), $l[1] as bool);
  }
}

/// Go: `iface.NameAPI` (handle).
class NameApi extends GoHandle {
  NameApi.$h(super.$h);

  /// Go: `func (iface.NameAPI).Publish(ctx context.Context, path path.Path, opts ...options.NamePublishOption) (ipns.Name, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<$ipns.Name> publish($context.Context ctx, $path.Path path,
      [List<$options.NamePublishOption> opts = const []]) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.NameAPI.Publish',
        [this, ctx, path, opts]);
    return $ipns.Name($nn($r) as String);
  }

  /// Go: `func (iface.NameAPI).Resolve(ctx context.Context, name string, opts ...options.NameResolveOption) (path.Path, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<$path.Path> resolve($context.Context ctx, String name,
      [List<$options.NameResolveOption> opts = const []]) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.NameAPI.Resolve',
        [this, ctx, name, opts]);
    return $path.Path($nn($r) as String);
  }

  /// Go: `func (iface.NameAPI).Search(ctx context.Context, name string, opts ...options.NameResolveOption) (<-chan iface.IpnsResult, error)`.
  Stream<IpnsResult> search($context.Context ctx, String name,
          [List<$options.NameResolveOption> opts = const []]) =>
      $stream('github.com/ipfs/kubo/core/coreiface.NameAPI.Search', [
        this,
        ctx,
        name,
        opts
      ]).map((r) => IpnsResult.$fromJson(r as Map<String, Object?>));
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

/// Go: `iface.PubSubAPI` (handle).
class PubSubApi extends GoHandle {
  PubSubApi.$h(super.$h);

  /// Go: `func (iface.PubSubAPI).Ls(context.Context) ([]string, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<List<String>> ls($context.Context ctx) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.PubSubAPI.Ls', [this, ctx]);
    return [for (final e0 in $r as List) e0 as String];
  }

  /// Go: `func (iface.PubSubAPI).Peers(context.Context, ...options.PubSubPeersOption) ([]peer.ID, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<List<$peer.Id>> peers($context.Context ctx,
      [List<$options.PubSubPeersOption> opts = const []]) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.PubSubAPI.Peers',
        [this, ctx, opts]);
    return [for (final e0 in $r as List) $peer.Id(e0 as String)];
  }

  /// Go: `func (iface.PubSubAPI).Publish(context.Context, string, []byte) error`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<void> publish(
      $context.Context ctx, String topic, Uint8List data) async {
    await $call('github.com/ipfs/kubo/core/coreiface.PubSubAPI.Publish',
        [this, ctx, topic, data]);
  }

  /// Go: `func (iface.PubSubAPI).Subscribe(context.Context, string, ...options.PubSubSubscribeOption) (iface.PubSubSubscription, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<PubSubSubscription> subscribe($context.Context ctx, String topic,
      [List<$options.PubSubSubscribeOption> opts = const []]) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.PubSubAPI.Subscribe',
        [this, ctx, topic, opts]);
    return PubSubSubscription.$h($nn($r) as int);
  }
}

/// Go: `iface.PubSubMessage` (valores lidos dos métodos).
final class PubSubMessage {
  PubSubMessage.$fromJson(Map<String, Object?> j)
      : data = j['Data'] == null ? null : $bytes(j['Data']),
        from = j['From'] == null ? null : $peer.Id(j['From'] as String),
        seq = j['Seq'] == null ? null : $bytes(j['Seq']),
        topics = [for (final e0 in j['Topics'] as List) e0 as String];

  /// Go: `Data()`.
  final Uint8List? data;

  /// Go: `From()`.
  final $peer.Id? from;

  /// Go: `Seq()`.
  final Uint8List? seq;

  /// Go: `Topics()`.
  final List<String> topics;
}

/// Go: `iface.PubSubSubscription` (handle).
class PubSubSubscription extends $io.Closer {
  PubSubSubscription.$h(super.$h) : super.$h();

  /// Go: `func (iface.PubSubSubscription).Next(context.Context) (iface.PubSubMessage, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<PubSubMessage> next($context.Context ctx) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.PubSubSubscription.Next',
        [this, ctx]);
    return PubSubMessage.$fromJson($nn($r) as Map<String, Object?>);
  }

  /// Go: `func (io.Closer).Close() error`.
  void close() {
    $check(_d34($h, $out));
  }
}

/// Go: `iface.RoutingAPI` (handle).
class RoutingApi extends GoHandle {
  RoutingApi.$h(super.$h);

  /// Go: `func (iface.RoutingAPI).Provide(context.Context, path.Path, ...options.RoutingProvideOption) error`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<void> provide($context.Context ctx, $path.Path path,
      [List<$options.RoutingProvideOption> opts = const []]) async {
    await $call('github.com/ipfs/kubo/core/coreiface.RoutingAPI.Provide',
        [this, ctx, path, opts]);
  }

  /// Go: `func (iface.RoutingAPI).FindProviders(context.Context, path.Path, ...options.RoutingFindProvidersOption) (<-chan peer.AddrInfo, error)`.
  Stream<$peer.AddrInfo> findProviders($context.Context ctx, $path.Path path,
          [List<$options.RoutingFindProvidersOption> opts = const []]) =>
      $stream('github.com/ipfs/kubo/core/coreiface.RoutingAPI.FindProviders', [
        this,
        ctx,
        path,
        opts
      ]).map((r) => $peer.AddrInfo.$fromJson(r as Map<String, Object?>));

  /// Go: `func (iface.RoutingAPI).FindPeer(context.Context, peer.ID) (peer.AddrInfo, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<$peer.AddrInfo> findPeer($context.Context ctx, $peer.Id id) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.RoutingAPI.FindPeer',
        [this, ctx, id]);
    return $peer.AddrInfo.$fromJson($nn($r) as Map<String, Object?>);
  }
}

/// Go: `iface.SwarmAPI` (handle).
class SwarmApi extends GoHandle {
  SwarmApi.$h(super.$h);

  /// Go: `func (iface.SwarmAPI).Connect(context.Context, peer.AddrInfo) error`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<void> connect($context.Context ctx, $peer.AddrInfo addrInfo) async {
    await $call('github.com/ipfs/kubo/core/coreiface.SwarmAPI.Connect',
        [this, ctx, addrInfo]);
  }

  /// Go: `func (iface.SwarmAPI).Disconnect(context.Context, multiaddr.Multiaddr) error`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<void> disconnect(
      $context.Context ctx, $go_multiaddr.Multiaddr multiaddr) async {
    await $call('github.com/ipfs/kubo/core/coreiface.SwarmAPI.Disconnect',
        [this, ctx, multiaddr]);
  }

  /// Go: `func (iface.SwarmAPI).Peers(context.Context) ([]iface.ConnectionInfo, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<List<ConnectionInfo>> peers($context.Context ctx) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.SwarmAPI.Peers', [this, ctx]);
    return [
      for (final e0 in $r as List)
        ConnectionInfo.$fromJson(e0 as Map<String, Object?>)
    ];
  }

  /// Go: `func (iface.SwarmAPI).ListenAddrs(context.Context) ([]multiaddr.Multiaddr, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<List<$go_multiaddr.Multiaddr>> listenAddrs(
      $context.Context ctx) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.SwarmAPI.ListenAddrs',
        [this, ctx]);
    return [for (final e0 in $r as List) $go_multiaddr.Multiaddr(e0 as String)];
  }

  /// Go: `func (iface.SwarmAPI).LocalAddrs(context.Context) ([]multiaddr.Multiaddr, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<List<$go_multiaddr.Multiaddr>> localAddrs($context.Context ctx) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.SwarmAPI.LocalAddrs', [this, ctx]);
    return [for (final e0 in $r as List) $go_multiaddr.Multiaddr(e0 as String)];
  }

  /// Go: `func (iface.SwarmAPI).KnownAddrs(context.Context) (map[peer.ID][]multiaddr.Multiaddr, error)`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<Map<$peer.Id, List<$go_multiaddr.Multiaddr>>> knownAddrs(
      $context.Context ctx) async {
    final $r = await $call(
        'github.com/ipfs/kubo/core/coreiface.SwarmAPI.KnownAddrs', [this, ctx]);
    return {
      for (final e0 in ($r as Map<String, Object?>).entries)
        $peer.Id(e0.key): [
          for (final e1 in e0.value as List)
            $go_multiaddr.Multiaddr(e1 as String)
        ]
    };
  }
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

// Exports diretos (sem JSON) usados acima.
final _d22 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD22');
final _d5 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD5');
final _d11 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD11');
final _d12 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD12');
final _d17 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD17');
final _d18 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD18');
final _d19 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD19');
final _d20 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD20');
final _d21 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD21');
final _d33 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD33');
final _d34 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD34');
