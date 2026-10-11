// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/core/coreiface/options
library;

import 'package:ipfs_ffi/src/runtime.dart';

/// Go: `options.ApiOption` (opção funcional; construtores nas variáveis do pacote).
final class ApiOption extends GoOption {
  ApiOption.$(super.p, super.a);
}

/// Go: `options.KeyGenerateOption` (opção funcional; construtores nas variáveis do pacote).
final class KeyGenerateOption extends GoOption {
  KeyGenerateOption.$(super.p, super.a);
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

/// Go: `var Key`: construtores de opções.
const key = _Key._();

final class _Key {
  const _Key._();

  /// Go: `options.Key.Size`.
  KeyGenerateOption size(int size) => KeyGenerateOption.$('Key.Size', [size]);

  /// Go: `options.Key.Type`.
  KeyGenerateOption type(String algorithm) =>
      KeyGenerateOption.$('Key.Type', [algorithm]);
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
