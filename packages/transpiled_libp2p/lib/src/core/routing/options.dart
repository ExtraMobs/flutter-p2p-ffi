// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/core/routing/options.dart
//
// Port of go-libp2p's core/routing/options.go: the functional-options
// pattern used to configure a routing call (e.g. "allow expired values").
// Go's `Option` returns an error; this throws instead, matching the
// exception-based convention used throughout this package.

/// A single routing option, applied to [RoutingOptions]. Equivalent to
/// go-libp2p's `Option`.
typedef RoutingOption = void Function(RoutingOptions opts);

/// A set of routing options. Equivalent to go-libp2p's `Options`.
class RoutingOptions {
  /// Creates an empty options set.
  RoutingOptions();

  /// Allow expired values.
  bool expired = false;

  /// Operate offline (rely on cached/local data only).
  bool offline = false;

  /// Other (ValueStore-implementation-specific) options.
  Map<Object, Object>? other;

  /// Applies each of [options] in order.
  void apply(List<RoutingOption> options) {
    for (final option in options) {
      option(this);
    }
  }

  /// Converts this options set to a single [RoutingOption] that copies its
  /// state onto another [RoutingOptions].
  RoutingOption toOption() {
    return (opts) {
      opts.expired = expired;
      opts.offline = offline;
      opts.other = other == null ? null : Map.of(other!);
    };
  }
}

/// Tells the routing system to return expired records when no newer
/// records are known. Equivalent to go-libp2p's `Expired`.
void expiredOption(RoutingOptions opts) => opts.expired = true;

/// Tells the routing system to operate offline (rely on cached/local data
/// only). Equivalent to go-libp2p's `Offline`.
void offlineOption(RoutingOptions opts) => opts.offline = true;
