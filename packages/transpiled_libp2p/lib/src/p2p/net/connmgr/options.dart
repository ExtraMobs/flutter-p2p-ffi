// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p/p2p/net/connmgr/options.go.
part of 'connmgr.dart';

/// The configuration struct for the basic connection manager.
///
/// Go: the unexported `config` struct (`options.go:11-18`). It stays private
/// here for the same reason it is unexported there.
class _Config {
  _Config({
    required this.highWater,
    required this.lowWater,
    required this.gracePeriod,
    required this.silencePeriod,
    required this.clock,
    this.decayer,
  });

  int highWater;
  int lowWater;
  Duration gracePeriod;
  Duration silencePeriod;
  DecayerCfg? decayer;
  Clock clock;
}

/// An option for the basic connection manager.
///
/// Go: `Option` (`options.go:21`), declared as `func(*config) error` over an
/// unexported `config`. Dart cannot express a public typedef over a private
/// type without exposing it, so the function is wrapped in an opaque value
/// instead. An option that rejects its argument throws, which is this port's
/// standing translation of Go's `(value, error)`.
class Option {
  const Option._(this._apply);

  final void Function(_Config cfg) _apply;
}

/// Applies a configuration for the decayer.
///
/// Go: `DecayerConfig` (`options.go:24-29`).
Option decayerConfig(DecayerCfg opts) => Option._((cfg) => cfg.decayer = opts);

/// Sets the internal clock implementation.
///
/// Go: `WithClock` (`options.go:32-37`).
Option withClock(Clock c) => Option._((cfg) => cfg.clock = c);

/// Sets the grace period, the time a newly opened connection is given before
/// it becomes subject to pruning.
///
/// Throws [ArgumentError] for a negative period, where Go returns
/// `errors.New("grace period must be non-negative")`.
///
/// Go: `WithGracePeriod` (`options.go:42-50`).
Option withGracePeriod(Duration p) => Option._((cfg) {
  if (p < Duration.zero) {
    throw ArgumentError.value(p, 'p', 'grace period must be non-negative');
  }
  cfg.gracePeriod = p;
});

/// Sets the silence period. The connection manager performs a cleanup once per
/// silence period if the number of connections surpasses the high watermark.
///
/// Throws [ArgumentError] for a non-positive period, where Go returns
/// `errors.New("silence period must be non-zero")`.
///
/// Go: `WithSilencePeriod` (`options.go:55-63`).
Option withSilencePeriod(Duration p) => Option._((cfg) {
  if (p <= Duration.zero) {
    throw ArgumentError.value(p, 'p', 'silence period must be non-zero');
  }
  cfg.silencePeriod = p;
});
