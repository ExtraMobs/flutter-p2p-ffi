// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/core/coreiface/options
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/boxo/namesys.dart' as $namesys;

/// Go: `options.ApiOption` (opção funcional; construtores nas variáveis do pacote).
final class ApiOption extends GoOption {
  ApiOption.$(super.p, super.a);
}

/// Go: `options.BlockPutOption` (opção funcional; construtores nas variáveis do pacote).
final class BlockPutOption extends GoOption {
  BlockPutOption.$(super.p, super.a);
}

/// Go: `options.BlockRmOption` (opção funcional; construtores nas variáveis do pacote).
final class BlockRmOption extends GoOption {
  BlockRmOption.$(super.p, super.a);
}

/// Go: `options.KeyGenerateOption` (opção funcional; construtores nas variáveis do pacote).
final class KeyGenerateOption extends GoOption {
  KeyGenerateOption.$(super.p, super.a);
}

/// Go: `options.KeyRenameOption` (opção funcional; construtores nas variáveis do pacote).
final class KeyRenameOption extends GoOption {
  KeyRenameOption.$(super.p, super.a);
}

/// Go: `options.NamePublishOption` (opção funcional; construtores nas variáveis do pacote).
final class NamePublishOption extends GoOption {
  NamePublishOption.$(super.p, super.a);
}

/// Go: `options.NameResolveOption` (opção funcional; construtores nas variáveis do pacote).
final class NameResolveOption extends GoOption {
  NameResolveOption.$(super.p, super.a);
}

/// Go: `options.PinAddOption` (opção funcional; construtores nas variáveis do pacote).
final class PinAddOption extends GoOption {
  PinAddOption.$(super.p, super.a);
}

/// Go: `options.PinIsPinnedOption` (opção funcional; construtores nas variáveis do pacote).
final class PinIsPinnedOption extends GoOption {
  PinIsPinnedOption.$(super.p, super.a);
}

/// Go: `options.PinLsOption` (opção funcional; construtores nas variáveis do pacote).
final class PinLsOption extends GoOption {
  PinLsOption.$(super.p, super.a);
}

/// Go: `options.PinRmOption` (opção funcional; construtores nas variáveis do pacote).
final class PinRmOption extends GoOption {
  PinRmOption.$(super.p, super.a);
}

/// Go: `options.PinUpdateOption` (opção funcional; construtores nas variáveis do pacote).
final class PinUpdateOption extends GoOption {
  PinUpdateOption.$(super.p, super.a);
}

/// Go: `options.RoutingFindProvidersOption` (opção funcional; construtores nas variáveis do pacote).
final class RoutingFindProvidersOption extends GoOption {
  RoutingFindProvidersOption.$(super.p, super.a);
}

/// Go: `options.RoutingProvideOption` (opção funcional; construtores nas variáveis do pacote).
final class RoutingProvideOption extends GoOption {
  RoutingProvideOption.$(super.p, super.a);
}

/// Go: `options.UnixfsAddOption` (opção funcional; construtores nas variáveis do pacote).
final class UnixfsAddOption extends GoOption {
  UnixfsAddOption.$(super.p, super.a);
}

/// Go: `options.UnixfsLsOption` (opção funcional; construtores nas variáveis do pacote).
final class UnixfsLsOption extends GoOption {
  UnixfsLsOption.$(super.p, super.a);
}

/// Go: `var Api`: construtores de opções.
const api = _Api._();

final class _Api {
  const _Api._();

  /// Go: `options.Api.FetchBlocks`.
  ApiOption fetchBlocks(bool fetch) => ApiOption.$('Api.FetchBlocks', [fetch]);

  /// Go: `options.Api.Offline`.
  ApiOption offline(bool offline) => ApiOption.$('Api.Offline', [offline]);
}

/// Go: `var Block`: construtores de opções.
const block = _Block._();

final class _Block {
  const _Block._();

  /// Go: `options.Block.CidCodec`.
  BlockPutOption cidCodec(String codecName) =>
      BlockPutOption.$('Block.CidCodec', [codecName]);

  /// Go: `options.Block.Force`.
  BlockRmOption force(bool force) => BlockRmOption.$('Block.Force', [force]);

  /// Go: `options.Block.Format`.
  BlockPutOption format(String format) =>
      BlockPutOption.$('Block.Format', [format]);

  /// Go: `options.Block.Hash`.
  BlockPutOption hash(int mhType, int mhLen) =>
      BlockPutOption.$('Block.Hash', [mhType, mhLen]);

  /// Go: `options.Block.Pin`.
  BlockPutOption pin(bool pin) => BlockPutOption.$('Block.Pin', [pin]);
}

/// Go: `var Dht`: construtores de opções.
const dht = _Dht._();

final class _Dht {
  const _Dht._();

  /// Go: `options.Dht.NumProviders`.
  RoutingFindProvidersOption numProviders(int numProviders) =>
      RoutingFindProvidersOption.$('Dht.NumProviders', [numProviders]);

  /// Go: `options.Dht.Recursive`.
  RoutingProvideOption recursive(bool recursive) =>
      RoutingProvideOption.$('Dht.Recursive', [recursive]);
}

/// Go: `var Key`: construtores de opções.
const key = _Key._();

final class _Key {
  const _Key._();

  /// Go: `options.Key.Force`.
  KeyRenameOption force(bool force) => KeyRenameOption.$('Key.Force', [force]);

  /// Go: `options.Key.Size`.
  KeyGenerateOption size(int size) => KeyGenerateOption.$('Key.Size', [size]);

  /// Go: `options.Key.Type`.
  KeyGenerateOption type(String algorithm) =>
      KeyGenerateOption.$('Key.Type', [algorithm]);
}

/// Go: `var Name`: construtores de opções.
const name = _Name._();

final class _Name {
  const _Name._();

  /// Go: `options.Name.AllowDelegated`.
  NamePublishOption allowDelegated(bool allowDelegated) =>
      NamePublishOption.$('Name.AllowDelegated', [allowDelegated]);

  /// Go: `options.Name.AllowOffline`.
  NamePublishOption allowOffline(bool allow) =>
      NamePublishOption.$('Name.AllowOffline', [allow]);

  /// Go: `options.Name.Cache`.
  NameResolveOption cache(bool cache) =>
      NameResolveOption.$('Name.Cache', [cache]);

  /// Go: `options.Name.CompatibleWithV1`.
  NamePublishOption compatibleWithV1(bool compatible) =>
      NamePublishOption.$('Name.CompatibleWithV1', [compatible]);

  /// Go: `options.Name.Key`.
  NamePublishOption key(String key) => NamePublishOption.$('Name.Key', [key]);

  /// Go: `options.Name.ResolveOption`.
  NameResolveOption resolveOption($namesys.ResolveOption opt) =>
      NameResolveOption.$('Name.ResolveOption', [opt]);

  /// Go: `options.Name.Sequence`.
  NamePublishOption sequence(int seq) =>
      NamePublishOption.$('Name.Sequence', [seq]);

  /// Go: `options.Name.TTL`.
  NamePublishOption ttl(int ttl) => NamePublishOption.$('Name.TTL', [ttl]);

  /// Go: `options.Name.ValidTime`.
  NamePublishOption validTime(int validTime) =>
      NamePublishOption.$('Name.ValidTime', [validTime]);
}

/// Go: `var Pin`: construtores de opções.
const pin = _Pin._();

final class _Pin {
  const _Pin._();

  /// Go: `Pin.IsPinned`.
  final isPinned = const _PinIsPinned._();

  /// Go: `Pin.Ls`.
  final ls = const _PinLs._();

  /// Go: `options.Pin.Name`.
  PinAddOption name(String name) => PinAddOption.$('Pin.Name', [name]);

  /// Go: `options.Pin.Recursive`.
  PinAddOption recursive(bool recursive) =>
      PinAddOption.$('Pin.Recursive', [recursive]);

  /// Go: `options.Pin.RmRecursive`.
  PinRmOption rmRecursive(bool recursive) =>
      PinRmOption.$('Pin.RmRecursive', [recursive]);

  /// Go: `options.Pin.Unpin`.
  PinUpdateOption unpin(bool unpin) => PinUpdateOption.$('Pin.Unpin', [unpin]);
}

final class _PinIsPinned {
  const _PinIsPinned._();

  /// Go: `options.Pin.IsPinned.All`.
  PinIsPinnedOption all() => PinIsPinnedOption.$('Pin.IsPinned.All', []);

  /// Go: `options.Pin.IsPinned.Direct`.
  PinIsPinnedOption direct() => PinIsPinnedOption.$('Pin.IsPinned.Direct', []);

  /// Go: `options.Pin.IsPinned.Indirect`.
  PinIsPinnedOption indirect() =>
      PinIsPinnedOption.$('Pin.IsPinned.Indirect', []);

  /// Go: `options.Pin.IsPinned.Recursive`.
  PinIsPinnedOption recursive() =>
      PinIsPinnedOption.$('Pin.IsPinned.Recursive', []);

  /// Go: `options.Pin.IsPinned.Type`.
  PinIsPinnedOption type(String typeStr) =>
      PinIsPinnedOption.$('Pin.IsPinned.Type', [typeStr]);
}

final class _PinLs {
  const _PinLs._();

  /// Go: `options.Pin.Ls.All`.
  PinLsOption all() => PinLsOption.$('Pin.Ls.All', []);

  /// Go: `options.Pin.Ls.Detailed`.
  PinLsOption detailed(bool detailed) =>
      PinLsOption.$('Pin.Ls.Detailed', [detailed]);

  /// Go: `options.Pin.Ls.Direct`.
  PinLsOption direct() => PinLsOption.$('Pin.Ls.Direct', []);

  /// Go: `options.Pin.Ls.Indirect`.
  PinLsOption indirect() => PinLsOption.$('Pin.Ls.Indirect', []);

  /// Go: `options.Pin.Ls.Name`.
  PinLsOption name(String name) => PinLsOption.$('Pin.Ls.Name', [name]);

  /// Go: `options.Pin.Ls.Recursive`.
  PinLsOption recursive() => PinLsOption.$('Pin.Ls.Recursive', []);

  /// Go: `options.Pin.Ls.Type`.
  PinLsOption type(String typeStr) => PinLsOption.$('Pin.Ls.Type', [typeStr]);
}

/// Go: `var Put`: construtores de opções.
const put = _Put._();

final class _Put {
  const _Put._();

  /// Go: `options.Put.NumProviders`.
  RoutingFindProvidersOption numProviders(int numProviders) =>
      RoutingFindProvidersOption.$('Put.NumProviders', [numProviders]);

  /// Go: `options.Put.Recursive`.
  RoutingProvideOption recursive(bool recursive) =>
      RoutingProvideOption.$('Put.Recursive', [recursive]);
}

/// Go: `var Routing`: construtores de opções.
const routing = _Routing._();

final class _Routing {
  const _Routing._();

  /// Go: `options.Routing.NumProviders`.
  RoutingFindProvidersOption numProviders(int numProviders) =>
      RoutingFindProvidersOption.$('Routing.NumProviders', [numProviders]);

  /// Go: `options.Routing.Recursive`.
  RoutingProvideOption recursive(bool recursive) =>
      RoutingProvideOption.$('Routing.Recursive', [recursive]);
}

/// Go: `var Unixfs`: construtores de opções.
const unixfs = _Unixfs._();

final class _Unixfs {
  const _Unixfs._();

  /// Go: `options.Unixfs.Chunker`.
  UnixfsAddOption chunker(String chunker) =>
      UnixfsAddOption.$('Unixfs.Chunker', [chunker]);

  /// Go: `options.Unixfs.CidVersion`.
  UnixfsAddOption cidVersion(int version) =>
      UnixfsAddOption.$('Unixfs.CidVersion', [version]);

  /// Go: `options.Unixfs.FsCache`.
  UnixfsAddOption fsCache(bool enable) =>
      UnixfsAddOption.$('Unixfs.FsCache', [enable]);

  /// Go: `options.Unixfs.HashOnly`.
  UnixfsAddOption hashOnly(bool hashOnly) =>
      UnixfsAddOption.$('Unixfs.HashOnly', [hashOnly]);

  /// Go: `options.Unixfs.Hash`.
  UnixfsAddOption hash(int mhtype) =>
      UnixfsAddOption.$('Unixfs.Hash', [mhtype]);

  /// Go: `options.Unixfs.IncludeEmptyDirs`.
  UnixfsAddOption includeEmptyDirs(bool include) =>
      UnixfsAddOption.$('Unixfs.IncludeEmptyDirs', [include]);

  /// Go: `options.Unixfs.InlineLimit`.
  UnixfsAddOption inlineLimit(int limit) =>
      UnixfsAddOption.$('Unixfs.InlineLimit', [limit]);

  /// Go: `options.Unixfs.Inline`.
  UnixfsAddOption inline(bool enable) =>
      UnixfsAddOption.$('Unixfs.Inline', [enable]);

  /// Go: `options.Unixfs.Layout`.
  UnixfsAddOption layout(int layout) =>
      UnixfsAddOption.$('Unixfs.Layout', [layout]);

  /// Go: `options.Unixfs.MaxDirectoryLinks`.
  UnixfsAddOption maxDirectoryLinks(int n) =>
      UnixfsAddOption.$('Unixfs.MaxDirectoryLinks', [n]);

  /// Go: `options.Unixfs.MaxFileLinks`.
  UnixfsAddOption maxFileLinks(int n) =>
      UnixfsAddOption.$('Unixfs.MaxFileLinks', [n]);

  /// Go: `options.Unixfs.MaxHAMTFanout`.
  UnixfsAddOption maxHamtFanout(int n) =>
      UnixfsAddOption.$('Unixfs.MaxHAMTFanout', [n]);

  /// Go: `options.Unixfs.Mode`.
  UnixfsAddOption mode(int mode) => UnixfsAddOption.$('Unixfs.Mode', [mode]);

  /// Go: `options.Unixfs.Mtime`.
  UnixfsAddOption mtime(int seconds, int nsecs) =>
      UnixfsAddOption.$('Unixfs.Mtime', [seconds, nsecs]);

  /// Go: `options.Unixfs.Nocopy`.
  UnixfsAddOption nocopy(bool enable) =>
      UnixfsAddOption.$('Unixfs.Nocopy', [enable]);

  /// Go: `options.Unixfs.Pin`.
  UnixfsAddOption pin(bool pin, String pinName) =>
      UnixfsAddOption.$('Unixfs.Pin', [pin, pinName]);

  /// Go: `options.Unixfs.PreserveMode`.
  UnixfsAddOption preserveMode(bool enable) =>
      UnixfsAddOption.$('Unixfs.PreserveMode', [enable]);

  /// Go: `options.Unixfs.PreserveMtime`.
  UnixfsAddOption preserveMtime(bool enable) =>
      UnixfsAddOption.$('Unixfs.PreserveMtime', [enable]);

  /// Go: `options.Unixfs.Progress`.
  UnixfsAddOption progress(bool enable) =>
      UnixfsAddOption.$('Unixfs.Progress', [enable]);

  /// Go: `options.Unixfs.RawLeaves`.
  UnixfsAddOption rawLeaves(bool enable) =>
      UnixfsAddOption.$('Unixfs.RawLeaves', [enable]);

  /// Go: `options.Unixfs.ResolveChildren`.
  UnixfsLsOption resolveChildren(bool resolve) =>
      UnixfsLsOption.$('Unixfs.ResolveChildren', [resolve]);

  /// Go: `options.Unixfs.Silent`.
  UnixfsAddOption silent(bool silent) =>
      UnixfsAddOption.$('Unixfs.Silent', [silent]);

  /// Go: `options.Unixfs.SizeEstimationMode`.
  UnixfsAddOption sizeEstimationMode(int mode) =>
      UnixfsAddOption.$('Unixfs.SizeEstimationMode', [mode]);

  /// Go: `options.Unixfs.UseCumulativeSize`.
  UnixfsLsOption useCumulativeSize(bool use) =>
      UnixfsLsOption.$('Unixfs.UseCumulativeSize', [use]);
}
